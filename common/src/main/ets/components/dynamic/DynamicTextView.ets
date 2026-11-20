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

/** 折叠判定阈值（字符数启发式：不低于该值的长文显示展开/收起按钮） */
const TEXT_EXPAND_THRESHOLD: number = 120;

/**
 * 动态文字内容：默认最多 6 行，超长折叠显示"展开"，点击切换折叠态；空文本不渲染。
 */
@Component
export struct DynamicTextView {
  @Prop text: string;
  @State expanded: boolean = false;

  build() {
    if (this.text != null && this.text !== '') {
      Column() {
        Text(this.text)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .lineHeight(20)
          .maxLines(this.expanded ? 100 : 6)
          .textOverflow({ overflow: this.expanded ? TextOverflow.None : TextOverflow.Ellipsis })
        if (this.isLongText()) {
          Text(this.expanded ? '收起' : '展开')
            .fontSize(12)
            .fontColor('#1698CE')
            .margin({ top: 4 })
            .onClick(() => {
              this.expanded = !this.expanded;
            })
        }
      }.width('100%')
    }
  }

  private isLongText(): boolean {
    return this.text != null && this.text.length >= TEXT_EXPAND_THRESHOLD;
  }
}
