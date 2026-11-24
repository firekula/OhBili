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

import { ApiManager, DataSourceManager, DynamicDataSource, DynamicFeedResult,
  DynamicItem, DynamicItemView, HomePullToRefresh, OhNavBar } from '@ohos/common'
import router from '@ohos.router';

/** 视频标签单次加载的翻页兜底上限：一页可能被过滤到 0 条，循环拉取直到有新增或翻尽 */
let FEED_MAX_ROUNDS: number = 5;

@Component
export struct MomentsView {
  @StorageLink('isOhBiliLoggedIn') @Watch('onLoginStateChanged') loginState: boolean = false;
  @StorageLink('ohBiliUname') uname: string = '';
  @StorageLink('ohBiliFace') face: string = '';
  /** 仅为构建器内 this.scroller 的编译期类型检查保留；运行时实际取子组件同名属性 */
  private scroller: Scroller = new Scroller();
  /** 各标签独立滚动器（切回标签保留各自滚动位置） */
  private scrollers: Scroller[] = [new Scroller(), new Scroller()];
  @State data: any[] = [];
  /** 当前标签：0=全部 1=视频 */
  @State currentTab: number = 0;
  /** 各标签独立分页游标（首页空串） */
  private feedOffsets: string[] = ['', ''];
  /** 各标签是否还有更多动态 */
  private hasMores: boolean[] = [true, true];
  /** 各标签是否已成功发起过加载（防重复触发；切回已加载标签不重拉首屏） */
  private loadedOnces: boolean[] = [false, false];
  /** 各标签首屏加载中 */
  @State isLoadingArr: boolean[] = [false, false];
  /** 各标签首屏请求失败（网络异常等） */
  @State loadFailedArr: boolean[] = [false, false];
  /** 各标签登录失效（业务码 -101） */
  @State loginExpiredArr: boolean[] = [false, false];

  aboutToAppear() {
    if (this.loginState) {
      // 预取两个标签首屏，切换标签无需等待
      this.loadFirst(0);
      this.loadFirst(1);
    }
  }

  /**
   * 登录成功后自动加载动态流（未登录不发起动态请求）；
   * 退出登录后重置标记，再次登录可重新加载。
   */
  onLoginStateChanged() {
    if (!this.loginState) {
      this.loadedOnces = [false, false];
      return;
    }
    this.loadFirst(0);
    this.loadFirst(1);
  }

  build() {
    Column() {
      OhNavBar({ title: "动态", isBack: false, isTitleCenter: true })

      if (this.loginState) {
        this.TabBar()
      }

      if (!this.loginState) {
        Text("你还未登录").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium).margin({ top: 48 })
        Text("登录账号，查看你关注的UP主内容").fontSize(15).fontColor($r('app.color.text_secondary')).margin({ top: 16 })
        Button("登录").width(240).margin({ top: 16 }).onClick(() => {
          router.pushUrl({ url: "pages/Login" })
        })
      } else {
        // 双标签同驻：Swiper 承载两页，切换不销毁列表、保留滚动位置
        Swiper() {
          this.pageContent(0)
          this.pageContent(1)
        }
        .width('100%')
        .layoutWeight(1)
        .index(this.currentTab)
        .loop(false)
        .indicator(false)
        .onChange((index: number) => {
          this.onSwiperChange(index);
        })
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }

  /**
   * 全部/视频标签栏
   */
  @Builder
  TabBar() {
    Row({ space: 10 }) {
      Text("全部")
        .fontSize(14)
        .fontColor(this.currentTab == 0 ? Color.White : $r('app.color.text_primary'))
        .fontWeight(this.currentTab == 0 ? FontWeight.Medium : FontWeight.Normal)
        .backgroundColor(this.currentTab == 0 ? '#1698CE' : $r('app.color.surface'))
        .borderRadius(14)
        .padding({ left: 16, right: 16, top: 5, bottom: 5 })
        .onClick(() => {
          this.switchTab(0);
        })
      Text("视频")
        .fontSize(14)
        .fontColor(this.currentTab == 1 ? Color.White : $r('app.color.text_primary'))
        .fontWeight(this.currentTab == 1 ? FontWeight.Medium : FontWeight.Normal)
        .backgroundColor(this.currentTab == 1 ? '#1698CE' : $r('app.color.surface'))
        .borderRadius(14)
        .padding({ left: 16, right: 16, top: 5, bottom: 5 })
        .onClick(() => {
          this.switchTab(1);
        })
    }
    .width('100%')
    .padding({ left: 12, top: 8, bottom: 8 })
  }

  /**
   * 单个标签页：加载中/登录失效/失败/空态/列表，按该标签独立状态渲染
   */
  @Builder
  private pageContent(tab: number) {
    if (this.isLoadingArr[tab] && this.sourceOf(tab).totalCount() == 0) {
      // 首屏加载态
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
        Text(tab == 1 ? "视频动态加载中..." : "动态加载中...")
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.loginExpiredArr[tab] && this.sourceOf(tab).totalCount() == 0) {
      // 登录失效：引导重新登录，非死循环加载
      Column() {
        Text("登录已失效").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium).margin({ top: 48 })
        Text("请重新登录后查看动态").fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 12 })
        Button("重新登录").width(240).margin({ top: 16 }).onClick(() => {
          router.pushUrl({ url: "pages/Login" })
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.loadFailedArr[tab] && this.sourceOf(tab).totalCount() == 0) {
      // 请求失败错误态，可重试
      Column() {
        Text("动态加载失败").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium).margin({ top: 48 })
        Text("请检查网络后重试").fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 12 })
        Button("重试").width(240).margin({ top: 16 }).onClick(() => {
          this.loadFirst(tab);
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.sourceOf(tab).totalCount() == 0) {
      // 空态（如新账号无关注）
      Column() {
        Text(tab == 1 ? "暂无视频动态" : "暂无动态")
          .fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium).margin({ top: 48 })
        Text("去关注喜欢的UP主吧").fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      if (tab == 0) {
        HomePullToRefresh({
          // 必传项，列表组件所绑定的数据
          data: $data,
          // 必传项，需绑定传入主体布局内的列表或宫格组件
          scroller: this.scrollers[0],
          // 必传项，自定义主体布局，内部有列表或宫格组件
          customList: this.getAllListView,
          // 下拉刷新回调
          onRefresh: () => {
            return this.refresh();
          },
          // 上拉加载更多回调
          onLoadMore: () => {
            return this.loadMore();
          },
          customLoad: null,
          customRefresh: null,
        })
      } else {
        HomePullToRefresh({
          // 必传项，列表组件所绑定的数据
          data: $data,
          // 必传项，需绑定传入主体布局内的列表或宫格组件
          scroller: this.scrollers[1],
          // 必传项，自定义主体布局，内部有列表或宫格组件
          customList: this.getVideoListView,
          // 下拉刷新回调
          onRefresh: () => {
            return this.refresh();
          },
          // 上拉加载更多回调
          onLoadMore: () => {
            return this.loadMore();
          },
          customLoad: null,
          customRefresh: null,
        })
      }
    }
  }

  /**
   * 点击标签切换（Swiper 跟随 index 动画切换）；未加载过的标签拉首屏
   */
  private switchTab(tab: number): void {
    if (tab == this.currentTab) {
      return;
    }
    this.currentTab = tab;
    if (!this.loadedOnces[tab]) {
      this.loadFirst(tab);
    }
  }

  /**
   * Swiper 滑动切换回调：同步当前标签；未加载过的标签拉首屏
   */
  private onSwiperChange(index: number): void {
    this.currentTab = index;
    if (!this.loadedOnces[index]) {
      this.loadFirst(index);
    }
  }

  private sourceOf(tab: number): DynamicDataSource {
    return tab == 1 ? DataSourceManager.getDynamicVideoSource()
      : DataSourceManager.getDynamicSource();
  }

  /**
   * 指定标签首屏加载（刷新该标签第一页）
   */
  private loadFirst(tab: number): void {
    this.loadedOnces[tab] = true;
    this.isLoadingArr[tab] = true;
    this.loadFailedArr[tab] = false;
    this.loginExpiredArr[tab] = false;
    this.fetchFirstPage(tab);
  }

  /**
   * 首屏拉取：视频标签一页可能被过滤到 0 条，
   * 循环按游标翻页直到有内容或翻尽（FEED_MAX_ROUNDS 兜底）
   */
  private async fetchFirstPage(tab: number): Promise<void> {
    let videoOnly: boolean = tab == 1;
    let offset: string = '';
    let hasMore: boolean = true;
    let success: boolean = false;
    let expired: boolean = false;
    let rounds: number = 0;
    while (rounds < FEED_MAX_ROUNDS) {
      let result: DynamicFeedResult =
        await ApiManager.getInstance().requestDynamicFeed(offset, rounds == 0, videoOnly);
      if (!result.success) {
        expired = result.loginExpired;
        break;
      }
      success = true;
      offset = result.nextOffset;
      hasMore = result.hasMore;
      rounds++;
      if (!videoOnly || this.sourceOf(tab).totalCount() > 0 || !hasMore) {
        break;
      }
    }
    this.isLoadingArr[tab] = false;
    if (success) {
      this.feedOffsets[tab] = offset;
      this.hasMores[tab] = hasMore;
    } else if (expired) {
      this.loginExpiredArr[tab] = true;
    } else {
      this.loadFailedArr[tab] = true;
    }
  }

  /**
   * 下拉刷新：回到最新（重新加载当前标签第一页）
   */
  private async refresh(): Promise<string> {
    let tab: number = this.currentTab;
    let result: DynamicFeedResult =
      await ApiManager.getInstance().requestDynamicFeed('', true, tab == 1);
    if (result.success) {
      this.feedOffsets[tab] = result.nextOffset;
      this.hasMores[tab] = result.hasMore;
      this.loginExpiredArr[tab] = false;
      return '';
    }
    if (result.loginExpired) {
      this.loginExpiredArr[tab] = true;
    }
    return '刷新失败';
  }

  /**
   * 上拉加载更多：按游标分页追加；翻尽后提示"没有更多了"且不再请求。
   * 视频标签一页可能被过滤到 0 条新增，循环翻页直到有新增或翻尽（有兜底上限）
   */
  private async loadMore(): Promise<string> {
    let tab: number = this.currentTab;
    if (!this.hasMores[tab]) {
      return '没有更多了';
    }
    let videoOnly: boolean = tab == 1;
    let offset: string = this.feedOffsets[tab];
    let hasMore: boolean = true;
    let rounds: number = 0;
    while (rounds < FEED_MAX_ROUNDS) {
      let before: number = this.sourceOf(tab).totalCount();
      let result: DynamicFeedResult =
        await ApiManager.getInstance().requestDynamicFeed(offset, false, videoOnly);
      if (!result.success) {
        if (result.loginExpired) {
          this.loginExpiredArr[tab] = true;
          return '登录已失效';
        }
        return '加载失败';
      }
      offset = result.nextOffset;
      hasMore = result.hasMore;
      rounds++;
      let added: number = this.sourceOf(tab).totalCount() - before;
      if (!videoOnly || added > 0 || !hasMore) {
        break;
      }
    }
    this.feedOffsets[tab] = offset;
    this.hasMores[tab] = hasMore;
    return '';
  }

  /**
   * 全部标签列表。注意：customList 以引用方式传入 HomePullToRefresh，
   * 构建器内 this 不是本组件，只能使用子组件同名属性（this.scroller）与
   * 静态单例（DataSourceManager），不可调用本组件方法。
   */
  @Builder
  private getAllListView(_, onListStatus: (isListStart: boolean, isListEnd: boolean) => void) {
    List({ scroller: this.scroller }) {
      LazyForEach(DataSourceManager.getDynamicSource(), (item: DynamicItem, index: number) => {
        ListItem() {
          DynamicItemView({ item: item })
        }
      }, item => item.id_str)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 12, right: 12 })
    .edgeEffect(EdgeEffect.None)
    .onScrollIndex((start, end) => {
      onListStatus(start == 0,
        end == DataSourceManager.getDynamicSource().totalCount() - 1)
    })
  }

  /**
   * 视频标签列表（仅视频投稿动态）
   */
  @Builder
  private getVideoListView(_, onListStatus: (isListStart: boolean, isListEnd: boolean) => void) {
    List({ scroller: this.scroller }) {
      LazyForEach(DataSourceManager.getDynamicVideoSource(), (item: DynamicItem, index: number) => {
        ListItem() {
          DynamicItemView({ item: item })
        }
      }, item => item.id_str)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 12, right: 12 })
    .edgeEffect(EdgeEffect.None)
    .onScrollIndex((start, end) => {
      onListStatus(start == 0,
        end == DataSourceManager.getDynamicVideoSource().totalCount() - 1)
    })
  }
}
