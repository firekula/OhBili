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

import { ApiManager } from '../../network/ApiManager';
import { NavHelper } from '../../utils/NavHelper';

/**
 * 投币弹窗：选择 1/2 枚硬币 + 可选"同时点赞"，确认后 coinVideo 提交；
 * 成功回调 onResult(multiply, liked)，multiply>0 表示已投币枚数，liked 表示是否同时点赞。
 * 业务码：34004 太频繁 / 34005 已投满 / -104 硬币不足 / -101 登录失效。
 */
@CustomDialog
export struct CoinDialog {
  controller?: CustomDialogController;
  private aid: number = 0;
  onResult: (multiply: number, liked: boolean) => void = () => {
  };
  @State multiply: number = 1;
  @State selectLike: boolean = true;
  @State sending: boolean = false;

  build() {
    Column() {
      Text('给这个视频投个币吧')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: 20, bottom: 16 })

      Row({ space: 16 }) {
        this.CoinOption(1)
        this.CoinOption(2)
      }
      .margin({ bottom: 12 })

      Row() {
        Checkbox()
          .select(this.selectLike)
          .selectedColor('#fb7299')
          .width(18)
          .height(18)
          .onChange((value: boolean) => {
            this.selectLike = value;
          })
        Text('同时点赞视频')
          .fontSize(13)
          .fontColor($r('app.color.text_mid'))
          .margin({ left: 8 })
      }
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 })

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor($r('app.color.text_mid'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.controller.close();
          })
        Divider().vertical(true).height(24)
        Text(this.sending ? '投币中...' : '投币')
          .fontSize(15)
          .fontColor('#fb7299')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.confirmCoin();
          })
      }
      .width('100%')
    }
    .width('92%')
    .borderRadius(16)
    .backgroundColor($r('app.color.surface'))
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  /**
   * 单枚/双枚硬币选项（选中态粉色描边）
   */
  @Builder
  private CoinOption(count: number) {
    Column() {
      Text(count == 1 ? '①' : '②')
        .fontSize(28)
        .fontColor(this.multiply == count ? '#fb7299' : $r('app.color.text_tertiary'))
      Text(count == 1 ? '投一枚' : '投两枚')
        .fontSize(12)
        .fontColor(this.multiply == count ? '#fb7299' : $r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width(96)
    .padding({ top: 14, bottom: 12 })
    .borderRadius(12)
    .backgroundColor($r('app.color.surface_soft'))
    .border({
      width: this.multiply == count ? 1.5 : 0,
      color: '#fb7299'
    })
    .onClick(() => {
      this.multiply = count;
    })
  }

  /**
   * 确认投币：coinVideo 提交，业务码分流提示；
   * 34005（已投满）视为已投过币回调关闭
   */
  private confirmCoin(): void {
    if (this.sending) {
      return;
    }
    this.sending = true;
    ApiManager.getInstance().coinVideo(this.aid, this.multiply, this.selectLike)
      .then((code: number) => {
        this.sending = false;
        if (code == 0) {
          this.showToast('投币成功');
          this.controller.close();
          this.onResult(this.multiply, this.selectLike);
          return;
        }
        if (code == 34005) {
          this.showToast('已经投过币啦');
          this.controller.close();
          this.onResult(0, false);
          return;
        }
        if (code == -101) {
          this.showToast('登录已失效，请重新登录');
          NavHelper.goLogin();
          return;
        }
        if (code == 34004) {
          this.showToast('操作太频繁了，请稍后再试');
          return;
        }
        if (code == -104) {
          this.showToast('硬币不足');
          return;
        }
        this.showToast('投币失败，请重试');
      }).catch(() => {
        this.sending = false;
        this.showToast('投币失败，请重试');
      });
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}
