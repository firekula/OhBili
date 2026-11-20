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
import { VideoReply } from '@ohos/common';
import { VideoOverview } from '@ohos/common';
import { WindowManager } from '@ohos/common';
import { ThemeUtil } from '@ohos/common';
import { BaseVideo, EmptyBaseVideo, EmptyStat, Stat } from '@ohos/common';
import { StringUtil } from '@ohos/common';
import { ReplyCursor, ReplyItem } from '@ohos/common';
import { ReplyDetailView } from '@ohos/common';
import { DataSourceManager } from '@ohos/common';
import { ApiManager } from '@ohos/common';
import { BLog } from '@ohos/common';
import { ArchiveStatResponse } from '@ohos/common';
import { PlayerView } from '@ohos/common';

@Entry
@Component
struct VideoPlayer {
  @State vInfo: BaseVideo = router.getParams()['vInfo']
  /** 续播起始秒数（历史记录跳入时传入，0=从头播） */
  private startAt: number = router.getParams()['startAt'] ?? 0;
  /** 本地视频文件绝对路径（离线缓存跳入时传入，空=在线播放） */
  private localPath: string = router.getParams()['localPath'] ?? '';
  @StorageLink('isPortrait') isPortrait: boolean = true;
  @State currentIndex: number = 0;
  @StorageLink('replyCount') @Watch('onCountUpdated') replyCount: number = 0;
  @State tabTitle: ResourceStr[] = [$r('app.string.video_overview'), $r('app.string.video_reply', 0)];
  @StorageLink('replyItem') @Watch('onReplyUpdated') replyItem: ReplyItem = null;
  @StorageLink('playerFullScreen') playerFullScreen: boolean = false;
  @StorageLink('playerLocked') playerLocked: boolean = false;
  @State pageState: string = "";
  @State fansCount: number = 0;
  @State archiveCount: number = 0;
  @State isFollowing: Boolean = false;
  /** 沉浸式布局下状态栏/导航条避让高度（vp），非全屏时以 padding 避让 */
  @State statusBarPad: number = 0;
  @State navBarPad: number = 0;
  /** 沉浸式布局是否已应用（每页仅一次，防 onPageShow 重复触发） */
  private immersiveApplied: boolean = false;
  /** 延迟应用沉浸式的定时器 id（页面销毁时清理，防止快速返回后误触发） */
  private immersiveTimer: number = -1;

  aboutToAppear() {
    // 全屏态推入的视频页（关联视频在横屏全屏下顶入）保持横屏窗口不回竖；
    // 非全屏进入则锁定竖屏，防止传感器旋转
    if (!this.playerFullScreen) {
      WindowManager.lockPortrait();
    }
    // 视频页沉浸式改为延迟应用（onPageShow + 转场动画时长后）：
    // aboutToAppear 立即改窗口布局会让底部首页在转场开始前重排（列表跳回顶部）
    // 叠栈计数：仅最后一个视频页销毁时才退出沉浸式，避免上层视频页返回时破坏下层沉浸状态
    let cnt: number = AppStorage.get<number>('videoPageCount') ?? 0;
    AppStorage.setOrCreate('videoPageCount', cnt + 1);
    this.replyItem = null;
    if (this.vInfo.stat.reply != undefined) {
      this.replyCount = this.vInfo.stat.reply;
    } else {
      ApiManager.getInstance().requestArchiveStat(this.vInfo.bvid)
        .then((response: ArchiveStatResponse) => {
          if (response.data != null) {
            BLog.i("requestArchiveStat stat: " + JSON.stringify(response.data));
            this.vInfo.stat = response.data;
            this.replyCount = response.data.reply;
          }
        });
    }
    if (this.vInfo.desc == undefined) {
      ApiManager.getInstance().requestArchiveDesc(this.vInfo.bvid)
        .then((desc: string) => {
          this.vInfo.desc = desc;
        });
    }
    this.pageState = "aboutToAppear";
    DataSourceManager.setReplyMapSource(this.vInfo.bvid);
    DataSourceManager.setRelatedMapSource(this.vInfo.bvid);
    DataSourceManager.getReplySource(this.vInfo.bvid).setData([]);
    DataSourceManager.getRelatedSource(this.vInfo.bvid).setData([
    EmptyBaseVideo("VideoInfoView"),
    EmptyBaseVideo("VideoTopBar")]);
    ApiManager.getInstance().requestRelated(this.vInfo.bvid);
    ApiManager.getInstance().requestUserCardInfo(this.vInfo.owner.mid).then(response => {
      this.fansCount = response.data.follower;
      this.archiveCount = response.data.archive_count;
      this.isFollowing = response.data.following;
    })
    ApiManager.getInstance()
      .requestReply(this.vInfo.bvid, 0, 1, 0)
      .then((cursor: ReplyCursor) => {
        // 评论接口失败/被风控时 cursor 为 null，需判空避免未处理异常
        if (cursor != null) {
          this.replyCount = cursor.all_count;
        }
      })
      .catch((err: Error) => {
        BLog.e("requestReply initial failed: " + err);
      });
  }

  /**
   * 延迟应用沉浸式布局：等待路由转场动画（约 400ms）结束后再改窗口布局，
   * 避免转场期间窗口尺寸变化导致下层页面（首页列表）可见跳动；
   * padding 初始为 0（普通窗口布局下内容本就从状态栏下方开始），
   * 沉浸式生效后再设为避让高度，视频画面在屏幕上的位置保持不变。
   */
  private applyImmersiveLayout() {
    if (this.immersiveApplied || this.immersiveTimer >= 0) {
      return;
    }
    this.immersiveTimer = setTimeout(() => {
      this.immersiveTimer = -1;
      if (this.pageState === "aboutToDisappear") {
        return;
      }
      this.immersiveApplied = true;
      // 视频页沉浸式：窗口全屏布局 + 透明系统栏，系统栏显示/隐藏不再引起窗口尺寸跳变
      WindowManager.setLayoutFullScreen(true, '#00000000', '#ffffff', '#00000000', '#182431');
      this.statusBarPad = px2vp(WindowManager.getStatusBarAvoidHeight());
      this.navBarPad = px2vp(WindowManager.getNavBarAvoidHeight());
    }, 450);
  }

  onPageShow() {
    this.pageState = "onPageShow";
    AppStorage.SetOrCreate('bvid', this.vInfo.bvid);
    // 沉浸式延迟到转场动画结束后应用（aboutToAppear 过早，首页会先重排）
    this.applyImmersiveLayout();
    // 多视频页叠栈时 replyCount 为全局共享键，回到本页时以本页数据恢复，
    // 避免 A 页评论数显示成 B 页的（同时驱动 VideoReply 重建绑定本页弹幕/评论源）
    if (this.vInfo.stat.reply != undefined) {
      this.replyCount = this.vInfo.stat.reply;
    }
  }

  onPageHide() {
    this.pageState = "onPageHide";
  }

  onBackPress() {
    // 锁定态屏蔽返回键
    if (this.playerLocked) {
      return true;
    }
    // 全屏态先退全屏（与 PlayerView.exitFullScreen 逻辑一致）：
    // 横屏全屏旋转窗口回竖屏（布局由 windowSizeChange 跟随恢复）；
    // 竖屏视频全屏（B站样式，窗口未旋转）动画收起，结束后恢复系统栏
    if (this.playerFullScreen) {
      if (!this.isPortrait) {
        WindowManager.rotateWindowPortrait();
      } else {
        this.getUIContext().animateTo({
          duration: 300,
          curve: Curve.EaseOut,
          onFinish: () => {
            WindowManager.setFullScreen(true);
          }
        }, () => {
          this.playerFullScreen = false;
        });
      }
      return true;
    }
    if (this.replyItem != null) {
      this.replyItem = null;
      return true;
    }
  }

  aboutToDisappear() {
    this.pageState = "aboutToDisappear";
    // 清理未触发的沉浸式延迟定时器（快速进出页面场景）
    if (this.immersiveTimer >= 0) {
      clearTimeout(this.immersiveTimer);
      this.immersiveTimer = -1;
    }
    // 叠栈计数：仅最后一个视频页销毁时恢复系统栏与退出沉浸式布局
    let cnt: number = AppStorage.get<number>('videoPageCount') ?? 1;
    AppStorage.setOrCreate('videoPageCount', cnt - 1);
    if (cnt - 1 <= 0) {
      // 离开视频页兜底恢复系统栏与退出沉浸式布局（全屏状态下页面直接销毁的场景）
      WindowManager.setFullScreen(true);
      ThemeUtil.applyThemeBars();
      if (!this.isPortrait) {
        // 窗口仍横屏（绕过 onBackPress 的销毁路径）：旋转回竖屏并同步方向状态
        WindowManager.rotateWindowPortrait();
        this.isPortrait = true;
      }
    }
    DataSourceManager.deleteRelatedMapSource(this.vInfo.bvid);
    DataSourceManager.deleteReplyMapSource(this.vInfo.bvid);
  }

  onCountUpdated(propName: string): void {
    BLog.i('IjkPlayer onCountUpdated replyCount:' + this.replyCount);
    this.tabTitle[1] = $r('app.string.video_reply', StringUtil.generateCN(this.replyCount));
  }

  onReplyUpdated(propName: string): void {
    BLog.i("ReplyDetailView onReplyUpdated")
    if (this.replyItem == null) {
      DataSourceManager.getReplyDetailSource().setData([])
    }
  }

  @Builder TabBuilder(targetIndex: number) {
    Column() {
      Text(this.tabTitle[targetIndex])
        .fontSize(14)
        .fontColor(this.currentIndex === targetIndex ? '#1698CE' : $r('app.color.tab_inactive'))
        .border({ width: { bottom: this.currentIndex === targetIndex ? 2 : 0 }, color: '#1698CE' })
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .border({ width: { bottom: 0.5 }, color: $r('app.color.border') })
    // 点击即时切换：不等 Tabs 滑动动画结束（onChange 在动画后才回调，导致内容延迟切换）
    .onClick(() => {
      if (this.currentIndex !== targetIndex && this.replyItem == null) {
        this.currentIndex = targetIndex;
      }
    })
  }

  build() {
    Column() {
      PlayerView({ cid: this.vInfo.cid, bvid: this.vInfo.bvid, pageState: $pageState,
        startAt: this.startAt, localPath: this.localPath })
      if (this.isPortrait && !this.playerFullScreen) {
        if (this.replyItem != null) {
          Column() {
            ReplyDetailView({ vInfo: this.vInfo })
          }.layoutWeight(1)
        } else {
          Tabs({ index: this.currentIndex }) {
            TabContent() {
              VideoOverview({ vInfo: $vInfo, isFollowing: $isFollowing, fansCount: $fansCount, archiveCount: $archiveCount })
            }
            .tabBar(this.TabBuilder(0))

            TabContent() {
              VideoReply({ vInfo: this.vInfo })
            }
            .tabBar(this.TabBuilder(1))
          }.barHeight(40).onChange((index) => {
            if (this.replyItem == null) {
              BLog.i("onChange: " + index);
              this.currentIndex = index
            }
          }).layoutWeight(1)
        }
      }
    }
    .width('100%').height('100%')
    // 沉浸式布局：非全屏时内容避让状态栏/导航条，全屏时铺满窗口
    .padding({
      top: this.playerFullScreen ? 0 : this.statusBarPad,
      bottom: this.playerFullScreen ? 0 : this.navBarPad
    })
  }
}
