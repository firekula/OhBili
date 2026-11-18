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
import promptAction from '@ohos.promptAction'
import { BLog } from '../../utils/BLog';

@Component
export struct HomeSearchBar {
  private isShowHeatImg: boolean = true
  private barHeight: Length = 50
  @StorageLink("searchDefault") searchDefault: string = "";
  @StorageLink("isOhBiliLoggedIn") isLoggedIn: boolean = false;
  @StorageLink("ohBiliFace") userFace: string = "";

  build() {
    Row() {
      Image($r('app.media.ic_home_search'))
        .width(24)
        .height(24)
      // 假搜索框：不获焦（避免主页弹输入法及返回时焦点恢复），点击跳转独立搜索页。
      // 此前用 onFocus 导航，从搜索页返回主页时焦点恢复会再次触发 onFocus 导致无法返回主页
      TextInput({ placeholder: this.searchDefault })
        .focusable(false)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Search', params: {
            defaultKeyword: this.searchDefault
          } });
        })
      if (this.isShowHeatImg) {
        if (this.isLoggedIn && this.userFace !== '') {
          // 已登录：显示用户头像（加载中/失败回退占位图）
          Image(this.userFace)
            .width(36)
            .height(36)
            .borderRadius(12)
            .alt($r('app.media.ic_live_no_face_dark'))
        } else {
          Image($r('app.media.ic_live_no_face_dark'))
            .width(36)
            .height(36)
            .borderRadius(12)
            .onClick(() => {
              // 未登录点击头像进入扫码登录页（仅 phone Home 渲染本头像，
              // tablet Home 传 isShowHeatImg=false 不渲染）
              router.pushUrl({ url: 'pages/Login' });
            })
        }
      }
    }
    .width('100%')
    .height(this.barHeight)
    .borderRadius(25)
    .padding({ left: 20, right: 20 })
    .backgroundColor("#eeeeee")
  }
}

@Component
export struct SearchBar {
  private keyword?: ResourceStr
  private placeholder?: ResourceStr = $r('app.string.hint_text')

  build() {
    Row() {
      Image($r('app.media.ic_page_back'))
        .width(48)
        .height(48)
        .onClick(() => {
          router.back();
        }).padding(12)
      TextInput({ text: this.keyword, placeholder: this.placeholder })
        .layoutWeight(1)
        .margin({ left: 6, right: 12 })
        .onChange((value: string) => {
          this.keyword = value;
        }).border({
          width: 1,
          color: Color.Gray
        })
        .height(40)
        .backgroundColor(Color.White)
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
          // 提交事件文本为输入法上屏的权威值（API 12+ SubmitEvent.text），
          // 组合输入场景下与 onChange 同步值可能存在时序差异，事件文本优先、this.keyword 兜底
          let submitText: string = '';
          if (event != null && event.text != null) {
            submitText = event.text;
          }
          this.searchKeyword(submitText);
        })
      Text($r('app.string.search')).padding(12)
        .onClick(() => {
          this.searchKeyword();
        })
    }.width('100%').height(50)
    .padding({ left: 8, right: 8 })
  }

  private searchKeyword(submitText?: string) {
    let keywordText: string = '';
    if (submitText != null && submitText !== '') {
      keywordText = submitText;
      // 回车提交文本与 onChange 同步值对齐，保证回车/按钮两路一致
      this.keyword = submitText;
    } else if (this.keyword != null && this.keyword as string && (this.keyword as string) != "") {
      keywordText = this.keyword as string;
    }
    BLog.i("SearchBar searchKeyword: " + keywordText);
    if (keywordText != "") {
      router.pushUrl({ url: "pages/SearchResult", params: { keyword: keywordText } })
    } else if (this.placeholder != null && this.placeholder as string && this.placeholder != $r("app.string.hint_text")) {
      router.pushUrl({ url: "pages/SearchResult", params: { keyword: this.placeholder }})
    } else {
      promptAction.showToast({
        message: '关键字不能为空',
        duration: 2000
      })
    }
  }
}