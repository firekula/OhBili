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

import { ApiManager, DataSourceManager, DynamicFeedResult, DynamicItem,
  DynamicItemView, HomePullToRefresh, OhNavBar } from '@ohos/common'
import router from '@ohos.router';

@Component
export struct MomentsView {
  @StorageLink('isOhBiliLoggedIn') @Watch('onLoginStateChanged') loginState: boolean = false;
  @StorageLink('ohBiliUname') uname: string = '';
  @StorageLink('ohBiliFace') face: string = '';
  private scroller: Scroller = new Scroller();
  @State data: any[] = [];
  /** 动态流分页游标（首页空串） */
  @State feedOffset: string = '';
  /** 是否还有更多动态 */
  @State hasMore: boolean = true;
  /** 首屏加载中 */
  @State isLoading: boolean = false;
  /** 首屏请求失败（网络异常等） */
  @State loadFailed: boolean = false;
  /** 登录失效（业务码 -101） */
  @State loginExpired: boolean = false;
  /** 是否已成功发起过加载（防重复触发） */
  private loadedOnce: boolean = false;

  aboutToAppear() {
    if (this.loginState) {
      this.loadFirst();
    }
  }

  /**
   * 登录成功后自动加载动态流（未登录不发起动态请求）；
   * 退出登录后重置标记，再次登录可重新加载。
   */
  onLoginStateChanged() {
    if (!this.loginState) {
      this.loadedOnce = false;
      return;
    }
    if (!this.loadedOnce) {
      this.loadFirst();
    }
  }

  build() {
    Column() {
      OhNavBar({ title: "动态", isBack: false, isTitleCenter: true })

      if (!this.loginState) {
        Text("你还未登录").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
        Text("登录账号，查看你关注的UP主内容").fontSize(15).fontColor('#888888').margin({ top: 16 })
        Button("登录").width(240).margin({ top: 16 }).onClick(() => {
          router.pushUrl({ url: "pages/Login" })
        })
      } else {
        if (this.isLoading && DataSourceManager.getDynamicSource().totalCount() == 0) {
          // 首屏加载态
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
            Text("动态加载中...")
              .fontSize(14)
              .fontColor('#888888')
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.loginExpired && DataSourceManager.getDynamicSource().totalCount() == 0) {
          // 登录失效：引导重新登录，非死循环加载
          Column() {
            Text("登录已失效").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
            Text("请重新登录后查看动态").fontSize(14).fontColor('#888888').margin({ top: 12 })
            Button("重新登录").width(240).margin({ top: 16 }).onClick(() => {
              router.pushUrl({ url: "pages/Login" })
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.loadFailed && DataSourceManager.getDynamicSource().totalCount() == 0) {
          // 请求失败错误态，可重试
          Column() {
            Text("动态加载失败").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
            Text("请检查网络后重试").fontSize(14).fontColor('#888888').margin({ top: 12 })
            Button("重试").width(240).margin({ top: 16 }).onClick(() => {
              this.loadFirst();
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (DataSourceManager.getDynamicSource().totalCount() == 0) {
          // 空态（如新账号无关注）
          Column() {
            Text("暂无动态").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
            Text("去关注喜欢的UP主吧").fontSize(14).fontColor('#888888').margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          HomePullToRefresh({
            // 必传项，列表组件所绑定的数据
            data: $data,
            // 必传项，需绑定传入主体布局内的列表或宫格组件
            scroller: this.scroller,
            // 必传项，自定义主体布局，内部有列表或宫格组件
            customList: this.getListView,
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
    }.width('100%').height('100%').backgroundColor('#eeeeee')
  }

  /**
   * 首屏加载（刷新第一页）
   */
  private loadFirst(): void {
    this.loadedOnce = true;
    this.isLoading = true;
    this.loadFailed = false;
    this.loginExpired = false;
    ApiManager.getInstance().requestDynamicFeed('', true).then((result: DynamicFeedResult) => {
      this.isLoading = false;
      if (result.success) {
        this.feedOffset = result.nextOffset;
        this.hasMore = result.hasMore;
      } else if (result.loginExpired) {
        this.loginExpired = true;
      } else {
        this.loadFailed = true;
      }
    }).catch(() => {
      this.isLoading = false;
      this.loadFailed = true;
    });
  }

  /**
   * 下拉刷新：回到最新（重新加载第一页）
   */
  private async refresh(): Promise<string> {
    let result: DynamicFeedResult = await ApiManager.getInstance().requestDynamicFeed('', true);
    if (result.success) {
      this.feedOffset = result.nextOffset;
      this.hasMore = result.hasMore;
      this.loginExpired = false;
      return '';
    }
    if (result.loginExpired) {
      this.loginExpired = true;
    }
    return '刷新失败';
  }

  /**
   * 上拉加载更多：按游标分页追加；翻尽后提示"没有更多了"且不再请求
   */
  private async loadMore(): Promise<string> {
    if (!this.hasMore) {
      return '没有更多了';
    }
    let result: DynamicFeedResult =
      await ApiManager.getInstance().requestDynamicFeed(this.feedOffset, false);
    if (result.success) {
      this.feedOffset = result.nextOffset;
      this.hasMore = result.hasMore;
      return '';
    }
    if (result.loginExpired) {
      this.loginExpired = true;
      return '登录已失效';
    }
    return '加载失败';
  }

  @Builder
  private getListView(_, onListStatus: (isListStart: boolean, isListEnd: boolean) => void) {
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
}
