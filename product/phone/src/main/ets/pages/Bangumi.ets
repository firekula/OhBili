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
  BangumiEpisode,
  BangumiSeason,
  BangumiSeasonBrief,
  BangumiSeasonResponse,
  BangumiSection,
  BLog,
  NavHelper,
  PlayerView,
  StringUtil,
  ThemeUtil,
  WindowManager
} from '@ohos/common';

/** 页面加载状态 */
enum LoadState {
  Loading,
  Error,
  Content
}

/** 番剧页路由参数（router.getParams 单次转型后按类型访问） */
interface BangumiRouteParams {
  seasonId?: number
  epId?: number
}

/**
 * 番剧详情页：PlayerView 番剧链路播放（epId 取流）+ 详情区
 * （评分/简介/追番/选集/花絮折叠/多季切换）。
 * 路由参数 { seasonId: number, epId: number }（epId 0=默认第一集）。
 */
@Entry
@Component
struct BangumiPage {
  private routeParams: BangumiRouteParams = router.getParams() as BangumiRouteParams;
  private seasonId: number = this.routeParams.seasonId ?? 0;
  private epId: number = this.routeParams.epId ?? 0;
  @State state: LoadState = LoadState.Loading;
  @State mSeason: BangumiSeason | null = null;
  @State mCurrentEpId: number = 0;
  @State mCurrentCid: number = 0;
  @State mAid: number = 0;
  @State mIsFollow: boolean = false;
  @State mFollowLoading: boolean = false;
  /** 简介展开 */
  @State mEvaluateExpanded: boolean = false;
  /** 花絮/ PV 折叠区展开 */
  @State mSectionsExpanded: boolean = false;
  @State pageState: string = "";
  @StorageLink('isPortrait') isPortrait: boolean = true;
  @StorageLink('playerFullScreen') playerFullScreen: boolean = false;
  @StorageLink('playerLocked') playerLocked: boolean = false;
  /** 沉浸式布局下状态栏/导航条避让高度（vp） */
  @State statusBarPad: number = 0;
  @State navBarPad: number = 0;
  /** 沉浸式布局是否已应用（防 onPageShow 重复触发） */
  private immersiveApplied: boolean = false;
  /** 延迟应用沉浸式的定时器 id */
  private immersiveTimer: number = -1;

  aboutToAppear() {
    if (this.seasonId == null || this.seasonId <= 0) {
      this.state = LoadState.Error;
      return;
    }
    if (!this.playerFullScreen) {
      WindowManager.lockPortrait();
    }
    // 叠栈计数：仅最后一个番剧页销毁时才退出沉浸式
    let cnt: number = AppStorage.get<number>('bangumiPageCount') ?? 0;
    AppStorage.setOrCreate('bangumiPageCount', cnt + 1);
    this.pageState = "aboutToAppear";
    this.loadSeason(true);
  }

  onPageShow() {
    this.pageState = "onPageShow";
    this.applyImmersiveLayout();
  }

  onPageHide() {
    this.pageState = "onPageHide";
  }

  onBackPress() {
    // 锁定态屏蔽返回键
    if (this.playerLocked) {
      return true;
    }
    // 全屏态先退全屏（与 Video 页一致）
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
    return false;
  }

  aboutToDisappear() {
    this.pageState = "aboutToDisappear";
    if (this.immersiveTimer >= 0) {
      clearTimeout(this.immersiveTimer);
      this.immersiveTimer = -1;
    }
    // 叠栈计数：仅最后一个番剧页销毁时恢复系统栏与退出沉浸式布局
    let cnt: number = AppStorage.get<number>('bangumiPageCount') ?? 1;
    AppStorage.setOrCreate('bangumiPageCount', cnt - 1);
    if (cnt - 1 <= 0) {
      WindowManager.setFullScreen(true);
      ThemeUtil.applyThemeBars();
      if (!this.isPortrait) {
        WindowManager.rotateWindowPortrait();
        this.isPortrait = true;
      }
    }
  }

  /**
   * 延迟应用沉浸式布局（等待路由转场动画结束），与 Video 页同款
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
      WindowManager.setLayoutFullScreen(true, '#00000000', '#ffffff', '#00000000', '#182431');
      this.statusBarPad = px2vp(WindowManager.getStatusBarAvoidHeight());
      this.navBarPad = px2vp(WindowManager.getNavBarAvoidHeight());
    }, 450);
  }

  /**
   * 加载番剧详情
   * @param initial 首次进入（显示 Loading 态）；切季重载保持播放器不断流
   */
  private loadSeason(initial: boolean): void {
    if (initial) {
      this.state = LoadState.Loading;
    }
    ApiManager.getInstance().requestBangumiSeason(this.seasonId, 0)
      .then((resp: ApiResponse<BangumiSeasonResponse>) => {
        if (resp.code == -1 || resp.result == null || resp.result.code != 0
          || resp.result.result == null) {
          if (initial) {
            this.state = LoadState.Error;
          }
          return;
        }
        let season: BangumiSeason = resp.result.result;
        this.mSeason = season;
        this.mIsFollow = season.user_status != null && season.user_status.follow == 1;
        this.selectEpisode(initial ? this.epId : 0);
        this.state = LoadState.Content;
      }).catch(() => {
        if (initial) {
          this.state = LoadState.Error;
        }
      });
  }

  /**
   * 选集：epId>0 在正片中查找，否则取第一集
   */
  private selectEpisode(epId: number): void {
    let season: BangumiSeason | null = this.mSeason;
    if (season == null || season.episodes == null || season.episodes.length == 0) {
      return;
    }
    let target: BangumiEpisode | null = null;
    if (epId > 0) {
      for (let i: number = 0; i < season.episodes.length; i++) {
        let ep: BangumiEpisode = season.episodes[i];
        if (ep.ep_id == epId) {
          target = ep;
          break;
        }
      }
    }
    if (target == null) {
      target = season.episodes[0];
    }
    this.applyEpisode(target);
  }

  /**
   * 应用选中集：更新当前 epId/cid/aid（epId 变化经 @Prop @Watch 驱动 PlayerView 切集）
   */
  private applyEpisode(ep: BangumiEpisode): void {
    this.mCurrentEpId = ep.ep_id ?? 0;
    this.mCurrentCid = ep.cid ?? 0;
    this.mAid = ep.aid ?? 0;
  }

  /**
   * 追番/取消追番（未登录跳登录页）
   */
  private toggleFollow(): void {
    let loggedIn: boolean = AppStorage.get<boolean>('isOhBiliLoggedIn') ?? false;
    if (!loggedIn) {
      NavHelper.goLogin();
      return;
    }
    if (this.mFollowLoading) {
      return;
    }
    let season: BangumiSeason | null = this.mSeason;
    let sid: number = season != null && season.season_id != null && season.season_id > 0
      ? season.season_id : this.seasonId;
    this.mFollowLoading = true;
    let promise: Promise<number> = this.mIsFollow
      ? ApiManager.getInstance().unfollowBangumi(sid)
      : ApiManager.getInstance().followBangumi(sid);
    promise.then((code: number) => {
      this.mFollowLoading = false;
      if (code == 0) {
        this.mIsFollow = !this.mIsFollow;
        this.showToast(this.mIsFollow ? '追番成功' : '已取消追番');
      } else if (code == -101) {
        this.showToast('登录已失效，请重新登录');
      } else {
        this.showToast('操作失败，请重试');
      }
    }).catch(() => {
      this.mFollowLoading = false;
      this.showToast('操作失败，请重试');
    });
  }

  /**
   * 切季：重拉详情并回到新季第一集
   */
  private switchSeason(target: BangumiSeasonBrief): void {
    let sid: number = target.season_id ?? 0;
    if (sid <= 0 || sid == this.seasonId) {
      return;
    }
    this.seasonId = sid;
    this.mSectionsExpanded = false;
    this.loadSeason(false);
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  // ---------- 布局 ----------

  @Builder
  episodeChip(ep: BangumiEpisode) {
    Column() {
      Text(ep.index ?? '')
        .fontSize(12)
        .fontColor(this.mCurrentEpId == ep.ep_id ? Color.White : $r('app.color.text_primary'))
        .maxLines(1)
      if (ep.badge != null && ep.badge.length > 0) {
        Text(ep.badge)
          .fontSize(8)
          .fontColor('#FF6699')
          .maxLines(1)
          .margin({ top: 1 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width(72)
    .height(34)
    .borderRadius(4)
    .backgroundColor(this.mCurrentEpId == ep.ep_id ? '#fb7299' : $r('app.color.page_bg'))
    .margin({ right: 8, bottom: 8 })
    .onClick(() => {
      if (this.mCurrentEpId != ep.ep_id) {
        this.applyEpisode(ep);
      }
    })
  }

  @Builder
  sectionBlock(section: BangumiSection) {
    Column() {
      Row() {
        Text((section.title ?? '') + ' · ' + (section.episodes == null ? 0 : section.episodes.length))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.mSectionsExpanded ? '收起' : '展开')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })
      .onClick(() => {
        this.mSectionsExpanded = !this.mSectionsExpanded;
      })

      if (this.mSectionsExpanded) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(section.episodes ?? [], (ep: BangumiEpisode) => {
            this.episodeChip(ep)
          }, (ep: BangumiEpisode) => 's' + ep.ep_id + '_' + ep.badge)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  detailPane() {
    Scroll() {
      Column() {
        // 标题 + 评分
        Row() {
          Text(this.mSeason == null || this.mSeason.title == null ? '' : this.mSeason.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.mSeason != null && this.mSeason.rating != null
            && this.mSeason.rating.score != null && this.mSeason.rating.score > 0) {
            Text(this.mSeason.rating.score.toFixed(1))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF9F0A')
              .margin({ left: 12 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12 })

        // 追番数
        if (this.mSeason != null && this.mSeason.stat != null && this.mSeason.stat.follow != null
          && this.mSeason.stat.follow > 0) {
          Text(StringUtil.generateCN(this.mSeason.stat.follow) + '人追番')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 16, top: 4 })
        }

        // 追番按钮
        Button(this.mIsFollow ? '已追番' : '追番')
          .width(112)
          .height(32)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.mIsFollow ? $r('app.color.page_bg') : '#fb7299')
          .fontColor(this.mIsFollow ? $r('app.color.text_secondary') : Color.White)
          .margin({ left: 16, top: 10 })
          .onClick(() => {
            this.toggleFollow();
          })

        // 简介（可展开）
        if (this.mSeason != null && this.mSeason.evaluate != null
          && this.mSeason.evaluate.length > 0) {
          Text(this.mSeason.evaluate)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(this.mEvaluateExpanded ? 20 : 2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
            .width('100%')
            .padding({ left: 16, right: 16, top: 10 })
            .onClick(() => {
              this.mEvaluateExpanded = !this.mEvaluateExpanded;
            })
        }

        // 多季切换
        if (this.mSeason != null && this.mSeason.seasons != null
          && this.mSeason.seasons.length > 1) {
          Text('系列')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .padding({ left: 16, top: 14, bottom: 8 })
          Scroll() {
            Row() {
              ForEach(this.mSeason.seasons, (brief: BangumiSeasonBrief) => {
                Text(brief.season_title ?? '')
                  .fontSize(12)
                  .fontColor(this.seasonId == brief.season_id ? Color.White : $r('app.color.text_primary'))
                  .backgroundColor(this.seasonId == brief.season_id ? '#1698CE' : $r('app.color.page_bg'))
                  .borderRadius(14)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.switchSeason(brief);
                  })
              }, (brief: BangumiSeasonBrief) => 'ss' + brief.season_id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .padding({ left: 16, right: 16 })
        }

        // 选集
        Text('选集')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ left: 16, top: 14, bottom: 8 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.mSeason == null || this.mSeason.episodes == null ? [] : this.mSeason.episodes,
            (ep: BangumiEpisode) => {
              this.episodeChip(ep)
            }, (ep: BangumiEpisode) => 'e' + ep.ep_id + '_' + ep.badge)
        }
        .width('100%')
        .padding({ left: 16, right: 8 })

        // 花絮 / PV
        if (this.mSeason != null && this.mSeason.sections != null
          && this.mSeason.sections.length > 0) {
          ForEach(this.mSeason.sections, (section: BangumiSection) => {
            this.sectionBlock(section)
          }, (section: BangumiSection) => 'sec' + section.section_id)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 24 })
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    Column() {
      if (this.state == LoadState.Content) {
        PlayerView({
          cid: this.mCurrentCid, bvid: '', pageState: $pageState, startAt: 0,
          epId: this.mCurrentEpId, bangumiCid: this.mCurrentCid, bangumiAid: this.mAid
        })
        if (this.isPortrait && !this.playerFullScreen) {
          this.detailPane()
        }
      } else if (this.state == LoadState.Loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
          Text("加载中...")
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text("番剧加载失败").fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium)
          Text("内容不存在或网络异常，请重试").fontSize(14)
            .fontColor($r('app.color.text_secondary')).margin({ top: 12 })
          Button("重试").width(240).margin({ top: 16 }).onClick(() => {
            this.loadSeason(true);
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .padding({
      top: this.playerFullScreen ? 0 : this.statusBarPad,
      bottom: this.playerFullScreen ? 0 : this.navBarPad
    })
  }
}
