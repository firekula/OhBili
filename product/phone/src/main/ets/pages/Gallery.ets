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

/**
 * 全屏图片预览页：黑底 Swiper（初始下标）+ Image(Contain)，
 * 左右滑动切换，点击任意处返回。
 * 路由参数 { urls: string[], index: number }
 */
@Entry
@Component
struct Gallery {
  private params: object = router.getParams() as object;
  private urls: string[] = this.params == null ? [] : this.params['urls'];
  @State currentIndex: number = this.params == null ? 0 : this.params['index'];

  build() {
    Stack() {
      if (this.urls != null && this.urls.length > 0) {
        Swiper() {
          ForEach(this.urls, (url: string) => {
            Image(url)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .alt($r('app.media.bg_default_show'))
          }, (url: string) => url)
        }
        .width('100%')
        .height('100%')
        .index(this.currentIndex)
        .loop(false)
        .indicator(false)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onClick(() => {
      router.back();
    })
  }
}
