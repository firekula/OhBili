/**
 * Copyright (c) 2023 Wathinst <wxz@xkzhineng.com>
 * OhBili is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 * http://license.coscl.org.cn/MulanPSL2
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 * See the Mulan PSL v2 for more details.
 */

import { ApiManager, BaseVideo, DataSourceManager, EmptyBaseVideo,
  EmptyStat, OhNavBar, Owner, parseDurationTextToSeconds,
  RecommendItemView, SpaceArcDataSource, SpaceArcItem, SpaceArcResult,
  SpaceUserProfile, Stat, StringUtil } from '@ohos/common'
import router from '@ohos.router';

/** 页面加载状态 */
enum LoadState {
  Loading,
  Error,
  Content
}

/**
 * 通用用户空间页：资料头（头像/昵称/LV/签名 + 关注/粉丝/获赞）+ 投稿两列网格（分页）。
 * 路由参数 { mid: number }；用户不存在/请求失败展示错误态可重试。
 */
@Entry
@Component
struct UserSpace {
  private mid: number = router.getParams()['mid'];
  private scroller: Scroller = new Scroller();
  @State state: LoadState = LoadState.Loading;
  @State profile: SpaceUserProfile | null = null;
  /** 投稿首屏是否加载失败（资料头仍可展示） */
  @State arcFailed: boolean = false;
  /** 投稿是否还有更多 */
  @State hasMore: boolean = true;
  /** 下拉刷新进行中（Refresh 组件状态） */
  @State isRefreshing: boolean = false;
  /** 上拉加载更多锁（防止滚动抖动重复请求） */
  private loadingMoreLock: boolean = false;

  aboutToAppear() {
    if (this.mid == null || this.mid <= 0) {
      this.state = LoadState.Error;
      return;
    }
    this.loadData();
  }

  aboutToDisappear() {
    DataSourceManager.deleteSpaceArcSource(this.mid.toString());
  }

  build() {
    Column() {
      OhNavBar({ title: this.navTitle(), isBack: true })

      if (this.state == LoadState.Loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
          Text("加载中...")
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.state == LoadState.Error) {
        // 用户不存在或请求失败：错误态可重试，不白屏
        Column() {
          Text("空间加载失败").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium)
          Text("用户不存在或网络异常，请重试").fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 12 })
          Button("重试").width(240).margin({ top: 16 }).onClick(() => {
            this.loadData();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        this.ProfileHeader()
        if (this.arcFailed && this.arcSource().totalCount() == 0) {
          // 投稿首屏失败：资料头下展示可重试错误区
          Column() {
            Text("投稿加载失败").fontSize(14).fontColor($r('app.color.text_secondary'))
            Button("重试").width(160).margin({ top: 8 }).onClick(() => {
              this.retryArchives();
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.arcSource().totalCount() == 0) {
          // 无投稿空态
          Column() {
            Text("暂无投稿").fontSize(14).fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          // Refresh + List + LazyForEach 内联于 build()：this 绑定正确
          // （@Builder 经 @BuilderParam 链传递后 this 指向宿主子组件，不可在此引用实例方法）
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ scroller: this.scroller }) {
              LazyForEach(this.arcSource(), (item: SpaceArcItem, index: number) => {
                if (index % 2 == 0) {
                  ListItem() {
                    Row() {
                      Column() {
                        RecommendItemView({ item: this.arcToBaseVideo(item) })
                      }.layoutWeight(1)
                      Column().width(8)
                      Column() {
                        if (index + 1 < this.arcSource().totalCount()) {
                          RecommendItemView({ item: this.arcToBaseVideo(this.arcSource().getData(index + 1)) })
                        }
                      }.layoutWeight(1)
                    }
                  }
                } else {
                  ListItem() {
                    Column().width('100%').height(8)
                  }
                }
              }, item => item.bvid)
              if (!this.hasMore) {
                ListItem() {
                  Text("没有更多了")
                    .fontSize(12)
                    .fontColor($r('app.color.text_tertiary'))
                    .margin({ top: 4, bottom: 4 })
                }
              }
            }
            .width('100%')
            .height('100%')
            .padding({ top: 8, bottom: 8, left: 16, right: 16 })
            .edgeEffect(EdgeEffect.None)
            .onReachEnd(() => {
              this.loadMoreArchives();
            })
          }
          .onRefreshing(() => {
            this.refreshArchives();
          })
          .width('100%')
          .layoutWeight(1)
        }
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }

  /**
   * 资料头：头像/昵称/LV 徽标/签名 + 关注/粉丝/获赞三列（SpaceUserProfile 驱动）
   */
  @Builder
  private ProfileHeader() {
    Column() {
      Row() {
        Image(this.profileFace())
          .width(64)
          .height(64)
          .borderRadius(32)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.ic_comment_avatar_default'))
        Column() {
          Text(this.profileName())
            .fontSize(18)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
          Row() {
            if (this.profileLevel() > 0) {
              Text('LV' + this.profileLevel())
                .fontSize(10)
                .fontColor(Color.White)
                .backgroundColor('#fb7299')
                .borderRadius(2)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            } else {
              // 等级未返回时占位
              Text('--')
                .fontSize(10)
                .fontColor($r('app.color.text_tertiary'))
            }
          }.margin({ top: 4 })
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.profileSign())
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })
        .width('100%')
        .textAlign(TextAlign.Start)

      Row() {
        Column() {
          Text(StringUtil.generateCN(this.profileFollowing()))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
          Text("关注")
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 2 })
        }.layoutWeight(1)

        Column() {
          Text(StringUtil.generateCN(this.profileFollower()))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
          Text("粉丝")
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 2 })
        }.layoutWeight(1)

        Column() {
          Text(StringUtil.generateCN(this.profileLikeNum()))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
          Text("获赞")
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 2 })
        }.layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
  }

  /**
   * 并行拉取资料与投稿首屏
   */
  private async loadData(): Promise<void> {
    this.state = LoadState.Loading;
    let profilePromise: Promise<SpaceUserProfile | null> =
      ApiManager.getInstance().requestSpaceInfo(this.mid);
    let arcPromise: Promise<SpaceArcResult> =
      ApiManager.getInstance().requestSpaceArchives(this.mid, true);
    let profile: SpaceUserProfile | null = null;
    let arcResult: SpaceArcResult = new SpaceArcResult(false, false);
    try {
      profile = await profilePromise;
    } catch (err) {
      profile = null;
    }
    try {
      arcResult = await arcPromise;
    } catch (err) {
      arcResult = new SpaceArcResult(false, false);
    }
    this.profile = profile;
    this.arcFailed = !arcResult.success;
    this.hasMore = arcResult.hasMore;
    if (profile == null && !arcResult.success) {
      // 用户不存在/请求失败：错误态
      this.state = LoadState.Error;
      return;
    }
    this.state = LoadState.Content;
  }

  /**
   * 仅重试投稿首屏（资料头已展示时）
   */
  private retryArchives(): void {
    ApiManager.getInstance().requestSpaceArchives(this.mid, true).then((result: SpaceArcResult) => {
      this.arcFailed = !result.success;
      this.hasMore = result.hasMore;
    }).catch(() => {
      this.arcFailed = true;
    });
  }

  /**
   * 下拉刷新：重新加载第一页投稿；完成后复位刷新状态
   */
  private refreshArchives(): void {
    ApiManager.getInstance().requestSpaceArchives(this.mid, true).then((result: SpaceArcResult) => {
      this.arcFailed = !result.success;
      this.hasMore = result.hasMore;
      this.isRefreshing = false;
    }).catch(() => {
      this.isRefreshing = false;
    });
  }

  /**
   * 上拉加载更多：pn 分页追加；翻尽后展示"没有更多了"且不再请求
   */
  private async loadMoreArchives(): Promise<void> {
    if (this.loadingMoreLock || !this.hasMore) {
      return;
    }
    this.loadingMoreLock = true;
    try {
      let result: SpaceArcResult =
        await ApiManager.getInstance().requestSpaceArchives(this.mid, false);
      this.hasMore = result.hasMore;
    } catch (err) {
      // 网络异常时静默，下次触底重试
    } finally {
      this.loadingMoreLock = false;
    }
  }

  private arcSource(): SpaceArcDataSource {
    return DataSourceManager.getSpaceArcSource(this.mid.toString());
  }

  private navTitle(): string {
    let name: string = this.profileName();
    return name === '' ? '用户空间' : name;
  }

  private profileName(): string {
    return this.profile == null ? '' : this.profile.name;
  }

  private profileFace(): string {
    return this.profile == null ? '' : this.profile.face;
  }

  private profileSign(): string {
    if (this.profile == null) {
      return '';
    }
    let sign: string = this.profile.sign;
    return sign === '' ? '这个人很懒，什么都没写' : sign;
  }

  private profileLevel(): number {
    return this.profile == null ? 0 : this.profile.level;
  }

  private profileFollowing(): number {
    return this.profile == null ? 0 : this.profile.following;
  }

  private profileFollower(): number {
    return this.profile == null ? 0 : this.profile.follower;
  }

  private profileLikeNum(): number {
    return this.profile == null ? 0 : this.profile.likeNum;
  }

  /**
   * SpaceArcItem → BaseVideo 映射（复用 RecommendItemView 渲染投稿网格）
   */
  private arcToBaseVideo(item: SpaceArcItem): BaseVideo {
    let video: BaseVideo = EmptyBaseVideo(item.bvid);
    video.title = item.title ?? '';
    video.pic = item.pic ?? '';
    video.desc = item.description ?? '';
    video.pubdate = item.created ?? 0;
    video.duration = parseDurationTextToSeconds(item.length ?? '');
    let owner: Owner = {
      mid: this.mid,
      name: item.author ?? '',
      face: this.profileFace()
    };
    video.owner = owner;
    let stat: Stat = EmptyStat();
    stat.view = item.play ?? 0;
    video.stat = stat;
    return video;
  }
}
