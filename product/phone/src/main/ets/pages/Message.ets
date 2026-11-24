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
import {
  ApiManager,
  ApiResponse,
  BaseVideo,
  EmptyBaseVideo,
  MessageEntry,
  MessageFeedDataSource,
  MsgFeedAtResponse,
  MsgFeedLikeResponse,
  MsgFeedReplyResponse,
  NavHelper,
  StringUtil,
  SysNoticeResponse
} from '@ohos/common';

/** 子页签索引 */
let TAB_REPLY: number = 0;
let TAB_AT: number = 1;
let TAB_LIKE: number = 2;
let TAB_SYS: number = 3;

/**
 * 消息中心页：回复/@我/收到的赞/系统通知 四类消息流（游标分页）；
 * 未登录显示占位；进入页面刷新未读总数徽标（AppStorage ohBiliMsgUnreadTotal）。
 */
@Entry
@Component
struct MessagePage {
  @StorageLink('isOhBiliLoggedIn') mLoggedIn: boolean = false;
  @StorageLink('ohBiliMsgUnreadTotal') mUnreadTotal: number = 0;
  @State mCurrentTab: number = TAB_REPLY;
  @State mReplyLoaded: boolean = false;
  @State mAtLoaded: boolean = false;
  @State mLikeLoaded: boolean = false;
  @State mSysLoaded: boolean = false;
  // 各 Tab 首屏错误态文案（空串表示无错误）
  @State mReplyError: string = '';
  @State mAtError: string = '';
  @State mLikeError: string = '';
  @State mSysError: string = '';
  private mReplySource: MessageFeedDataSource = new MessageFeedDataSource();
  private mAtSource: MessageFeedDataSource = new MessageFeedDataSource();
  private mLikeSource: MessageFeedDataSource = new MessageFeedDataSource();
  private mSysSource: MessageFeedDataSource = new MessageFeedDataSource();
  // 游标分页状态（不驱动 UI）
  private mReplyId: number = 0;
  private mReplyEnd: boolean = false;
  private mReplyLoading: boolean = false;
  private mAtId: number = 0;
  private mAtEnd: boolean = false;
  private mAtLoading: boolean = false;
  private mLikeId: number = 0;
  private mLikeEnd: boolean = false;
  private mLikeLoading: boolean = false;
  private mSysEnd: boolean = false;
  private mSysLoading: boolean = false;

  aboutToAppear() {
    if (this.mLoggedIn) {
      this.loadReply(true);
    }
  }

  onPageShow() {
    this.refreshUnread();
  }

  /**
   * 刷新未读总数（徽标与 MoreServerView 共享 AppStorage 键）
   */
  private refreshUnread(): void {
    if (!this.mLoggedIn) {
      this.mUnreadTotal = 0;
      return;
    }
    ApiManager.getInstance().requestMsgFeedUnread().then((data) => {
      if (data == null) {
        return;
      }
      let total: number = (data.reply ?? 0) + (data.at ?? 0)
        + (data.like ?? 0) + (data.sys ?? 0);
      AppStorage.setOrCreate('ohBiliMsgUnreadTotal', total);
    }).catch(() => {
    });
  }

  private switchTab(index: number): void {
    this.mCurrentTab = index;
    if (!this.mLoggedIn) {
      return;
    }
    if (index == TAB_REPLY && !this.mReplyLoaded) {
      this.loadReply(true);
    } else if (index == TAB_AT && !this.mAtLoaded) {
      this.loadAt(true);
    } else if (index == TAB_LIKE && !this.mLikeLoaded) {
      this.loadLike(true);
    } else if (index == TAB_SYS && !this.mSysLoaded) {
      this.loadSys(true);
    }
  }

  // ---------- 数据加载（游标分页） ----------

  private loadReply(first: boolean): void {
    if (this.mReplyLoading) {
      return;
    }
    this.mReplyLoading = true;
    ApiManager.getInstance().requestMsgFeedReply(first ? 0 : this.mReplyId, '')
      .then((resp: ApiResponse<MsgFeedReplyResponse>) => {
        this.mReplyLoading = false;
        this.mReplyLoaded = true;
        if (resp.code == -1 || resp.result == null) {
          this.mReplyError = '网络异常，请检查网络后重试';
          return;
        }
        if (resp.result.code != 0) {
          this.mReplyError = '加载失败（' + resp.result.code + ' ' + (resp.result.message ?? '') + '）';
          return;
        }
        if (resp.result.data == null) {
          return;
        }
        this.mReplyError = '';
        let data = resp.result.data;
        let items = data.items ?? [];
        let entries: MessageEntry[] = [];
        for (let i: number = 0; i < items.length; i++) {
          let item = items[i];
          let entry: MessageEntry = {
            key: 'r' + (item.id ?? 0) + '_' + i,
            avatar: item.user == null ? '' : (item.user.avatar ?? ''),
            title: item.user == null ? '' : (item.user.nickname ?? ''),
            time: 0,
            summary: item.item == null ? '' : (item.item.reply ?? ''),
            sourceTitle: item.item == null ? '' : (item.item.source_content ?? ''),
            bvid: this.extractBvid(item.item == null ? '' : (item.item.target_id ?? ''))
          };
          entries.push(entry);
        }
        if (first) {
          this.mReplySource.setData(entries);
        } else {
          this.mReplySource.appendData(entries);
        }
        if (data.cursor != null) {
          this.mReplyId = data.cursor.id ?? 0;
          this.mReplyEnd = data.cursor.is_end ?? true;
        } else {
          this.mReplyEnd = true;
        }
      }).catch(() => {
        this.mReplyLoading = false;
        this.mReplyLoaded = true;
      });
  }

  private loadAt(first: boolean): void {
    if (this.mAtLoading) {
      return;
    }
    this.mAtLoading = true;
    ApiManager.getInstance().requestMsgFeedAt(first ? 0 : this.mAtId, '')
      .then((resp: ApiResponse<MsgFeedAtResponse>) => {
        this.mAtLoading = false;
        this.mAtLoaded = true;
        if (resp.code == -1 || resp.result == null) {
          this.mAtError = '网络异常，请检查网络后重试';
          return;
        }
        if (resp.result.code != 0) {
          this.mAtError = '加载失败（' + resp.result.code + ' ' + (resp.result.message ?? '') + '）';
          return;
        }
        if (resp.result.data == null) {
          return;
        }
        this.mAtError = '';
        let data = resp.result.data;
        let items = data.items ?? [];
        let entries: MessageEntry[] = [];
        for (let i: number = 0; i < items.length; i++) {
          let item = items[i];
          let entry: MessageEntry = {
            key: 'a' + (item.id ?? 0) + '_' + i,
            avatar: item.user == null ? '' : (item.user.avatar ?? ''),
            title: item.user == null ? '' : (item.user.nickname ?? ''),
            time: item.item == null ? 0 : (item.item.at_time ?? 0),
            summary: item.item == null ? '' : (item.item.content ?? ''),
            sourceTitle: '',
            bvid: this.extractBvid(item.item == null ? '' : (item.item.target_id ?? ''))
          };
          entries.push(entry);
        }
        if (first) {
          this.mAtSource.setData(entries);
        } else {
          this.mAtSource.appendData(entries);
        }
        if (data.cursor != null) {
          this.mAtId = data.cursor.id ?? 0;
          this.mAtEnd = data.cursor.is_end ?? true;
        } else {
          this.mAtEnd = true;
        }
      }).catch(() => {
        this.mAtLoading = false;
        this.mAtLoaded = true;
      });
  }

  private loadLike(first: boolean): void {
    if (this.mLikeLoading) {
      return;
    }
    this.mLikeLoading = true;
    ApiManager.getInstance().requestMsgFeedLike(first ? 0 : this.mLikeId, '')
      .then((resp: ApiResponse<MsgFeedLikeResponse>) => {
        this.mLikeLoading = false;
        this.mLikeLoaded = true;
        if (resp.code == -1 || resp.result == null) {
          this.mLikeError = '网络异常，请检查网络后重试';
          return;
        }
        if (resp.result.code != 0) {
          this.mLikeError = '加载失败（' + resp.result.code + ' ' + (resp.result.message ?? '') + '）';
          return;
        }
        if (resp.result.data == null) {
          return;
        }
        this.mLikeError = '';
        let data = resp.result.data;
        let items = data.items ?? [];
        let entries: MessageEntry[] = [];
        for (let i: number = 0; i < items.length; i++) {
          let item = items[i];
          let entry: MessageEntry = {
            key: 'l' + (item.id ?? 0) + '_' + i,
            avatar: item.user == null ? '' : (item.user.avatar ?? ''),
            title: item.user == null ? '' : (item.user.nickname ?? ''),
            time: item.item == null ? 0 : (item.item.like_time ?? 0),
            summary: '',
            sourceTitle: item.item == null ? '' : (item.item.title ?? ''),
            bvid: this.extractBvid(item.item == null ? '' : (item.item.target_id ?? ''))
          };
          entries.push(entry);
        }
        if (first) {
          this.mLikeSource.setData(entries);
        } else {
          this.mLikeSource.appendData(entries);
        }
        if (data.cursor != null) {
          this.mLikeId = data.cursor.id ?? 0;
          this.mLikeEnd = data.cursor.is_end ?? true;
        } else {
          this.mLikeEnd = true;
        }
      }).catch(() => {
        this.mLikeLoading = false;
        this.mLikeLoaded = true;
      });
  }

  private loadSys(first: boolean): void {
    if (this.mSysLoading) {
      return;
    }
    this.mSysLoading = true;
    ApiManager.getInstance().requestSysNotices('')
      .then((resp: ApiResponse<SysNoticeResponse>) => {
        this.mSysLoading = false;
        this.mSysLoaded = true;
        if (resp.code == -1 || resp.result == null) {
          this.mSysError = '网络异常，请检查网络后重试';
          return;
        }
        if (resp.result.code != 0) {
          this.mSysError = '加载失败（' + resp.result.code + ' ' + (resp.result.message ?? '') + '）';
          return;
        }
        if (resp.result.data == null) {
          return;
        }
        this.mSysError = '';
        let items = resp.result.data.notify_list ?? [];
        let entries: MessageEntry[] = [];
        for (let i: number = 0; i < items.length; i++) {
          let item = items[i];
          let entry: MessageEntry = {
            key: 's' + (item.id ?? '') + '_' + i,
            avatar: item.cover ?? '',
            title: item.title ?? '',
            time: item.time ?? 0,
            summary: item.content ?? '',
            sourceTitle: '',
            bvid: ''
          };
          entries.push(entry);
        }
        if (first) {
          this.mSysSource.setData(entries);
        } else {
          this.mSysSource.appendData(entries);
        }
        // 系统通知单页拉取，翻页游标暂不支持（单页 20 条）
        this.mSysEnd = true;
      }).catch(() => {
        this.mSysLoading = false;
        this.mSysLoaded = true;
      });
  }

  /**
   * 目标 id 解析：仅 bvid（BV 开头）可跳视频页，aid 等解析不出则空串
   */
  private extractBvid(targetId: string): string {
    if (targetId != null && targetId.length > 2 && targetId.startsWith('BV')) {
      return targetId;
    }
    return '';
  }

  private loadMoreCurrent(): void {
    if (this.mCurrentTab == TAB_REPLY && !this.mReplyEnd) {
      this.loadReply(false);
    } else if (this.mCurrentTab == TAB_AT && !this.mAtEnd) {
      this.loadAt(false);
    } else if (this.mCurrentTab == TAB_LIKE && !this.mLikeEnd) {
      this.loadLike(false);
    }
  }

  /**
   * 条目点击：可解析出 bvid 则跳视频页
   */
  private onEntryClick(entry: MessageEntry): void {
    if (entry.bvid.length == 0) {
      return;
    }
    let video: BaseVideo = EmptyBaseVideo(entry.bvid);
    router.pushUrl({ url: 'pages/Video', params: { vInfo: video } });
  }

  // ---------- 布局 ----------

  @Builder
  tabBarText(title: string, index: number) {
    Text(title)
      .fontSize(15)
      .fontWeight(this.mCurrentTab === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.mCurrentTab === index ? '#1698CE' : $r('app.color.text_secondary'))
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .border({ width: { bottom: this.mCurrentTab === index ? 2 : 0 }, color: '#1698CE' })
      .onClick(() => {
        this.switchTab(index);
      })
  }

  @Builder
  messageList(source: MessageFeedDataSource) {
    if (source.totalCount() == 0) {
      Column() {
        if (this.isCurrentLoaded()) {
          if (this.currentError().length > 0) {
            Text(this.currentError())
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .padding({ left: 32, right: 32 })
            Button('重试')
              .margin({ top: 16 })
              .fontSize(14)
              .height(36)
              .padding({ left: 24, right: 24 })
              .onClick(() => {
                this.retryCurrent();
              })
          } else {
            Text('暂无消息')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
        } else {
          LoadingProgress().width(36).height(36)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        LazyForEach(source, (entry: MessageEntry) => {
          ListItem() {
            Row() {
              Image(entry.avatar.length > 0 ? entry.avatar : $r('app.media.ic_comment_avatar_default'))
                .width(40)
                .height(40)
                .borderRadius(20)
                .objectFit(ImageFit.Cover)
              Column() {
                Row() {
                  Text(entry.title)
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  if (entry.time > 0) {
                    Text(StringUtil.timeStampToAgoDate(entry.time))
                      .fontSize(11)
                      .fontColor($r('app.color.text_faint'))
                      .margin({ left: 8 })
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                if (entry.summary.length > 0) {
                  Text(entry.summary)
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                if (entry.sourceTitle.length > 0) {
                  Text(entry.sourceTitle)
                    .fontSize(12)
                    .fontColor($r('app.color.text_faint'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 10 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .onClick(() => {
              this.onEntryClick(entry);
            })
          }
        }, (entry: MessageEntry) => entry.key)
      }
      .width('100%')
      .height('100%')
      .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 66, endMargin: 16 })
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.loadMoreCurrent();
      })
    }
  }

  private isCurrentLoaded(): boolean {
    if (this.mCurrentTab == TAB_REPLY) {
      return this.mReplyLoaded;
    }
    if (this.mCurrentTab == TAB_AT) {
      return this.mAtLoaded;
    }
    if (this.mCurrentTab == TAB_LIKE) {
      return this.mLikeLoaded;
    }
    return this.mSysLoaded;
  }

  /**
   * 当前 Tab 错误文案（首屏失败时非空，驱动错误态 UI）
   */
  private currentError(): string {
    if (this.mCurrentTab == TAB_REPLY) {
      return this.mReplyError;
    }
    if (this.mCurrentTab == TAB_AT) {
      return this.mAtError;
    }
    if (this.mCurrentTab == TAB_LIKE) {
      return this.mLikeError;
    }
    return this.mSysError;
  }

  /**
   * 错误态重试：清空错误后重新拉取当前 Tab 首屏
   */
  private retryCurrent(): void {
    if (this.mCurrentTab == TAB_REPLY) {
      this.mReplyError = '';
      this.loadReply(true);
    } else if (this.mCurrentTab == TAB_AT) {
      this.mAtError = '';
      this.loadAt(true);
    } else if (this.mCurrentTab == TAB_LIKE) {
      this.mLikeError = '';
      this.loadLike(true);
    } else {
      this.mSysError = '';
      this.loadSys(true);
    }
  }

  build() {
    Column() {
      if (!this.mLoggedIn) {
        Column() {
          Image($r('app.media.ic_comment_avatar_default'))
            .width(64)
            .height(64)
            .borderRadius(32)
          Text('登录后查看消息')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 16 })
          Button('去登录')
            .margin({ top: 16 })
            .onClick(() => {
              NavHelper.goLogin();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Row() {
          this.tabBarText('回复', TAB_REPLY)
          this.tabBarText('@我', TAB_AT)
          this.tabBarText('收到的赞', TAB_LIKE)
          this.tabBarText('系统通知', TAB_SYS)
        }
        .width('100%')
        .padding({ left: 8 })
        .border({ width: { bottom: 0.5 }, color: $r('app.color.border') })

        if (this.mCurrentTab == TAB_REPLY) {
          this.messageList(this.mReplySource)
        } else if (this.mCurrentTab == TAB_AT) {
          this.messageList(this.mAtSource)
        } else if (this.mCurrentTab == TAB_LIKE) {
          this.messageList(this.mLikeSource)
        } else {
          this.messageList(this.mSysSource)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }
}
