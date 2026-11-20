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
import { StringUtil } from '../../utils/StringUtil';

@Component
export struct UserStateView {
  @StorageLink('isOhBiliLoggedIn') @Watch('onLoginStateChanged')
  loginState: boolean = false;
  @StorageLink('ohBiliDedeUserId') @Watch('onLoginStateChanged')
  dedeUserId: string = '';
  @State followingText: string = '-';
  @State followerText: string = '-';
  private fetching: boolean = false;

  aboutToAppear(): void {
    this.refreshRelationStat();
  }

  /** 登录态或 mid 变化：重新拉取（登出重置占位） */
  private onLoginStateChanged(): void {
    this.refreshRelationStat();
  }

  private refreshRelationStat(): void {
    if (!this.loginState || this.dedeUserId === '') {
      this.followingText = '-';
      this.followerText = '-';
      return;
    }
    let mid: number = parseInt(this.dedeUserId);
    if (isNaN(mid) || mid <= 0 || this.fetching) {
      return;
    }
    this.fetching = true;
    ApiManager.getInstance().requestRelationStat(mid).then((data) => {
      this.fetching = false;
      if (data == null) {
        return;
      }
      this.followingText = StringUtil.generateCN(data.following ?? 0);
      this.followerText = StringUtil.generateCN(data.follower ?? 0);
    }).catch(() => {
      this.fetching = false;
    });
  }

  build() {
    Row() {
      Column() {
        Text("-")
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.dynamic_state'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }.layoutWeight(1)

      Flex().width(1).height(20).backgroundColor($r('app.color.divider'))

      Column() {
        Text(this.followingText)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.attention'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }.layoutWeight(1)

      Flex().width(1).height(20).backgroundColor($r('app.color.divider'))

      Column() {
        Text(this.followerText)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.fans'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
      }.layoutWeight(1)
    }.width('100%').margin({ bottom: 16 })
  }
}
