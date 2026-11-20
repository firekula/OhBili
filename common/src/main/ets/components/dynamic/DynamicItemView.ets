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

import { DynamicItem, DynamicMajor, MajorArticle, MajorDrawItem, MajorLive,
  MajorPgc, MajorUgcSeason, ModuleAuthor, ModuleDynamic, LivePlayInfo,
  parseLiveRcmdInfo } from '../../model/response/DynamicFeedResponse';
import { NavHelper } from '../../utils/NavHelper';
import { DynamicVideoCard } from './DynamicVideoCard';
import { DynamicTextView } from './DynamicTextView';
import { DynamicDrawGrid } from './DynamicDrawGrid';
import { DynamicForwardContent } from './DynamicForwardContent';
import { DynamicSimpleCard } from './DynamicSimpleCard';

/**
 * 动态条目分发容器：作者栏 + 按类型分发内容（转发/视频/图文/纯文字）+ 底部互动数据栏。
 * orig → DynamicForwardContent（转发）；major.archive → DynamicVideoCard；
 * major.draw/opus 或 desc → DynamicTextView + DynamicDrawGrid。
 */
@Component
export struct DynamicItemView {
  private item: DynamicItem;
  /** 新版直播动态解析结果（aboutToAppear 解析一次，无 live_rcmd 时为 null） */
  private liveInfo: LivePlayInfo | null = null;

  aboutToAppear() {
    this.liveInfo = parseLiveRcmdInfo(this.major());
  }

  build() {
    Column() {
      this.AuthorBar()
      this.ContentBody()
      this.StatBar()
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(8)
    .padding(12)
  }

  @Builder
  private AuthorBar() {
    Row() {
      Image(this.authorFace())
        .width(40)
        .height(40)
        .borderRadius(20)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.ic_comment_avatar_default'))
        .onClick(() => {
          NavHelper.goUserSpace(this.authorMid());
        })
      Column() {
        Text(this.authorName())
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
        Text(this.pubTimeText())
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 2 })
          .maxLines(1)
      }
      .margin({ left: 8 })
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        NavHelper.goUserSpace(this.authorMid());
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ContentBody() {
    if (this.hasOrig()) {
      // 转发动态：desc 为转发理由，orig 为原动态
      DynamicForwardContent({
        orig: this.origDynamic(),
        reason: this.descText(),
        origAuthor: this.origAuthor()
      })
        .margin({ top: 8 })
    } else if (this.major() != null && this.major().archive != null) {
      // 视频投稿动态
      DynamicVideoCard({ archive: this.major().archive, author: this.author() })
        .margin({ top: 8 })
    } else if (this.hasDraw()) {
      // 旧版图文动态（major.draw.items）
      Column() {
        if (this.descText() !== '') {
          DynamicTextView({ text: this.descText() })
        }
        if (this.drawImages().length > 0) {
          DynamicDrawGrid({ images: this.drawImages() })
            .margin({ top: 6 })
        }
      }
      .margin({ top: 8 })
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else if (this.hasOpus()) {
      // 新版图文动态（major.opus：title/summary/pics）
      Column() {
        if (this.opusTitle() !== '') {
          Text(this.opusTitle())
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        if (this.opusSummaryText() !== '') {
          DynamicTextView({ text: this.opusSummaryText() })
            .margin({ top: 4 })
        }
        if (this.opusPics().length > 0) {
          DynamicDrawGrid({ images: this.opusPics() })
            .margin({ top: 6 })
        }
      }
      .margin({ top: 8 })
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else if (this.major() != null && this.major().article != null) {
      // 专栏动态：降级简化卡片
      DynamicSimpleCard({
        title: this.major().article.title ?? '',
        cover: this.articleCover(),
        desc: this.major().article.desc ?? '',
        typeName: '专栏'
      })
        .margin({ top: 8 })
    } else if (this.major() != null && this.major().pgc != null) {
      // 番剧/影视动态：降级简化卡片
      DynamicSimpleCard({
        title: this.major().pgc.title ?? '',
        cover: this.major().pgc.cover ?? '',
        desc: '',
        typeName: '番剧'
      })
        .margin({ top: 8 })
    } else if (this.major() != null && this.major().ugc_season != null) {
      // 合集动态：降级简化卡片
      DynamicSimpleCard({
        title: this.major().ugc_season.title ?? '',
        cover: this.major().ugc_season.cover ?? '',
        desc: '',
        typeName: '合集'
      })
        .margin({ top: 8 })
    } else if (this.major() != null && this.major().live != null) {
      // 直播动态：降级简化卡片
      DynamicSimpleCard({
        title: this.major().live.title ?? '',
        cover: this.major().live.cover ?? '',
        desc: '',
        typeName: '直播'
      })
        .margin({ top: 8 })
    } else if (this.liveInfo != null) {
      // 新版直播动态（major.live_rcmd）：降级简化卡片
      DynamicSimpleCard({
        title: this.liveInfo.title ?? '',
        cover: this.liveInfo.cover ?? '',
        desc: this.liveInfo.area_name ?? '',
        typeName: '直播'
      })
        .margin({ top: 8 })
    } else if (this.major() != null) {
      // 未知 major 类型：desc 文字降级，无 desc 时占位提示（不崩溃不空白）
      this.UnknownMajorBody()
    } else if (this.descText() !== '') {
      // 纯文字动态（无 major 有 desc），超长折叠
      DynamicTextView({ text: this.descText() })
        .margin({ top: 8 })
    } else {
      // 无 major 无 desc 的未知类型：文字占位（不空白）
      Text('暂不支持的内容类型')
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .margin({ top: 8 })
        .textAlign(TextAlign.Start)
    }
  }

  /**
   * 未知 major 类型降级：优先 desc 文字，无 desc 时占位提示
   */
  @Builder
  private UnknownMajorBody() {
    if (this.descText() !== '') {
      DynamicTextView({ text: this.descText() })
        .margin({ top: 8 })
    } else {
      Text('暂不支持的内容类型')
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .margin({ top: 8 })
        .textAlign(TextAlign.Start)
    }
  }

  @Builder
  private StatBar() {
    Row() {
      Row() {
        Image($r('app.media.ic_upper_shares'))
          .width(16)
          .height(16)
        Text(this.statText('forward'))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ left: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Row() {
        Image($r('app.media.ic_upper_comments'))
          .width(16)
          .height(16)
        Text(this.statText('comment'))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ left: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Row() {
        Image($r('app.media.ic_upper_likes'))
          .width(16)
          .height(16)
        Text(this.statText('like'))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ left: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .margin({ top: 8 })
    .padding({ top: 8 })
    .border({ width: { top: 0.5 }, color: $r('app.color.divider') })
  }

  private author(): ModuleAuthor | undefined {
    if (this.item == null || this.item.modules == null) {
      return undefined;
    }
    return this.item.modules.module_author;
  }

  private major(): DynamicMajor | undefined {
    if (this.item == null || this.item.modules == null || this.item.modules.module_dynamic == null) {
      return undefined;
    }
    return this.item.modules.module_dynamic.major;
  }

  private authorMid(): number {
    let author = this.author();
    return author == null ? 0 : author.mid;
  }

  private authorName(): string {
    let author = this.author();
    return author == null ? '' : (author.name ?? '');
  }

  private authorFace(): string {
    let author = this.author();
    return author == null ? '' : (author.face ?? '');
  }

  private pubTimeText(): string {
    let author = this.author();
    if (author == null) {
      return '';
    }
    let time: string = author.pub_time ?? '';
    let action: string = author.pub_action ?? '';
    if (action === '' && this.hasOrig()) {
      // 转发动态：B 站 API 未回填 pub_action 时对齐官方展示"转发了动态"
      action = '转发了动态';
    }
    if (action !== '' && time !== '') {
      return action + ' · ' + time;
    }
    return action !== '' ? action : time;
  }

  private descText(): string {
    if (this.item == null || this.item.modules == null || this.item.modules.module_dynamic == null
      || this.item.modules.module_dynamic.desc == null) {
      return '';
    }
    return this.item.modules.module_dynamic.desc.text ?? '';
  }

  /**
   * 是否为转发动态（module_dynamic.orig 存在）
   */
  private hasOrig(): boolean {
    if (this.item == null || this.item.modules == null || this.item.modules.module_dynamic == null) {
      return false;
    }
    return this.item.modules.module_dynamic.orig != null;
  }

  private origDynamic(): ModuleDynamic | undefined {
    if (this.item == null || this.item.modules == null || this.item.modules.module_dynamic == null) {
      return undefined;
    }
    return this.item.modules.module_dynamic.orig;
  }

  private origAuthor(): ModuleAuthor | undefined {
    let orig = this.origDynamic();
    if (orig == null) {
      return undefined;
    }
    return orig.module_author;
  }

  /**
   * 是否为旧版图文动态（major.draw.items 非空）
   */
  private hasDraw(): boolean {
    let major = this.major();
    return major != null && major.draw != null && major.draw.items != null
      && major.draw.items.length > 0;
  }

  /**
   * 旧版图文动态图片列表
   */
  private drawImages(): MajorDrawItem[] {
    let major = this.major();
    if (major == null || major.draw == null || major.draw.items == null) {
      return [];
    }
    return major.draw.items;
  }

  /**
   * 是否为新版图文动态（major.opus 存在）
   */
  private hasOpus(): boolean {
    let major = this.major();
    return major != null && major.opus != null;
  }

  private opusTitle(): string {
    let major = this.major();
    if (major == null || major.opus == null || major.opus.title == null) {
      return '';
    }
    return major.opus.title.text ?? '';
  }

  private opusSummaryText(): string {
    let major = this.major();
    if (major == null || major.opus == null || major.opus.summary == null) {
      return '';
    }
    return major.opus.summary.text ?? '';
  }

  private opusPics(): MajorDrawItem[] {
    let major = this.major();
    if (major == null || major.opus == null || major.opus.pics == null) {
      return [];
    }
    return major.opus.pics;
  }

  /**
   * 专栏封面（covers 数组取第一张，缺省返回空串）
   */
  private articleCover(): string {
    let major = this.major();
    if (major == null || major.article == null || major.article.covers == null
      || major.article.covers.length === 0) {
      return '';
    }
    return major.article.covers[0] ?? '';
  }

  /**
   * 互动计数文本，缺失显示"--"（kind: forward / comment / like）
   */
  private statText(kind: string): string {
    if (this.item == null || this.item.modules == null || this.item.modules.module_stat == null) {
      return '--';
    }
    let stat = this.item.modules.module_stat;
    let count: number | undefined = undefined;
    if (kind === 'forward' && stat.forward != null) {
      count = stat.forward.count;
    } else if (kind === 'comment' && stat.comment != null) {
      count = stat.comment.count;
    } else if (kind === 'like' && stat.like != null) {
      count = stat.like.count;
    }
    return count == null ? '--' : count.toString();
  }
}
