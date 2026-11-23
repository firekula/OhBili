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
  @StorageLink('isPortrait') @Watch('onPortraitUpdated') isPortrait: boolean = true;
  @State currentIndex: number = 0;
  @StorageLink('replyCount') @Watch('onCountUpdated') replyCount: number = 0;
  @State tabTitle: ResourceStr[] = [$r('app.string.video_overview'), $r('app.string.video_reply', 0)];
  @StorageLink('replyItem') @Watch('onReplyUpdated') replyItem: ReplyItem = null;
  @State pageState: string = "";
  @State fansCount: number = 0;
  @State archiveCount: number = 0;
  @State isFollowing: Boolean = false;
  @State isLiked: boolean = false;
  @State isCoined: boolean = false;

  aboutToAppear() {
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
        this.replyCount = cursor.all_count;
      });
    this.loadLikeCoinState();
  }

  /**
   * 加载当前用户对该视频的点赞/投币状态（未登录跳过）；
   * aid 缺失时经 archive/stat 兜底解析
   */
  private loadLikeCoinState(): void {
    let loggedIn: boolean = AppStorage.get<boolean>('isOhBiliLoggedIn') ?? false;
    if (!loggedIn) {
      return;
    }
    this.resolveAidForState().then((aid: number) => {
      if (aid <= 0) {
        return;
      }
      ApiManager.getInstance().requestHasLike(aid).then((liked: number) => {
        if (liked == 1) {
          this.isLiked = true;
        }
      }).catch(() => {
      });
      ApiManager.getInstance().requestCoinCount(aid).then((count: number) => {
        if (count > 0) {
          this.isCoined = true;
        }
      }).catch(() => {
      });
    }).catch(() => {
    });
  }

  /**
   * 解析视频 aid：BaseVideo.aid 缺失时经 archive/stat 接口兜底获取
   */
  private async resolveAidForState(): Promise<number> {
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

  onPageShow() {
    this.pageState = "onPageShow";
    AppStorage.SetOrCreate('bvid', this.vInfo.bvid);
  }

  onPageHide() {
    this.pageState = "onPageHide";
  }

  onBackPress() {
    if (this.replyItem != null) {
      this.replyItem = null;
      return true;
    }
  }

  aboutToDisappear() {
    this.pageState = "aboutToDisappear";
    DataSourceManager.deleteRelatedMapSource(this.vInfo.bvid);
    DataSourceManager.deleteReplyMapSource(this.vInfo.bvid);
  }

  onPortraitUpdated(propName: string): void {
    BLog.i('IjkPlayer onPortraitUpdated isPortrait:' + this.isPortrait);
    WindowManager.setFullScreen(this.isPortrait);
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
  }

  build() {
    Column() {
      PlayerView({ cid: this.vInfo.cid, bvid: this.vInfo.bvid, pageState: $pageState })
      if (this.isPortrait) {
        if (this.replyItem != null) {
          Column() {
            ReplyDetailView({ vInfo: this.vInfo })
          }.layoutWeight(1)
        } else {
          Tabs({ index: this.currentIndex }) {
            TabContent() {
              VideoOverview({ vInfo: $vInfo, isFollowing: $isFollowing, fansCount: $fansCount, archiveCount: $archiveCount, isLiked: $isLiked, isCoined: $isCoined })
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
  }
}
