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
import { SearchBar } from '@ohos/common';
import { SearchVideo, SearchVideoToBaseVideo } from '@ohos/common';
import { HomePullToRefresh } from '@ohos/common';
import { DataSourceManager } from '@ohos/common';
import { PopularItemView } from '@ohos/common';
import { ApiManager } from '@ohos/common';
import { BLog } from '@ohos/common';

@Entry
@Component
struct SearchResultPage {
  @State data: SearchVideo[] = [];
  private keyword: string = router.getParams()['keyword'];
  private scroller: Scroller = new Scroller();
  @State pn: number = 1;
  @State isLoading: boolean = false;
  @State isRateLimited: boolean = false;

  aboutToAppear() {
    BLog.i("SearchResultPage keyword:" + this.keyword);
    this.isLoading = true;
    ApiManager.getInstance().requestSearch(this.keyword, this.pn).then(result => {
      this.isLoading = false;
      this.updateSearchStatus();
    }).catch(() => {
      BLog.e("SearchResultPage search rejected, show status instead of infinite loading");
      this.isLoading = false;
      this.updateSearchStatus();
    })
  }

  aboutToDisappear() {
    DataSourceManager.getSearchSource().setData([]);
  }

  /**
   * 请求结束后同步风控状态（ApiManager.lastSearchBlocked 由 requestSearch 维护），
   * 供空态区分"无结果"与"请求过于频繁"。
   */
  private updateSearchStatus() {
    this.isRateLimited = ApiManager.getInstance().lastSearchBlocked;
  }

  build() {
    Column() {
      SearchBar({keyword: this.keyword})

      if (this.isLoading) {
        Text('数据加载中···')
          .width('100%').layoutWeight(1)
          .fontSize(14).textAlign(TextAlign.Center)
      } else {
        HomePullToRefresh({
          // 必传项，列表组件所绑定的数据
          data: $data,
          // 必传项，需绑定传入主体布局内的列表或宫格组件
          scroller: this.scroller,
          // 必传项，自定义主体布局，内部有列表或宫格组件
          customList: this.getListView,
          // 可选项，下拉刷新回调
          onRefresh: () => {
            return new Promise<string>((resolve, reject) => {
              this.pn = 1;
              ApiManager.getInstance().requestSearch(this.keyword, this.pn).then((videos: boolean) => {
                this.updateSearchStatus();
                resolve('');
              }).catch(() => {
                BLog.e("SearchResultPage onRefresh rejected");
                this.updateSearchStatus();
                resolve('');
              });
            });
          },
          // 可选项，上拉加载更多回调
          onLoadMore: () => {
            return new Promise<string>((resolve, reject) => {
              this.pn++;
              ApiManager.getInstance().requestSearch(this.keyword, this.pn).then((videos: boolean) => {
                this.updateSearchStatus();
                resolve('');
              }).catch(() => {
                BLog.e("SearchResultPage onLoadMore rejected");
                this.updateSearchStatus();
                resolve('');
              });
            });
          },
          customLoad: null,
          customRefresh: null,
        }).layoutWeight(1)
      }
    }
  }

  @Builder
  private getListView() {
    List({ scroller: this.scroller }) {
      if (DataSourceManager.getSearchSource().totalCount() == 0) {
        // 空态/风控区分提示，替代空白列表（保留下拉刷新可重试）
        ListItem() {
          Column({ space: 8 }) {
            Text(this.isRateLimited ? '请求过于频繁，请稍后再试' : '无结果')
              .fontSize(15)
              .fontColor('#ff999999')
            Text('下拉刷新重试')
              .fontSize(12)
              .fontColor('#ffbbbbbb')
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
        }
      }
      LazyForEach(DataSourceManager.getSearchSource(), (item: SearchVideo, index: number) => {
        ListItem() {
          PopularItemView({ item: SearchVideoToBaseVideo(item) })
        }
      }, item => item.bvid)
    }
    .backgroundColor('#ffffff')
    .width('100%')
    .padding({ left: 16, right: 16 })
    .divider({ strokeWidth: 1, color: '#ffeeeeee' })
    .edgeEffect(EdgeEffect.None)
  }

}