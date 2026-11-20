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

import { MajorDrawItem, ModuleAuthor, ModuleDynamic } from '../../model/response/DynamicFeedResponse';
import { NavHelper } from '../../utils/NavHelper';
import { DynamicVideoCard } from './DynamicVideoCard';
import { DynamicTextView } from './DynamicTextView';
import { DynamicDrawGrid } from './DynamicDrawGrid';

/**
 * 转发内容：转发理由（DynamicTextView）+ 嵌套原动态一层内复用 major 分发
 * （archive→DynamicVideoCard、draw/opus→DynamicTextView+DynamicDrawGrid、其余→文字提示）；
 * orig 缺失/无有效内容显示"原动态已失效"。
 */
@Component
export struct DynamicForwardContent {
  /** 原动态（可能缺失——已删除/失效） */
  private orig?: ModuleDynamic;
  /** 转发理由 */
  private reason: string;
  /** 原动态作者（orig.module_author，可能缺失） */
  private origAuthor?: ModuleAuthor;

  build() {
    Column() {
      if (this.reason != null && this.reason !== '') {
        DynamicTextView({ text: this.reason })
          .margin({ bottom: 8 })
      }

      Column() {
        if (!this.hasOrigContent()) {
          // 原动态已删除/失效
          Text("原动态已失效")
            .fontSize(13)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        } else {
          if (this.origAuthor != null) {
            Row() {
              Image(this.origAuthor.face ?? '')
                .width(24)
                .height(24)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
                .alt($r('app.media.ic_comment_avatar_default'))
                .onClick(() => {
                  NavHelper.goUserSpace(this.origAuthor.mid);
                })
              Text(this.origAuthor.name ?? '')
                .fontSize(12)
                .fontColor($r('app.color.text_mid'))
                .maxLines(1)
                .margin({ left: 6 })
                .layoutWeight(1)
                .onClick(() => {
                  NavHelper.goUserSpace(this.origAuthor.mid);
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ bottom: 6 })
          }
          this.OrigBody()
        }
      }
      .width('100%')
      .padding(8)
      .borderRadius(6)
      .backgroundColor($r('app.color.surface_soft'))
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 嵌套原动态主体分发（一层，不递归 orig）
   */
  @Builder
  private OrigBody() {
    if (this.origMajor() != null && this.origMajor().archive != null) {
      // 原动态为视频：可点击进播放页
      DynamicVideoCard({ archive: this.origMajor().archive, author: this.origAuthor })
    } else if (this.hasOrigDraw()) {
      // 原动态为旧版图文
      Column() {
        if (this.origDescText() !== '') {
          DynamicTextView({ text: this.origDescText() })
        }
        if (this.origDrawImages().length > 0) {
          DynamicDrawGrid({ images: this.origDrawImages() })
            .margin({ top: 6 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    } else if (this.hasOrigOpus()) {
      // 原动态为新版图文
      Column() {
        if (this.origOpusSummaryText() !== '') {
          DynamicTextView({ text: this.origOpusSummaryText() })
        }
        if (this.origOpusPics().length > 0) {
          DynamicDrawGrid({ images: this.origOpusPics() })
            .margin({ top: 6 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    } else if (this.origDescText() !== '') {
      // 其余类型：文字提示降级
      DynamicTextView({ text: this.origDescText() })
    } else {
      Text("原动态已失效")
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .textAlign(TextAlign.Start)
    }
  }

  /**
   * 原动态是否有可渲染内容
   */
  private hasOrigContent(): boolean {
    if (this.orig == null) {
      return false;
    }
    return this.orig.major != null || (this.orig.desc != null
      && this.orig.desc.text != null && this.orig.desc.text !== '');
  }

  private origMajor() {
    if (this.orig == null) {
      return undefined;
    }
    return this.orig.major;
  }

  private hasOrigDraw(): boolean {
    let major = this.origMajor();
    return major != null && major.draw != null && major.draw.items != null
      && major.draw.items.length > 0;
  }

  private origDrawImages(): MajorDrawItem[] {
    let major = this.origMajor();
    if (major == null || major.draw == null || major.draw.items == null) {
      return [];
    }
    return major.draw.items;
  }

  private hasOrigOpus(): boolean {
    let major = this.origMajor();
    return major != null && major.opus != null;
  }

  private origOpusSummaryText(): string {
    let major = this.origMajor();
    if (major == null || major.opus == null || major.opus.summary == null) {
      return '';
    }
    return major.opus.summary.text ?? '';
  }

  private origOpusPics(): MajorDrawItem[] {
    let major = this.origMajor();
    if (major == null || major.opus == null || major.opus.pics == null) {
      return [];
    }
    return major.opus.pics;
  }

  private origDescText(): string {
    if (this.orig == null || this.orig.desc == null) {
      return '';
    }
    return this.orig.desc.text ?? '';
  }
}
