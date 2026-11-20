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

import { HomeView } from './Home';
import { MineView } from './Mine';
import { WindowManager } from '@ohos/common';
import { ThemeUtil } from '@ohos/common';
import { MomentsView } from './Moments';

@Entry
@Component
struct Index {
  private tabsController: TabsController = new TabsController()
  @State currentIndex: number = 0;
  @StorageLink("isShowPage") isShowPage: boolean = true;

  @Builder TabBuilder(title: string | Resource, targetIndex: number, imgPath: Resource) {
    Column() {
      Image(imgPath)
        .fillColor(this.currentIndex === targetIndex ? '#1698CE' : $r('app.color.tab_inactive'))
        .size({ width: this.currentIndex === targetIndex ? 22 : 20,
          height: this.currentIndex === targetIndex ? 22 : 20 })
      Text(title)
        .margin({ top: 6 })
        .fontSize(this.currentIndex === targetIndex ? 14 : 12)
        .fontColor(this.currentIndex === targetIndex ? '#1698CE' : $r('app.color.tab_inactive'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .border({width: {top: 0.5}, color: $r('app.color.border')})
  }

  onPageShow() {
    this.isShowPage = true;
    // 延迟恢复系统栏布局：等返回转场动画（约 400ms）结束后再改窗口布局，
    // 避免转场期间窗口尺寸变化导致首页列表可见跳动；期间若已进入视频页则跳过
    setTimeout(() => {
      let cnt: number = AppStorage.get<number>('videoPageCount') ?? 0;
      if (cnt <= 0) {
        ThemeUtil.applyThemeBars();
      }
    }, 450);
  }

  onPageHide() {
    this.isShowPage = false;
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        HomeView()
      }
      .tabBar(this.TabBuilder($r('app.string.home'), 0, $r('app.media.ic_tab_bar_home')))

      TabContent() {
        MomentsView()
      }
      .tabBar(this.TabBuilder($r('app.string.moments'), 1, $r('app.media.ic_tab_bar_moments')))

      /*TabContent() {
        Text($r('app.string.func_develop')).fontSize(16)
      }
      .tabBar(this.TabBuilder($r('app.string.live_stream'), 2, $r('app.media.ic_tab_bar_shopping')))*/

      TabContent() {
        MineView()
      }
      .tabBar(this.TabBuilder($r('app.string.mine'), 2, $r('app.media.ic_tab_bar_mine')))
    }.scrollable(false)
    .barMode(BarMode.Fixed)
    .onChange((index) => {
      this.currentIndex = index
    })
  }
}