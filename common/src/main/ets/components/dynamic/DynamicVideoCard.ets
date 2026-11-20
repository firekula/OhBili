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
import { MajorArchive, ModuleAuthor, parseDurationTextToSeconds,
  parseCountTextToNumber } from '../../model/response/DynamicFeedResponse';
import { BaseVideo, EmptyBaseVideo, EmptyStat, Owner, Stat } from '../../model/response/Response';
import { StringUtil } from '../../utils/StringUtil';

/**
 * 视频投稿动态卡片：封面 16:9 + 时长角标 + 标题 + 播放/弹幕数；
 * 点击构造 BaseVideo（填充已知字段）跳转播放页。
 */
@Component
export struct DynamicVideoCard {
  private archive: MajorArchive;
  private author?: ModuleAuthor;

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(this.archive.cover ?? '')
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.bg_default_show'))
        if (this.archive.duration_text != null && this.archive.duration_text !== '') {
          Text(this.archive.duration_text)
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .borderRadius(2)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .margin(4)
        }
      }
      .width('100%')
      .aspectRatio(1.78)
      .borderRadius(4)
      .clip(true)

      Text(this.archive.title ?? '')
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
        .width('100%')
        .textAlign(TextAlign.Start)

      Row() {
        Image($r('app.media.ic_play_count'))
          .width(14)
          .height(14)
        Text(StringUtil.generateCN(this.viewCount()))
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 3, right: 10 })
        Image($r('app.media.ic_danmakus'))
          .width(14)
          .height(14)
        Text(StringUtil.generateCN(this.danmakuCount()))
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 3 })
      }
      .margin({ top: 4 })
      .width('100%')
    }
    .width('100%')
    .borderRadius(4)
    .backgroundColor($r('app.color.surface_soft'))
    .padding(8)
    .onClick(() => {
      router.pushUrl({ url: 'pages/Video', params: { vInfo: this.buildBaseVideo() } });
    })
  }

  private viewCount(): number {
    if (this.archive.stat == null) {
      return 0;
    }
    return parseCountTextToNumber(this.archive.stat.view ?? '');
  }

  private danmakuCount(): number {
    if (this.archive.stat == null) {
      return 0;
    }
    return parseCountTextToNumber(this.archive.stat.danmaku ?? '');
  }

  /**
   * 构造播放页路由参数：复用 EmptyBaseVideo(bvid) 后填充已知字段，
   * 播放页按 bvid 自行加载完整数据，缺失字段有默认值。
   */
  private buildBaseVideo(): BaseVideo {
    let video: BaseVideo = EmptyBaseVideo(this.archive.bvid ?? '');
    video.title = this.archive.title ?? '';
    video.pic = this.archive.cover ?? '';
    video.desc = this.archive.desc ?? '';
    video.pubdate = this.author == null ? 0 : (this.author.pub_ts ?? 0);
    video.duration = parseDurationTextToSeconds(this.archive.duration_text ?? '');
    let mid: number = this.author == null ? 0 : this.author.mid;
    let owner: Owner = {
      mid: mid,
      name: this.author == null ? '' : (this.author.name ?? ''),
      face: this.author == null ? '' : (this.author.face ?? '')
    };
    video.owner = owner;
    let stat: Stat = EmptyStat();
    stat.view = this.viewCount();
    stat.danmaku = this.danmakuCount();
    video.stat = stat;
    return video;
  }
}
