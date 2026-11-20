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

import { PullToRefresh, PullToRefreshOpt } from '@ohos/pulltorefresh'
import { pasteboard } from '@kit.BasicServicesKit';
import { ApiManager } from './../../network/ApiManager';
import { BLog } from './../../utils/BLog';
import { ReplyCursor, ReplyItem } from './../../model/response/ReplyResponse';
import { BaseVideo } from './../../model/response/Response';
import { ReplyItemView } from './ReplyItem';
import { DataSourceManager } from './../../model/DataSourceManager';

@Component
export struct VideoReply {
  private scroller: Scroller = new Scroller();
  private vInfo: BaseVideo;
  private type: number = 1;
  private sort: number = 0;
  @State data: any[] = [];
  @State next: number = 0;
  @StorageLink('replyCount') replyCount: number = 0;
  @StorageLink('replyItem') replyItem: ReplyItem = null;
  private refreshOpt = new PullToRefreshOpt();
  @State isEnd: boolean = false;
  /** 评论输入内容 */
  @State inputText: string = '';
  /** 回复目标评论（null=发表顶级评论） */
  @State replyTarget: ReplyItem = null;
  /** 评论发送中 */
  @State isSending: boolean = false;

  build() {
    Column() {
      PullToRefresh({
        // 必传项，列表组件所绑定的数据
        data: $data,
        // 必传项，需绑定传入主体布局内的列表或宫格组件
        scroller: this.scroller,
        refreshOpt: this.refreshOpt,
        // 必传项，自定义主体布局，内部有列表或宫格组件
        // 注意：@Builder 按引用传给子组件 @BuilderParam 后，构建器内 this 指向子组件，
        // 直接引用会导致 this.onReplyAction 等实例方法 undefined 崩溃，
        // 必须用箭头函数包裹转发，使构建器内 this 保持为本组件
        customList: (onItemClick: (item: any, index: number) => void,
                     onListStatus: (isListStart: boolean, isListEnd: boolean) => void): void => {
          this.getListView(onItemClick, onListStatus);
        },
        onItemClick: (item: any, index: number) => {
          BLog.i('IjkPlayer onItemClick index: ' + index);
          this.replyItem = item;
        },
        // 可选项，下拉刷新回调
        onRefresh: () => {
          return new Promise<string>((resolve) => {
            this.next = 0;
            ApiManager.getInstance()
              .requestReply(this.vInfo.bvid, 0, this.type, this.sort)
              .then((cursor: ReplyCursor) => {
                // 判空：接口失败/风控时 cursor 为 null，直接结束刷新（否则 loading 永不消失）
                if (cursor != null) {
                  this.replyCount = cursor.all_count;
                  this.next = cursor.next;
                  this.refreshOpt.enableLoadMore = !cursor.is_end;
                  this.isEnd = cursor.is_end;
                }
                resolve('');
              })
              .catch((err: Error) => {
                BLog.e("VideoReply onRefresh err: " + err);
                resolve('');
              });
          });
        },
        // 可选项，上拉加载更多回调
        onLoadMore: () => {
          return new Promise<string>((resolve) => {
            if (this.isEnd) {
              resolve('');
              return;
            }
            // 不预递增页码：失败时游标不前进，重试仍拉本页
            ApiManager.getInstance()
              .requestReply(this.vInfo.bvid, this.next, this.type, this.sort)
              .then((cursor: ReplyCursor) => {
                BLog.i("requestReply: next=" + this.next + ", cursor=" + JSON.stringify(cursor));
                if (cursor != null) {
                  this.replyCount = cursor.all_count;
                  this.next = cursor.next;
                  this.refreshOpt.enableLoadMore = !cursor.is_end;
                  this.isEnd = cursor.is_end;
                }
                resolve('');
              })
              .catch((err: Error) => {
                BLog.e("VideoReply onLoadMore err: " + err);
                resolve('');
              });
          });
        },
        customLoad: null,
        customRefresh: null,
      })
      .layoutWeight(1)
      // 底部评论输入栏（发评论/回复评论）
      Row() {
        TextInput({
          text: this.inputText,
          placeholder: this.replyTarget != null
            ? '回复 @' + this.replyTarget.member.uname + ':'
            : '发条友善的评论吧'
        })
          .layoutWeight(1)
          .height(36)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.placeholder'))
          .placeholderFont({ size: 14 })
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(18)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.inputText = value;
          })

        Text(this.isSending ? '发送中' : '发送')
          .fontSize(14)
          .fontColor(this.canSend() ? '#fb7299' : $r('app.color.placeholder'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })
          .onClick(() => {
            this.onSendClick();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.surface'))
    }
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }

  /** 是否可发送：有内容、非发送中 */
  private canSend(): boolean {
    return !this.isSending && this.inputText.trim().length > 0;
  }

  private onSendClick(): void {
    if (!this.canSend()) {
      return;
    }
    let message: string = this.inputText.trim();
    this.isSending = true;
    this.resolveAid().then((aid: number) => {
      if (aid <= 0) {
        this.isSending = false;
        this.showToast('视频信息获取失败，请重试');
        return;
      }
      let root: number = this.replyTarget != null ? this.replyTarget.rpid : 0;
      let parent: number = root;
      ApiManager.getInstance()
        .requestReplyAdd(aid, root, parent, message)
        .then((ok: boolean) => {
          this.isSending = false;
          if (ok) {
            this.inputText = '';
            this.replyTarget = null;
            this.showToast('评论成功');
            this.refreshReplies();
          } else {
            this.showToast('评论失败，请重试');
          }
        })
        .catch((err: Error) => {
          BLog.e("VideoReply onSendClick err: " + err);
          this.isSending = false;
          this.showToast('评论失败，请重试');
        });
    }).catch(() => {
      this.isSending = false;
      this.showToast('视频信息获取失败，请重试');
    });
  }

  /**
   * 解析视频 aid：BaseVideo.aid 缺失时（如首页推荐入口）经 view 接口兜底获取并缓存回 vInfo
   */
  private async resolveAid(): Promise<number> {
    if (this.vInfo != null && this.vInfo.aid != null && this.vInfo.aid > 0) {
      return this.vInfo.aid;
    }
    let response = await ApiManager.getInstance().requestArchiveStat(this.vInfo.bvid);
    if (response != null && response.data != null && response.data.aid != null) {
      let aid: number = response.data.aid;
      if (this.vInfo != null) {
        this.vInfo.aid = aid;
      }
      return aid;
    }
    return 0;
  }

  /** 重新拉取第一页评论（发送成功后刷新列表） */
  private refreshReplies(): void {
    ApiManager.getInstance()
      .requestReply(this.vInfo.bvid, 0, this.type, this.sort)
      .then((cursor: ReplyCursor) => {
        if (cursor != null) {
          this.replyCount = cursor.all_count;
          this.next = cursor.next;
          this.refreshOpt.enableLoadMore = !cursor.is_end;
          this.isEnd = cursor.is_end;
        }
      })
      .catch(() => {
      });
  }

  /** 评论点赞/点踩（乐观更新，失败回滚） */
  private onReplyAction(item: ReplyItem, action: number): void {
    this.resolveAid().then((aid: number) => {
      if (aid <= 0) {
        this.showToast('视频信息获取失败，请重试');
        return;
      }
      let prevAction: number = item.action ?? 0;
      let prevLike: number = item.like;
      // 乐观更新本地状态（点赞数只在"是否点赞"状态翻转时增减：点赞+1，取消点赞/转点踩-1）
      if (action === 1 && prevAction !== 1) {
        item.like = prevLike + 1;
      } else if (action !== 1 && prevAction === 1) {
        item.like = prevLike - 1;
      }
      item.action = action;
      DataSourceManager.getReplySource(this.vInfo.bvid).notifyDataReload();
      ApiManager.getInstance()
        .requestReplyAction(aid, item.rpid, action)
        .then((ok: boolean) => {
          if (!ok) {
            this.rollbackReplyAction(item, prevAction, prevLike);
            this.showToast('操作失败，请重试');
          }
        })
        .catch(() => {
          this.rollbackReplyAction(item, prevAction, prevLike);
          this.showToast('操作失败，请重试');
        });
    }).catch(() => {
      this.showToast('视频信息获取失败，请重试');
    });
  }

  private rollbackReplyAction(item: ReplyItem, prevAction: number, prevLike: number): void {
    item.action = prevAction;
    item.like = prevLike;
    DataSourceManager.getReplySource(this.vInfo.bvid).notifyDataReload();
  }

  /** 分享评论：复制内容到剪贴板 */
  private onShareReply(item: ReplyItem): void {
    let systemPasteboard = pasteboard.getSystemPasteboard();
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, item.content.message);
    systemPasteboard.setData(pasteData);
    this.showToast('评论已复制');
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  @Builder
  private getListView(onItemClick: (item: any, index: number) => void,
                      onListStatus: (isListStart: boolean, isListEnd: boolean) => void) {
    List({ scroller: this.scroller }) {
      LazyForEach(DataSourceManager.getReplySource(AppStorage.Get('bvid')), (item: ReplyItem, index: number) => {
        ListItem() {
          ReplyItemView({
            item: item, isShowReply: true, onItemClick: () => {
              onItemClick(item, index);
            },
            onAction: (target: ReplyItem, action: number) => {
              this.onReplyAction(target, action);
            },
            onReply: (target: ReplyItem) => {
              this.replyTarget = target;
            },
            onShare: (target: ReplyItem) => {
              this.onShareReply(target);
            }
          })
        }
      // 键值含 action/like：点赞/点踩乐观更新后键值变化触发该项重建（键值不变则 LazyForEach 不刷新）
      }, item => item.rpid + '-' + item.action + '-' + item.like)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .divider({ strokeWidth: 1, color: $r('app.color.divider') })
    .edgeEffect(EdgeEffect.None)
    .onScrollIndex((start, end) => {
      onListStatus(start == 0,
        end == DataSourceManager.getReplySource(AppStorage.Get('bvid')).totalCount() - 1)
    })
  }
}
