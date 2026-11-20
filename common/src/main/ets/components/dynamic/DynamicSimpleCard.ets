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

import promptAction from '@ohos.promptAction';

/**
 * 长尾类型（专栏/番剧/合集/直播等）降级卡片：
 * 封面 + 标题/文字摘要的简化卡片；点击提示"该类型内容暂不支持查看"，不跳转。
 */
@Component
export struct DynamicSimpleCard {
  /** 标题 */
  private title: string;
  /** 封面（可缺省，缺省时纯文字布局） */
  private cover: string;
  /** 文字摘要 */
  private desc: string;
  /** 类型名（如"专栏"/"番剧"角标） */
  private typeName: string;

  build() {
    Row() {
      if (this.cover != null && this.cover !== '') {
        Image(this.cover)
          .width(96)
          .height(60)
          .borderRadius(4)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.bg_default_show'))
      }
      Column() {
        Text(this.title != null && this.title !== '' ? this.title : this.desc)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        if (this.typeName != null && this.typeName !== '') {
          Text(this.typeName)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
            .borderRadius(3)
            .border({ width: 0.5, color: $r('app.color.border') })
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .margin({ top: 5 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: this.cover != null && this.cover !== '' ? 8 : 0 })
    }
    .width('100%')
    .padding(8)
    .borderRadius(6)
    .backgroundColor($r('app.color.surface_soft'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      promptAction.showToast({
        message: '该类型内容暂不支持查看',
        duration: 1500
      });
    })
  }
}
