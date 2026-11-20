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
import { ReplyItem } from './../../model/response/ReplyResponse';
import { ResUtils } from './../../utils/ResUtils';
import { StringUtil } from './../../utils/StringUtil';
import { LoginHelper } from './../../utils/LoginHelper';
import { ReplyTextView } from './ReplyTextView';

@Component
export struct ReplyItemView {
  private item: ReplyItem;
  private isShowReply: boolean = false;
  private onItemClick: () => void = () => {}
  /** 点赞/点踩（请求动作 0=取消赞 1=赞 2=踩 3=取消踩；item.action 模型值仍为 0/1/2） */
  private onAction: (item: ReplyItem, action: number) => void = () => {}
  /** 回复该评论（唤起评论输入框） */
  private onReply: (item: ReplyItem) => void = () => {}
  /** 分享（复制评论内容） */
  private onShare: (item: ReplyItem) => void = () => {}
  /** 删除自己的评论（仅本人评论的长按菜单中显示） */
  private onDelete: (item: ReplyItem) => void = () => {}

  build() {
    Row() {
      Image(this.item.member.avatar ? this.item.member.avatar : $r('app.media.icon'))
        .width(32)
        .height(32)
        .borderRadius(16)
        .margin({ right: 16 })
      Column() {
        Row() {
          Text(this.item.member.uname)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Regular)
            .maxLines(1)
          Image(ResUtils.getLevel(this.item.member.level_info.current_level))
            .height(12)
            .margin({ left: 6 })
        }.width('100%')
        .justifyContent(FlexAlign.Start)

        Row() {
          Text(StringUtil.timeStampToAgoDate(this.item.ctime))
            .fontSize(11)
            .fontColor($r('app.color.text_faint'))
            .height(20)
          if (this.item.reply_control != null && this.item.reply_control.location != null
            && this.item.reply_control.location.length > 0) {
            Text("IP属地:" + this.item.reply_control.location)
              .fontSize(11)
              .fontColor($r('app.color.text_faint'))
              .height(20)
              .margin({ left: 6 })
          }
        }.width('100%')
        .justifyContent(FlexAlign.Start)

        ReplyTextView({
          message: this.item.content.message,
          emote: this.item.content.emote,
          fontSize: 16,
          fontColor: $r('app.color.text_primary'),
          maxLines: this.item.content.max_line
        })
          .margin({ top: 12, bottom: 12 })

        Row() {
          Row() {
            Image($r('app.media.ic_reply_like'))
              .width(18)
              .height(18)
              .fillColor(this.item.action === 1 ? '#fb7299' : $r('app.color.text_tertiary'))
            Text(this.item.like + "")
              .fontSize(11)
              .fontColor(this.item.action === 1 ? '#fb7299' : $r('app.color.text_faint'))
              .margin({ left: 4 })
          }.alignItems(VerticalAlign.Center)
          .padding({ top: 4, bottom: 4, right: 8 })
          .onClick(() => {
            // 已赞 → 再点取消赞；未赞/已踩 → 点赞
            this.onAction(this.item, this.item.action === 1 ? 0 : 1);
          })

          Row() {
            Image($r('app.media.ic_reply_dislike'))
              .width(18)
              .height(18)
              .fillColor(this.item.action === 2 ? '#fb7299' : $r('app.color.text_tertiary'))
          }.alignItems(VerticalAlign.Center)
          .padding({ top: 4, bottom: 4, right: 8, left: 8 })
          .onClick(() => {
            // 已踩 → 再点取消踩(3)；未踩/已赞 → 点踩(2)
            this.onAction(this.item, this.item.action === 2 ? 3 : 2);
          })

          Row() {
            Text("分享")
              .fontSize(11)
              .fontColor($r('app.color.text_faint'))
          }.alignItems(VerticalAlign.Center)
          .padding({ top: 4, bottom: 4, right: 8, left: 8 })
          .onClick(() => {
            this.onShare(this.item);
          })

          Row() {
            Text("回复")
              .fontSize(11)
              .fontColor($r('app.color.text_faint'))
          }.alignItems(VerticalAlign.Center)
          .padding({ top: 4, bottom: 4, right: 8, left: 8 })
          .onClick(() => {
            this.onReply(this.item);
          })
        }.width('100%')
        .justifyContent(FlexAlign.Start)

        // 预览区：有子回复预览或有更多回复（rcount>0）时显示；replies 为 null 但有统计数时仍显示入口
        if ((this.item.replies != null || this.item.rcount > 0) && this.isShowReply) {
          Column() {
            ForEach(this.item.replies == null ? new Array<ReplyItem>() : this.item.replies,
              (item: ReplyItem) => {
                Column() {
                  ReplyTextView({
                    message: item.content.message,
                    emote: item.content.emote,
                    fontSize: 14,
                    fontColor: $r('app.color.text_primary'),
                    maxLines: 2,
                    prefix: item.member.uname + ': ',
                    prefixColor: '#1698CE'
                  })
                }.padding({ top: 12 })
              }, item => item.rpid + '')

            // x/v2/reply/main 每条评论最多返回 2 条子回复预览，按 rcount 判断是否有更多回复（原 replies.length>=3 永远不成立，导致详情页不可达）
            if (this.item.rcount > 0) {
              Text("共" + this.item.rcount + "条回复 >")
                .fontSize(14)
                .fontColor(Color.Blue)
                .width('100%')
                .textAlign(TextAlign.Start)
                .margin({ top: 12 })
                .onClick(() => {
                  this.onItemClick();
                })
            }
          }
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 12 })
          .margin({ top: 8 })
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(4)
        }

      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
    .margin({ top: 8, bottom: 8 })
    // 长按评论弹出操作菜单：复制；本人评论额外显示删除
    .bindContextMenu(this.ReplyMenuBuilder(), ResponseType.LongPress)
  }

  /** 是否本人评论（长按菜单"删除"项显示条件） */
  private isOwnReply(): boolean {
    return this.item != null && this.item.member != null
      && LoginHelper.isSelfMid(this.item.member.mid);
  }

  @Builder
  ReplyMenuBuilder() {
    Menu() {
      MenuItem({ content: '复制评论内容' })
        .onClick(() => {
          this.onShare(this.item);
        })
      if (this.isOwnReply()) {
        MenuItem({ content: '删除' })
          .onClick(() => {
            this.onDelete(this.item);
          })
      }
    }
  }
}
