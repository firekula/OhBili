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

import promptAction from '@ohos.promptAction'
import router from '@ohos.router';
import { NavHelper } from '../../utils/NavHelper';

@Component
export struct UserHeadView {
  @StorageLink('isOhBiliLoggedIn') loginState: boolean = false;
  @StorageLink('ohBiliUname') uname: string = '';
  @StorageLink('ohBiliFace') face: string = '';
  @StorageLink('ohBiliDedeUserId') dedeUserId: string = '';
  build() {
    Row() {
      if (this.loginState && this.face !== '') {
        // 已登录：显示用户头像，加载中/失败回退占位图
        Image(this.face)
          .width(64)
          .height(64)
          .borderRadius(32)
          .margin({ left: 16, right: 16 })
          .alt($r("app.media.ic_live_no_face_dark"))
      } else {
        Image($r("app.media.ic_live_no_face_dark"))
          .width(64)
          .height(64)
          .borderRadius(32)
          .margin({ left: 16, right: 16 })
      }

      if (!this.loginState)
      {
        Text($r('app.string.click_login'))
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      else if (this.uname !== '')
      {
        Text(this.uname)
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      else
      {
        // 登录成功但昵称尚未从导航接口返回时的短暂兜底文案
        Text($r('app.string.logged_in'))
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }

      Blank()

      Image($r('app.media.ic_arrow_right'))
        .objectFit(ImageFit.Auto)
        .width(20)
        .height(20)
        .margin({ left: 16, right: 16 })

    }.margin({ top: 32, bottom: 32 }).width('100%')
    .justifyContent(FlexAlign.Start)
    .onClick(() => {
      if(!this.loginState){
        router.pushUrl({url: "pages/Login"})
        return;
      }
      // 已登录：进入自己的空间页（tablet 经设备门禁静默无操作）
      let mid: number = parseInt(this.dedeUserId);
      if (!isNaN(mid) && mid > 0) {
        NavHelper.goUserSpace(mid);
      }
    })
  }
}