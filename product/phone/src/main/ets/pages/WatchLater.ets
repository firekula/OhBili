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
import { ApiManager, BaseVideo, DataSourceManager, EmptyBaseVideo, EmptyStat,
  isWatchLaterItemInvalid, NavHelper, OhNavBar, Owner, Stat, StringUtil,
  WatchLaterDataSource, WatchLaterItem, WatchLaterResult } from '@ohos/common';

/** 页面加载状态 */
enum LoadState {
  Loading,
  Error,
  Content
}

/**
 * 稍后再看页：WatchLaterDataSource 全量列表（封面/标题/UP/添加时间）；
 * 点击构造 BaseVideo 跳播放页（aid 透传供移除等操作）；
 * 失效条目（attr bit9）置灰不可点击；行尾移除按钮（AlertDialog 二次确认）；
 * 未登录页内登录引导；空态/错误态可重试；下拉刷新。
 */
@Entry
@Component
struct WatchLater {
  @StorageLink('isOhBiliLoggedIn') @Watch('onLoginStateChanged') loginState: boolean = false;
  @State state: LoadState = LoadState.Loading;
  @State isRefreshing: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    if (this.loginState) {
      this.loadList();
    } else {
      this.state = LoadState.Content;
    }
  }

  onLoginStateChanged() {
    if (this.loginState && this.source().totalCount() == 0 && this.state != LoadState.Loading) {
      this.loadList();
    }
  }

  /**
   * 返回本页时静默刷新（视频页添加稍后再看后返回即可见）
   */
  onPageShow() {
    if (this.loginState && this.state == LoadState.Content) {
      this.refresh();
    }
  }

  build() {
    Column() {
      OhNavBar({ title: "稍后再看", isBack: true })

      if (!this.loginState) {
        // 未登录：页内登录引导，不发起稍后再看请求
        Column() {
          Text("你还未登录").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("登录账号，查看你的稍后再看").fontSize(15).fontColor($r('app.color.text_secondary')).margin({ top: 16 })
          Button("登录").width(240).margin({ top: 16 }).onClick(() => {
            NavHelper.goLogin();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.state == LoadState.Loading) {
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
        Column() {
          Text("稍后再看加载失败").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium)
          Text("登录已失效或网络异常，请重试").fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 12 })
          Button("重试").width(240).margin({ top: 16 }).onClick(() => {
            this.loadList();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.source().totalCount() == 0) {
        // 空态
        Column() {
          Text("稍后再看是空的").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("看到好视频先马住，有空再看").fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.scroller }) {
            LazyForEach(this.source(), (item: WatchLaterItem, index: number) => {
              ListItem() {
                this.ItemRow(item, index)
              }
            }, (item: WatchLaterItem, index: number) => (item.aid ?? 0) + '_' + (item.bvid ?? ''))
          }
          .width('100%')
          .height('100%')
          .padding({ top: 8, bottom: 8, left: 12, right: 12 })
          .edgeEffect(EdgeEffect.None)
        }
        .onRefreshing(() => {
          this.refresh();
        })
        .width('100%')
        .layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }

  /**
   * 稍后再看条目行：封面 + 标题/UP/添加时间 + 行尾移除；
   * 失效条目（attr bit9/bvid 缺失）置灰不可点击。
   */
  @Builder
  private ItemRow(item: WatchLaterItem, index: number) {
    Row() {
      Stack() {
        Image(item.pic ?? '')
          .width(136)
          .height(84)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('app.color.border'))
        if (isWatchLaterItemInvalid(item)) {
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
          .fontColor(isWatchLaterItemInvalid(item) ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start)
        Blank()
        Text(item.owner == null ? '' : (item.owner.name ?? ''))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.addTimeText(item))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .height(84)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10, right: 8 })

      Text("移除")
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
        .padding({ left: 8, right: 4, top: 8, bottom: 8 })
        .onClick(() => {
          this.confirmRemove(item, index);
        })
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor($r('app.color.surface'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onItemClick(item);
    })
  }

  /**
   * 首屏加载
   */
  private loadList(): void {
    this.state = LoadState.Loading;
    ApiManager.getInstance().requestWatchLater().then((result: WatchLaterResult) => {
      if (result.success) {
        this.state = LoadState.Content;
      } else {
        this.state = LoadState.Error;
      }
    }).catch(() => {
      this.state = LoadState.Error;
    });
  }

  /**
   * 下拉刷新
   */
  private refresh(): void {
    ApiManager.getInstance().requestWatchLater().then((result: WatchLaterResult) => {
      this.isRefreshing = false;
    }).catch(() => {
      this.isRefreshing = false;
    });
  }

  /**
   * 条目点击：构造 BaseVideo 跳播放页（aid 透传），失效条目不可点击
   */
  private onItemClick(item: WatchLaterItem): void {
    if (isWatchLaterItemInvalid(item)) {
      return;
    }
    let video: BaseVideo = EmptyBaseVideo(item.bvid ?? '');
    video.title = item.title ?? '';
    video.pic = item.pic ?? '';
    video.aid = item.aid ?? 0;
    video.cid = item.cid ?? 0;
    video.desc = item.desc ?? '';
    video.duration = StringUtil.parseSecondToVideoDuration(item.duration ?? 0);
    let owner: Owner = {
      mid: item.owner == null ? 0 : (item.owner.mid ?? 0),
      name: item.owner == null ? '' : (item.owner.name ?? ''),
      face: item.owner == null ? '' : (item.owner.face ?? '')
    };
    video.owner = owner;
    let stat: Stat = EmptyStat();
    video.stat = stat;
    router.pushUrl({ url: 'pages/Video', params: { vInfo: video } });
  }

  /**
   * 移除二次确认（FR-008）
   */
  private confirmRemove(item: WatchLaterItem, index: number): void {
    let aid: number = item.aid ?? 0;
    if (aid <= 0) {
      return;
    }
    AlertDialog.show({
      title: '移除稍后再看',
      message: '确定将该视频从稍后再看移除吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#fb7299',
        action: () => {
          this.doRemove(aid, index);
        }
      }
    });
  }

  private doRemove(aid: number, index: number): void {
    ApiManager.getInstance().removeWatchLater(aid).then((ok: boolean) => {
      if (ok) {
        this.source().deleteData(index);
      } else {
        this.showToast('移除失败，请重试');
      }
    }).catch(() => {
      this.showToast('移除失败，请重试');
    });
  }

  /**
   * 添加时间文案
   */
  private addTimeText(item: WatchLaterItem): string {
    let addDt: number = item.add_dt ?? 0;
    if (addDt <= 0) {
      return '';
    }
    return StringUtil.timeStampToAgoDate(addDt) + '添加';
  }

  private source(): WatchLaterDataSource {
    return DataSourceManager.getWatchLaterSource();
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}
