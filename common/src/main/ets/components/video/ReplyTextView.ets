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

import { ReplyEmote } from './../../model/response/ReplyResponse';

/** 富文本分段：text 段或 emote 图片段（二选一，emoteUrl 非空为图片段） */
export interface ReplyTextSegment {
  key: string
  text: string
  emoteUrl: string
  /** 是否为大表情（emote.size==2），尺寸放大渲染 */
  emoteBig: boolean
}

/** 评论富文本解析：将 message 中命中 emote 映射的 [表情名] 占位替换为图片段 */
export class ReplyTextParser {
  static parse(message: string, emote: Record<string, ReplyEmote> | null): ReplyTextSegment[] {
    let segments: ReplyTextSegment[] = [];
    if (message == null || message.length === 0) {
      return segments;
    }
    if (emote == null) {
      segments.push({ key: 't0', text: message, emoteUrl: '', emoteBig: false });
      return segments;
    }
    let textStart: number = 0;
    let idx: number = 0;
    let segCount: number = 0;
    while (idx < message.length) {
      if (message.charAt(idx) === '[') {
        let closeIdx: number = message.indexOf(']', idx);
        if (closeIdx > idx) {
          let token: string = message.substring(idx, closeIdx + 1);
          let emoteItem: ReplyEmote = emote[token];
          if (emoteItem != null && emoteItem.url != null && emoteItem.url.length > 0) {
            if (idx > textStart) {
              segments.push({
                key: 't' + (segCount++),
                text: message.substring(textStart, idx),
                emoteUrl: '',
                emoteBig: false
              });
            }
            segments.push({
              key: 'e' + (segCount++),
              text: token,
              emoteUrl: emoteItem.url,
              emoteBig: emoteItem.size === 2
            });
            idx = closeIdx + 1;
            textStart = idx;
            continue;
          }
        }
      }
      idx++;
    }
    if (textStart < message.length) {
      segments.push({
        key: 't' + (segCount++),
        text: message.substring(textStart),
        emoteUrl: '',
        emoteBig: false
      });
    }
    return segments;
  }
}

/**
 * 评论富文本：文本 + [doge] 等 emote 表情内联渲染（ImageSpan）
 */
@Component
export struct ReplyTextView {
  private message: string = '';
  private emote: Record<string, ReplyEmote> | null = null;
  private fontSize: number = 16;
  private fontColor: ResourceColor = $r('app.color.text_primary');
  /** 最大行数（0 = 不限） */
  private maxLines: number = 0;
  /** 前缀文本（楼中楼预览的用户名等），与前缀颜色配对使用 */
  private prefix: string = '';
  private prefixColor: ResourceColor = $r('app.color.text_primary');

  build() {
    Text() {
      if (this.prefix.length > 0) {
        Span(this.prefix)
          .fontSize(this.fontSize)
          .fontColor(this.prefixColor)
      }
      ForEach(ReplyTextParser.parse(this.message, this.emote), (seg: ReplyTextSegment) => {
        if (seg.emoteUrl.length > 0) {
          ImageSpan(seg.emoteUrl)
            .width(seg.emoteBig ? this.fontSize * 2 : this.fontSize * 1.15)
            .height(seg.emoteBig ? this.fontSize * 2 : this.fontSize * 1.15)
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else {
          Span(seg.text)
            .fontSize(this.fontSize)
            .fontColor(this.fontColor)
        }
      }, (seg: ReplyTextSegment) => seg.key + '_' + seg.text)
    }
    .fontSize(this.fontSize)
    .fontColor(this.fontColor)
    .width('100%')
    .textAlign(TextAlign.Start)
    .maxLines(this.maxLines > 0 ? this.maxLines : 100)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}
