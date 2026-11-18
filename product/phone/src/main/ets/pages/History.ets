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
  EmptyStat, HistoryDataSource, HistoryItem, HistoryResult, isPlayableHistoryItem,
  Owner, Stat, StringUtil } from '@ohos/common';

/** 历史记录每页项数 */
let HISTORY_PAGE_SIZE: number = 20;

/** 页面加载状态 */
enum LoadState {
  Loading,
  Error,
  Content
}

/**
 * 历史记录页：云端历史列表（封面/标题/UP/时间/进度），
 * 点击续播（startAt=上次观看秒数），行尾单删（AlertDialog 确认），
 * 右上角清空全部（AlertDialog 确认）；未登录页内登录引导（不发起请求）。
 */
@Entry
@Component
struct History {
  @StorageLink('isOhBiliLoggedIn') @Watch('onLoginStateChanged') loginState: boolean = false;
  @State state: LoadState = LoadState.Loading;
  @State hasMore: boolean = true;
  @State isRefreshing: boolean = false;
  /** 上拉加载更多锁（防止滚动抖动重复请求） */
  private loadingMoreLock: boolean = false;
  private pn: number = 1;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    if (this.loginState) {
      this.loadFirst();
    } else {
      this.state = LoadState.Content;
    }
  }

  onLoginStateChanged() {
    if (this.loginState && this.source().totalCount() == 0 && this.state != LoadState.Loading) {
      this.loadFirst();
    }
  }

  build() {
    Column() {
      this.HeaderBar()

      if (!this.loginState) {
        // 未登录：页内登录引导，不发起历史请求
        Column() {
          Text("你还未登录").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("登录账号，查看你的历史记录").fontSize(15).fontColor('#888888').margin({ top: 16 })
          Button("登录").width(240).margin({ top: 16 }).onClick(() => {
            router.pushUrl({ url: "pages/Login" })
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
            .fontColor('#888888')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.state == LoadState.Error) {
        Column() {
          Text("历史记录加载失败").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium)
          Text("登录已失效或网络异常，请重试").fontSize(14).fontColor('#888888').margin({ top: 12 })
          Button("重试").width(240).margin({ top: 16 }).onClick(() => {
            this.loadFirst();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.source().totalCount() == 0) {
        // 空态（无历史或已清空）
        Column() {
          Text("暂无历史记录").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("快去看点视频吧").fontSize(14).fontColor('#888888').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.scroller }) {
            LazyForEach(this.source(), (item: HistoryItem, index: number) => {
              ListItem() {
                this.HistoryRow(item, index)
              }
            }, (item: HistoryItem, index: number) => index + '_' + (item.view_at ?? 0))
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
   * 头部栏：返回 + 标题 + 右上角"清空"入口（OhNavBar 无右槽，页内自绘同款栏）
   */
  @Builder
  private HeaderBar() {
    Row() {
      Image($r('app.media.ic_page_back'))
        .width(42).height(42)
        .margin({ left: 16 })
        .objectFit(ImageFit.Contain)
        .padding(12)
        .onClick(() => {
          router.back();
        })
      Text("历史记录")
        .fontSize(16)
        .fontColor(Color.Black)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 12, right: 12 })
      Blank()
      if (this.loginState && this.source().totalCount() > 0) {
        Text("清空")
          .fontSize(14)
          .fontColor('#fb7299')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.confirmClear();
          })
      }
    }
    .width('100%')
    .height(48)
    .border({ width: { bottom: 0.5 }, color: '#cccccc' })
    .backgroundColor(Color.White)
  }

  /**
   * 历史条目行：封面 + 标题/UP/时间/进度 + 行尾删除（仅普通视频）；
   * 非视频类型（番剧/直播等）降级展示且不可点击。
   */
  @Builder
  private HistoryRow(item: HistoryItem, index: number) {
    Row() {
      Stack() {
        Image(item.cover ?? '')
          .width(136)
          .height(84)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.ic_comment_avatar_default'))
        if (!isPlayableHistoryItem(item)) {
          // 非视频类型角标（番剧/影视/直播回放等）
          Text(this.itemBadge(item))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .position({ x: 6, y: 6 })
        }
        if (isPlayableHistoryItem(item) && (item.progress ?? 0) > 0) {
          // 进度遮罩文案
          Text(this.progressText(item))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .position({ x: 6, y: 84 - 18 })
        }
      }
      .width(136)
      .height(84)

      Column() {
        Text(item.title ?? '')
          .fontSize(14)
          .fontColor(isPlayableHistoryItem(item) ? '#333333' : '#999999')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start)
        Blank()
        Text(item.author_name ?? '')
          .fontSize(12)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.viewTimeText(item))
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .height(84)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10, right: 8 })

      if (isPlayableHistoryItem(item)) {
        Text("删除")
          .fontSize(12)
          .fontColor('#999999')
          .padding({ left: 8, right: 4, top: 8, bottom: 8 })
          .onClick(() => {
            this.confirmDelete(item, index);
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
    ApiManager.getInstance().requestHistory(1, HISTORY_PAGE_SIZE).then((result: HistoryResult) => {
      this.handleResult(result, true);
    }).catch(() => {
      this.state = LoadState.Error;
    });
  }

  private handleResult(result: HistoryResult, isFirst: boolean): void {
    if (result.success) {
      this.hasMore = result.hasMore;
      this.state = LoadState.Content;
      return;
    }
    if (isFirst) {
      // 首屏失败（含登录失效）展示错误态可重试
      this.state = LoadState.Error;
    }
  }

  /**
   * 下拉刷新：重新加载第一页
   */
  private refresh(): void {
    this.pn = 1;
    ApiManager.getInstance().requestHistory(1, HISTORY_PAGE_SIZE).then((result: HistoryResult) => {
      if (result.success) {
        this.hasMore = result.hasMore;
      }
      this.isRefreshing = false;
    }).catch(() => {
      this.isRefreshing = false;
    });
  }

  /**
   * 上拉加载更多：游标分页追加；翻尽后不再请求
   */
  private async loadMore(): Promise<void> {
    if (this.loadingMoreLock || !this.hasMore || this.state != LoadState.Content) {
      return;
    }
    this.loadingMoreLock = true;
    try {
      let nextPn: number = this.pn + 1;
      let result: HistoryResult =
        await ApiManager.getInstance().requestHistory(nextPn, HISTORY_PAGE_SIZE);
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
   * 条目点击：构造 BaseVideo 跳播放页，startAt 为上次观看秒数（续播）
   */
  private onItemClick(item: HistoryItem): void {
    if (!isPlayableHistoryItem(item) || item.history == null) {
      return;
    }
    let video: BaseVideo = EmptyBaseVideo(item.history.bvid ?? '');
    video.title = item.title ?? '';
    video.pic = item.cover ?? '';
    video.cid = item.history.cid ?? 0;
    video.aid = item.history.oid ?? 0;
    video.duration = StringUtil.parseSecondToVideoDuration(item.duration ?? 0);
    let owner: Owner = {
      mid: Number(item.author_mid ?? 0),
      name: item.author_name ?? '',
      face: item.author_face ?? ''
    };
    video.owner = owner;
    let stat: Stat = EmptyStat();
    video.stat = stat;
    let startAt: number = this.resumeSeconds(item);
    router.pushUrl({ url: 'pages/Video', params: { vInfo: video, startAt: startAt } });
  }

  /**
   * 续播秒数：已看完（progress<0 或 >= duration）从头播，否则从 progress 处续播
   */
  private resumeSeconds(item: HistoryItem): number {
    let progress: number = item.progress ?? 0;
    let duration: number = item.duration ?? 0;
    if (progress > 0 && (duration <= 0 || progress < duration)) {
      return progress;
    }
    return 0;
  }

  /**
   * 单条删除二次确认（FR-008）
   */
  private confirmDelete(item: HistoryItem, index: number): void {
    if (item.history == null || item.history.oid == null) {
      return;
    }
    // 现行 web 版删除接口 kid 格式：{business}_{kid}（如 archive_170001）
    let kidNum: number = item.kid ?? item.history.oid;
    let kid: string = (item.history.business ?? 'archive') + '_' + kidNum;
    AlertDialog.show({
      title: '删除历史记录',
      message: '确定删除这条历史记录吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#fb7299',
        action: () => {
          this.doDelete(kid, index);
        }
      }
    });
  }

  private doDelete(kid: string, index: number): void {
    ApiManager.getInstance().deleteHistory(kid).then((ok: boolean) => {
      if (ok) {
        this.source().deleteData(index);
      } else {
        this.showToast('删除失败，请重试');
      }
    }).catch(() => {
      this.showToast('删除失败，请重试');
    });
  }

  /**
   * 清空全部二次确认（FR-008，不可恢复）
   */
  private confirmClear(): void {
    AlertDialog.show({
      title: '清空历史记录',
      message: '确定要清空全部历史记录吗？该操作不可恢复',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: '#fb7299',
        action: () => {
          this.doClear();
        }
      }
    });
  }

  private doClear(): void {
    ApiManager.getInstance().clearHistory().then((ok: boolean) => {
      if (ok) {
        this.source().setData([]);
        this.hasMore = false;
      } else {
        this.showToast('清空失败，请重试');
      }
    }).catch(() => {
      this.showToast('清空失败，请重试');
    });
  }

  private source(): HistoryDataSource {
    return DataSourceManager.getHistorySource();
  }

  /**
   * 观看时间文案
   */
  private viewTimeText(item: HistoryItem): string {
    let viewAt: number = item.view_at ?? 0;
    if (viewAt <= 0) {
      return '';
    }
    return StringUtil.timeStampToAgoDate(viewAt);
  }

  /**
   * 进度文案：progress<0 已看完，否则"看到 mm:ss/mm:ss"
   */
  private progressText(item: HistoryItem): string {
    let progress: number = item.progress ?? 0;
    let duration: number = item.duration ?? 0;
    if (progress < 0) {
      return '已看完';
    }
    return '看到 ' + StringUtil.parseSecondToVideoDuration(progress)
      + '/' + StringUtil.parseSecondToVideoDuration(duration);
  }

  /**
   * 非视频类型角标文案
   */
  private itemBadge(item: HistoryItem): string {
    let badge: string = item.badge ?? '';
    if (badge !== '') {
      return badge;
    }
    let business: string = item.history == null ? '' : (item.history.business ?? '');
    if (business === 'pgc') {
      return '番剧';
    }
    if (business === 'live') {
      return '直播';
    }
    if (business !== '') {
      return business;
    }
    return '暂不可播';
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}
