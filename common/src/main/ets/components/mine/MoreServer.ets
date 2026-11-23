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
import router from '@ohos.router'
import { ApiManager } from '../../network/ApiManager'
import { NavHelper } from '../../utils/NavHelper'

/**
 * 更多服务列表：消息中心（phone，未读徽标）/设置/问题反馈/关于。
 * showMessage 默认 false（tablet 不展示消息中心入口），phone 的 Mine 页传 true。
 */
@Component
export struct MoreServerView {
  private showMessage: boolean = false;
  @StorageLink('isOhBiliLoggedIn') mLoggedIn: boolean = false;
  @StorageLink('ohBiliMsgUnreadTotal') mUnreadTotal: number = 0;

  aboutToAppear() {
    if (this.showMessage) {
      this.refreshUnread();
    }
  }

  /**
   * 刷新消息未读总数（写 AppStorage 供徽标绑定）
   */
  private refreshUnread(): void {
    if (!this.mLoggedIn) {
      this.mUnreadTotal = 0;
      return;
    }
    ApiManager.getInstance().requestMsgFeedUnread().then((data) => {
      if (data == null) {
        return;
      }
      let total: number = (data.reply ?? 0) + (data.at ?? 0)
        + (data.like ?? 0) + (data.sys ?? 0);
      AppStorage.setOrCreate('ohBiliMsgUnreadTotal', total);
    }).catch(() => {
    });
  }

  @Builder
  unreadBadge() {
    if (this.mUnreadTotal > 0) {
      Text(this.mUnreadTotal > 99 ? '99+' : '' + this.mUnreadTotal)
        .fontSize(10)
        .fontColor(Color.White)
        .backgroundColor('#fb7299')
        .borderRadius(9)
        .maxLines(1)
        .constraintSize({ minWidth: 18 })
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .textAlign(TextAlign.Center)
        .margin({ right: 8 })
    }
  }

  build() {
    Column() {
      Text($r('app.string.more_service'))
        .fontSize(18)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium).margin({ left: 16, top: 24, right: 16, bottom: 24 })

      if (this.showMessage) {
        Row() {
          Image($r('app.media.ic_upper_comments'))
            .width(24)
            .height(24)
          Text($r('app.string.msg_center'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
          Blank()
          this.unreadBadge()
          Image($r('app.media.ic_arrow_right'))
            .objectFit(ImageFit.Auto)
            .width(20)
            .height(20)
        }.width('100%')
        .padding({ left: 24, top: 16, right: 12, bottom: 16 })
        .onClick(() => {
          NavHelper.goMessage();
        })
      }

      Row() {
        Image($r('app.media.ic_setting'))
          .width(24)
          .height(24)
        Text($r('app.string.setting'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        Blank()
        Image($r('app.media.ic_arrow_right'))
          .objectFit(ImageFit.Auto)
          .width(20)
          .height(20)
      }.width('100%')
      .padding({ left: 24, top: 16, right: 12, bottom: 16 })
      .onClick(() => {
        router.pushUrl({ url: "pages/Setting" });
      })

      Row() {
        Image($r('app.media.ic_feedback'))
          .width(24)
          .height(24)
        Text($r('app.string.problem_feedback'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        Blank()
        Image($r('app.media.ic_arrow_right'))
          .objectFit(ImageFit.Auto)
          .width(20)
          .height(20)
      }.width('100%')
      .padding({ left: 24, top: 16, right: 12, bottom: 16 })
      .onClick(() => {
        router.pushUrl({ url: "pages/Feedback" });
      })

      Row() {
        Image($r('app.media.ic_about'))
          .width(24)
          .height(24)
        Text($r('app.string.about'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        Blank()
        Image($r('app.media.ic_arrow_right'))
          .objectFit(ImageFit.Auto)
          .width(20)
          .height(20)
      }.width('100%')
      .padding({ left: 24, top: 16, right: 12, bottom: 16 })
      .onClick(() => {
        router.pushUrl({ url: "pages/About" });
      })

    }.width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
  }
}
