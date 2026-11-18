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

import router from '@ohos.router';
import { ApiManager, BaseVideo, DataSourceManager, EmptyBaseVideo,
  EmptyStat, FavMedia, FavMediaDataSource, FavResourceResult, isFavMediaInvalid,
  OhNavBar, Owner, Stat, StringUtil } from '@ohos/common';

/** 收藏夹内容每页项数 */
let FAV_PAGE_SIZE: number = 20;

/** 页面加载状态 */
enum LoadState {
  Loading,
  Error,
  Content
}

/**
 * 收藏夹内容页：FavMediaDataSource 分页列表（封面/标题/UP/收藏时间）；
 * 点击构造 BaseVideo 跳播放页；失效视频（attr 标记）置灰不可点击；
 * 行尾取消收藏按钮（AlertDialog 二次确认，favDeal delIds）；空态/错误态可重试。
 * 路由参数 { mediaId: number, title: string }。
 */
@Entry
@Component
struct FavDetail {
  private mediaId: number = router.getParams()['mediaId'];
  private title: string = router.getParams()['title'] ?? '';
  @State state: LoadState = LoadState.Loading;
  @State hasMore: boolean = true;
  @State isRefreshing: boolean = false;
  /** 上拉加载更多锁 */
  private loadingMoreLock: boolean = false;
  private pn: number = 1;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    if (this.mediaId == null || this.mediaId <= 0) {
      this.state = LoadState.Error;
      return;
    }
    this.loadFirst();
  }

  aboutToDisappear() {
    DataSourceManager.deleteFavMediaSource(this.mediaId.toString());
  }

  build() {
    Column() {
      OhNavBar({ title: this.title === '' ? '收藏夹' : this.title, isBack: true })

      if (this.state == LoadState.Loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
          Text("加载中...")
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.state == LoadState.Error) {
        Column() {
          Text("收藏夹加载失败").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium)
          Text("登录已失效或网络异常，请重试").fontSize(14).fontColor('#888888').margin({ top: 12 })
          Button("重试").width(240).margin({ top: 16 }).onClick(() => {
            this.loadFirst();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.source().totalCount() == 0) {
        // 空态
        Column() {
          Text("收藏夹是空的").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("收藏喜欢的视频到这里吧").fontSize(14).fontColor('#888888').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.scroller }) {
            LazyForEach(this.source(), (item: FavMedia, index: number) => {
              ListItem() {
                this.MediaRow(item, index)
              }
            }, (item: FavMedia, index: number) => index + '_' + (item.bvid ?? item.id ?? 0))
            if (!this.hasMore) {
              ListItem() {
                Text("没有更多了")
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ top: 4, bottom: 4 })
              }
            }
          }
          .width('100%')
          .height('100%')
          .padding({ top: 8, bottom: 8, left: 12, right: 12 })
          .edgeEffect(EdgeEffect.None)
          .onReachEnd(() => {
            this.loadMore();
          })
        }
        .onRefreshing(() => {
          this.refresh();
        })
        .width('100%')
        .layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor('#eeeeee')
  }

  /**
   * 收藏视频行：封面 + 标题/UP/收藏时间 + 行尾取消收藏；
   * 失效视频（attr bit9/bvid 缺失）置灰不可点击。
   */
  @Builder
  private MediaRow(item: FavMedia, index: number) {
    Row() {
      Stack() {
        Image(item.cover ?? '')
          .width(136)
          .height(84)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.ic_comment_avatar_default'))
        if (isFavMediaInvalid(item)) {
          // 失效视频角标
          Text('已失效')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .position({ x: 6, y: 6 })
        }
      }
      .width(136)
      .height(84)

      Column() {
        Text(item.title ?? '')
          .fontSize(14)
          .fontColor(isFavMediaInvalid(item) ? '#999999' : '#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start)
        Blank()
        Text(item.upper == null ? '' : (item.upper.name ?? ''))
          .fontSize(12)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.favTimeText(item))
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .height(84)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10, right: 8 })

      if (!isFavMediaInvalid(item)) {
        Text("取消收藏")
          .fontSize(12)
          .fontColor('#999999')
          .padding({ left: 8, right: 4, top: 8, bottom: 8 })
          .onClick(() => {
            this.confirmUnfav(item, index);
          })
      }
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onItemClick(item);
    })
  }

  /**
   * 首屏加载（第一页）
   */
  private loadFirst(): void {
    this.state = LoadState.Loading;
    this.pn = 1;
    this.hasMore = true;
    ApiManager.getInstance().requestFavResources(this.mediaId, 1, FAV_PAGE_SIZE)
      .then((result: FavResourceResult) => {
        this.handleResult(result, true);
      }).catch(() => {
        this.state = LoadState.Error;
      });
  }

  private handleResult(result: FavResourceResult, isFirst: boolean): void {
    if (result.success) {
      this.hasMore = result.hasMore;
      this.state = LoadState.Content;
      return;
    }
    if (isFirst) {
      this.state = LoadState.Error;
    }
  }

  /**
   * 下拉刷新：重新加载第一页
   */
  private refresh(): void {
    this.pn = 1;
    ApiManager.getInstance().requestFavResources(this.mediaId, 1, FAV_PAGE_SIZE)
      .then((result: FavResourceResult) => {
        if (result.success) {
          this.hasMore = result.hasMore;
        }
        this.isRefreshing = false;
      }).catch(() => {
        this.isRefreshing = false;
      });
  }

  /**
   * 上拉加载更多：pn 分页追加；翻尽后不再请求
   */
  private async loadMore(): Promise<void> {
    if (this.loadingMoreLock || !this.hasMore || this.state != LoadState.Content) {
      return;
    }
    this.loadingMoreLock = true;
    try {
      let nextPn: number = this.pn + 1;
      let result: FavResourceResult =
        await ApiManager.getInstance().requestFavResources(this.mediaId, nextPn, FAV_PAGE_SIZE);
      if (result.success) {
        this.pn = nextPn;
        this.hasMore = result.hasMore;
      }
    } catch (err) {
      // 网络异常时静默，下次触底重试
    } finally {
      this.loadingMoreLock = false;
    }
  }

  /**
   * 条目点击：构造 BaseVideo 跳播放页（失效视频不可点击）
   */
  private onItemClick(item: FavMedia): void {
    if (isFavMediaInvalid(item)) {
      return;
    }
    let video: BaseVideo = EmptyBaseVideo(item.bvid ?? '');
    video.title = item.title ?? '';
    video.pic = item.cover ?? '';
    video.aid = item.id ?? 0;
    video.desc = item.intro ?? '';
    video.duration = StringUtil.parseSecondToVideoDuration(item.duration ?? 0);
    let owner: Owner = {
      mid: item.upper == null ? 0 : (item.upper.mid ?? 0),
      name: item.upper == null ? '' : (item.upper.name ?? ''),
      face: item.upper == null ? '' : (item.upper.face ?? '')
    };
    video.owner = owner;
    let stat: Stat = EmptyStat();
    if (item.cnt_info != null) {
      stat.view = item.cnt_info.play ?? 0;
      stat.danmaku = item.cnt_info.danmaku ?? 0;
    }
    video.stat = stat;
    router.pushUrl({ url: 'pages/Video', params: { vInfo: video } });
  }

  /**
   * 取消收藏二次确认（FR-008）：favDeal 从当前夹移除
   */
  private confirmUnfav(item: FavMedia, index: number): void {
    let aid: number = item.id ?? 0;
    if (aid <= 0) {
      return;
    }
    AlertDialog.show({
      title: '取消收藏',
      message: '确定将该视频移出此收藏夹吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移出',
        fontColor: '#fb7299',
        action: () => {
          this.doUnfav(aid, index);
        }
      }
    });
  }

  private doUnfav(aid: number, index: number): void {
    let delIds: number[] = [this.mediaId];
    ApiManager.getInstance().favDeal(aid, [], delIds).then((ok: boolean) => {
      if (ok) {
        this.source().deleteData(index);
      } else {
        this.showToast('取消收藏失败，请重试');
      }
    }).catch(() => {
      this.showToast('取消收藏失败，请重试');
    });
  }

  private source(): FavMediaDataSource {
    return DataSourceManager.getFavMediaSource(this.mediaId.toString());
  }

  /**
   * 收藏时间文案
   */
  private favTimeText(item: FavMedia): string {
    let favTime: number = item.fav_time ?? 0;
    if (favTime <= 0) {
      return '';
    }
    return StringUtil.timeStampToAgoDate(favTime) + '收藏';
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}
