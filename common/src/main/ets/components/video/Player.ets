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

import prompt from '@ohos.prompt';
import router from '@ohos.router';
import window from '@ohos.window';
import deviceInfo from '@ohos.deviceInfo';
import { IPlayer } from '../../player/IPlayer';
import { AvPlayer } from '../../player/AvPlayer';
import { IjkPlayer } from '../../player/IjkPlayer';
import { IPlayStatus } from '../../player/IPlayStatus';

import {
  DanmakuView,
  IDanmakus,
  DanmakuContext,
  Proxy,
  BaseDanmaku,
  BaseDanmakuParser,
  DANMAKU_STYLE_STROKEN,
  SpannedCacheStuffer,
  Callback,
  OnDanmakuClickListener,
  IDanmakuView,
  DanmakuTimer
} from '@ohos/danmakuflamemaster'
import display from '@ohos.display';
import { ProtoSource } from '../../model/proto/ProtoSource';
import { DanmakuParser } from '../../model/proto/DanmakuParser';
import { BLog } from '../../utils/BLog';
import { WindowManager } from '../../utils/WindowManager';
import { ApiManager } from '../../network/ApiManager';
import { PlayUrlResponse } from '../../model/response/PlayUrlResponse';
import { VideoPartsResponse } from '../../model/response/VideoPartsResponse';
import { ApiConstants } from '../../network/ApiConstants';
import { StringUtil } from '../../utils/StringUtil';

let PROGRESS_MAX_VALUE: number = 100;
let DANMAKU_TIME: number = 360000;
// ijkplayer 的 HAR 只提供 arm32/arm64 原生库，无 x86_64 版本；
// x86_64 模拟器上加载 libijkplayer_napi.so 会失败（native 模块为 undefined，
// 播放时 _getCurrentPosition 抛 TypeError 导致闪退），因此按 ABI 选择播放器：
// x86_64（模拟器）使用系统 AvPlayer，ARM 真机保持 IjkPlayer。
let playerType = deviceInfo.abiList.indexOf('x86_64') >= 0 ? "AvPlayer" : "IjkPlayer";

@Component
export struct PlayerView {
  private cid: number;
  private bvid: string;
  /** 续播起始秒数：prepared 后先 seek 再播放（0=从头播） */
  private startAt: number = 0;
  /** 本地视频文件绝对路径：非空时跳过 playurl/弹幕请求直接播本地（离线缓存） */
  private localPath: string = '';
  @StorageLink('isPortrait') isPortrait: boolean = true
  @Link @Watch('onPageStateUpdated') pageState: string;
  private player: IPlayer = (playerType == "IjkPlayer" ? new IjkPlayer() : new AvPlayer());
  @State progressValue: number = 0;
  @State currentTime: string = "00:00";
  @State totalTime: string = "00:00";
  @State loadingVisible: boolean = false;
  @State replayVisible: boolean = false;
  @State slideEnable: boolean = false;
  @State aspRatio: number = 16 / 9;
  @State mFirst: boolean = true;
  @State mState: IPlayStatus = IPlayStatus.INIT;
  @State mIsShowCtl: boolean = false;
  @StorageLink('playerFullScreen') @Watch('onFullScreenUpdated') mIsFullScreen: boolean = false;
  @StorageLink('playerLocked') mIsLocked: boolean = false;
  private mDisW: number = 0;
  private mDisH: number = 0;
  private mFsPortraitRatio: number = 9 / 16;
  private mFsLandscapeRatio: number = 16 / 9;
  @State mIsShowDanmaku: boolean = true;
  @State mDanmakuModel: DanmakuView.Model = new DanmakuView.Model();
  private mDanmakuContext: DanmakuContext;
  private mParser: BaseDanmakuParser;
  private mPlayUrl: string = "";
  private mPlayContext: object = null;
  private mCacheStufferAdapter: Proxy = new class extends Proxy {
    public prepareDrawing(danmaku: BaseDanmaku, fromWorkerThread: boolean): void {
    }

    public releaseResource(danmaku: BaseDanmaku): void {
      // TODO 重要:清理含有ImageSpan的text中的一些占用内存的资源 例如drawable
    }
  };
  @State @Watch('onDanmakuPnUpdated') danmakuPn: number = 1;
  /** 页面已销毁（返回/替换）：所有异步续体（playurl/prepare 等）一律失效，不再起播 */
  private mDestroyed: boolean = false;
  /** 页面当前是否可见（onPageShow/onPageHide）：隐藏时 prepared 不自动起播 */
  private mActive: boolean = true;
  /** 隐藏时正在播放：回到页面后恢复播放 */
  private mResumeOnShow: boolean = false;

  private createParser(source: ProtoSource): BaseDanmakuParser {
    let parser: BaseDanmakuParser = new DanmakuParser();
    parser.load(source);
    return parser;
  }

  onPageStateUpdated(propName: string): void {
    BLog.i('BiliPlayer bvid:' + this.bvid + ', pageState:' + this.pageState);
    switch (this.pageState) {
      case "onPageShow":
        this.mActive = true;
        this.player.setAutoPlay(true);
        if (!this.mFirst) {
          if (this.bvid == this.player.getPlayId()) {
            // 本页播放器实例仍在：恢复播放（仅隐藏时在播的才恢复，原先暂停的保持暂停）
            if (this.mResumeOnShow) {
              this.mResumeOnShow = false;
              BLog.i('BiliPlayer resume play on show');
              this.player.play();
            } else if (this.mState == IPlayStatus.PREPARED) {
              // 隐藏期间加载完成但被 autoPlay=false 禁止起播（从未渲染画面）：
              // 回到页面直接播放，修复回到首个视频黑屏问题
              BLog.i('BiliPlayer start prepared video on show');
              this.player.play();
            }
          } else {
            // 播放器已被其他视频页复用/释放（真机 IjkPlayer 单例场景）：整链路重新拉起
            BLog.i('BiliPlayer initPlay on show');
            this.mResumeOnShow = false;
            this.player.setPlayId(this.bvid);
            this.player.initPlay(this.mPlayContext).then(_ => {
              if (!this.mDestroyed) {
                this.initPlay(this.mPlayUrl);
              }
            });
          }
        }
        break;
      case "onPageHide":
        // 页面被覆盖（进入下一个视频页/其他页面）或退后台：停止自动起播并暂停当前播放，
        // 防止上一个视频在后台继续出声
        this.mActive = false;
        this.player.setAutoPlay(false);
        if (this.mState == IPlayStatus.PLAY) {
          this.mResumeOnShow = true;
          this.player.pause();
        }
        break;
      case "aboutToDisappear":
        this.releasePlayer();
        break;
      default:
        break;
    }
  }

  /**
   * 页面销毁兜底清理：即使 pageState @Watch 未触发也必须停播释放（幂等）
   */
  aboutToDisappear() {
    this.releasePlayer();
  }

  private releasePlayer(): void {
    if (this.mDestroyed) {
      return;
    }
    this.mDestroyed = true;
    this.mActive = false;
    BLog.i('BiliPlayer releasePlayer bvid:' + this.bvid);
    this.player.setAutoPlay(false);
    this.player.release();
    if (this.mIsFullScreen) {
      // 退出全屏（含窗口旋转、系统栏恢复、解锁），由 onFullScreenUpdated 统一处理
      this.mIsFullScreen = false;
    } else if (!this.isPortrait) {
      WindowManager.changeWindowDirection(window.Orientation.PORTRAIT)
      this.isPortrait = true
      WindowManager.setFullScreen(this.isPortrait);
    }
  }

  onDanmakuPnUpdated(propName: string): void {
    this.getDanmaku(false);
  }

  aboutToAppear() {
    let dis = display.getDefaultDisplaySync();
    if (dis != null) {
      this.mDisW = dis.width;
      this.mDisH = dis.height;
      // 竖屏全屏（窗口不旋转）与横屏全屏（窗口旋转后）的屏幕宽高比
      this.mFsPortraitRatio = this.mDisW / this.mDisH;
      this.mFsLandscapeRatio = this.mDisH / this.mDisW;
    }
    this.player.setPlayId(this.bvid);
    if (this.cid > 0) {
      this.getDanmaku(true);
    }
  }

  onFullScreenUpdated(propName: string): void {
    BLog.i('PlayerView onFullScreenUpdated: ' + this.mIsFullScreen
      + ', aspRatio: ' + this.aspRatio + ', isPortrait: ' + this.isPortrait);
    if (this.mIsFullScreen) {
      // 进入全屏：横屏视频旋转窗口铺满；竖屏视频保持竖屏铺满（B站样式）
      if (this.aspRatio >= 1) {
        if (this.isPortrait) {
          WindowManager.changeWindowDirection(window.Orientation.LANDSCAPE);
          this.isPortrait = false;
        }
      } else {
        if (!this.isPortrait) {
          WindowManager.changeWindowDirection(window.Orientation.PORTRAIT);
          this.isPortrait = true;
        }
        WindowManager.setFullScreen(false);
      }
    } else {
      // 退出全屏：恢复竖屏窗口与系统栏，并解除锁定
      this.mIsLocked = false;
      if (!this.isPortrait) {
        WindowManager.changeWindowDirection(window.Orientation.PORTRAIT);
        this.isPortrait = true;
      } else {
        WindowManager.setFullScreen(true);
      }
    }
  }

  // 全屏模式下视频宽度：视频宽高比窄于容器时按容器高度做信箱式留黑（不裁剪、不拉伸）
  private fsXcWidth(): Length {
    if (!this.mIsFullScreen) {
      return '100%';
    }
    let containerW: number = this.isPortrait ? this.mDisW : this.mDisH;
    let containerH: number = this.isPortrait ? this.mDisH : this.mDisW;
    if (containerW <= 0 || containerH <= 0) {
      return '100%';
    }
    let containerRatio: number = containerW / containerH;
    if (this.aspRatio >= containerRatio) {
      return '100%';
    }
    return (this.aspRatio / containerRatio) * 100 + '%';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: this.player.id(),
        type: 'surface',
        libraryname: this.player.libraryName(),
        controller: this.player.controller()
      })
        .onLoad((context) => {
          this.mPlayContext = context;
          this.player.initPlay(this.mPlayContext).then(_ => {
            if (this.mDestroyed) {
              // 页面已销毁：加载完成后不再起播（防"幽灵"播放）
              return;
            }
            if (this.localPath != '') {
              // 本地播放：跳过 playurl/弹幕网络请求，直接播本地文件
              this.mPlayUrl = this.localPath;
              this.initPlay(this.localPath);
            } else if (this.cid == 0) {
              this.getPageList(this.bvid);
            } else {
              this.getPlayUrl(this.bvid, this.cid);
            }
          });
        })
        .width(this.mIsFullScreen ? this.fsXcWidth() : '100%')
        .aspectRatio(this.aspRatio)

      if (!this.mIsShowCtl) {
        Column() {
          Blank()
          Progress({ value: this.progressValue, total: PROGRESS_MAX_VALUE,
            type: ProgressType.Linear })
            .color(Color.Red)
            .backgroundColor(Color.Transparent)
            .width('100%')
            .height(2)
        }.height('100%')
      }

      Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center,
        justifyContent: FlexAlign.Center }) {
        DanmakuView({ model: $mDanmakuModel })
      }.width('100%')
      .height('100%')

      PlayerControlView({
        player: this.player,
        mDanmakuModel: this.mDanmakuModel,
        loadingVisible: $loadingVisible,
        replayVisible: $replayVisible,
        progressValue: $progressValue,
        currentTime: $currentTime,
        totalTime: $totalTime,
        slideEnable: $slideEnable,
        mState: $mState,
        mIsShowCtl: $mIsShowCtl,
        danmakuPn: $danmakuPn,
        mIsShowDanmaku: $mIsShowDanmaku
      })

      if (this.replayVisible){
        Column() {
          Image($r('app.media.icon_replay'))
            .objectFit(ImageFit.Auto)
            .width(48)
            .height(48)
            .border({ width: 0 })
            .borderStyle(BorderStyle.Dashed)
            .onClick(() => {
              this.showLoadIng();
              this.player.play();
            })
        }.width('100%').height('100%')
        .backgroundColor('#33000000')
        .justifyContent(FlexAlign.Center)
      }

      if (this.loadingVisible) {
        Column() {
          Image($r('app.media.icon_load'))
            .objectFit(ImageFit.Auto)
            .width(48)
            .height(48)
            .border({ width: 0 })
            .borderStyle(BorderStyle.Dashed)
        }.width('100%').height('100%')
        .backgroundColor('#33000000')
        .justifyContent(FlexAlign.Center)
      }

      if (this.mIsFullScreen && !this.mIsLocked) {
        Row() {
          Image($r('app.media.ic_player_lock'))
            .width(24)
            .height(24)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center)
        .position({ x: 12, y: '50%' })
        .translate({ y: '-50%' })
        .onClick(() => {
          this.mIsLocked = true;
          this.mIsShowCtl = false;
        })
      }

      if (this.mIsFullScreen && this.mIsLocked) {
        // 锁定态：透明拦截层吞掉所有触摸，仅保留左侧解锁按钮
        Column() {
          Row() {
            Image($r('app.media.ic_player_unlock'))
              .width(24)
              .height(24)
          }
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#66000000')
          .justifyContent(FlexAlign.Center)
          .position({ x: 12, y: '50%' })
          .translate({ y: '-50%' })
          .onClick(() => {
            this.mIsLocked = false;
            this.mIsShowCtl = true;
          })
        }
        .width('100%')
        .height('100%')
        .onClick(() => {
        })
      }

    }.width('100%')
    .aspectRatio(this.mIsFullScreen ? (this.isPortrait ? this.mFsPortraitRatio : this.mFsLandscapeRatio) : this.aspRatio)
    .backgroundColor(Color.Black)
  }

  private getPageList(bvid: string) {
    ApiManager.getInstance().requestPageList(bvid).then((resp: VideoPartsResponse) => {
      if (this.mDestroyed) {
        return;
      }
      this.cid = resp.data[0].cid;
      this.getDanmaku(true);
      this.getPlayUrl(this.bvid, this.cid);
    });
  }

  private getDanmaku(isInit: boolean) {
    BLog.i("getDanmaku index: " + this.danmakuPn + ", isInit: " + isInit);
    ApiManager.getInstance().requestDmList(this.cid, 1, this.danmakuPn).then((source) => {
      if (this.mDestroyed) {
        return;
      }
      if (isInit) {
        this.initDanmaku(source);
      } else {
        this.updateDanmaku(source);
      }
    });
  }

  private getPlayUrl(bvid: string, cid: number) {
    ApiManager.getInstance().requestPlayUrl(bvid, cid).then((resp: PlayUrlResponse) => {
      if (this.mDestroyed) {
        return;
      }
      this.mPlayUrl = resp.data.durl[0].url.replace(/\\u0026/g, '&')
      BLog.i("requestPlayUrl Response Data url=" + this.mPlayUrl);
      this.initPlay(this.mPlayUrl);
    });
  }

  private showLoadIng() {
    this.loadingVisible = true;
    this.replayVisible = false;
  }

  private hideLoadIng() {
    this.loadingVisible = false;
    this.replayVisible = false;
  }

  private showRePlay() {
    this.loadingVisible = false;
    this.replayVisible = true;
  }

  private initPlay(url: string) {
    let thisClass = this;
    this.player.setOnTimeUpdateCallback({
      onTimeUpdate(current: number, total: number) {
        if (total > 0) {
          thisClass.slideEnable = true;
          let curPercent = current / total;
          let pos = curPercent * 100;
          thisClass.progressValue = pos;

          if (current != 0 && thisClass.danmakuPn * DANMAKU_TIME < current) {
            thisClass.danmakuPn = Math.floor(current / DANMAKU_TIME) + 1;
          }
        }
      }
    });
    this.player.setOnTimeStrUpdateCallback({
      onTimeStrUpdate(current: string, total: string) {
        thisClass.currentTime = current;
        thisClass.totalTime = total;
      }
    });
    this.player.setOnSizeChangeCallback({
      OnSizeChange(width: number, height: number) {
        thisClass.aspRatio = width / height;
      }
    });
    this.player.setOnStateChangeCallback({
      OnStateChange(status: IPlayStatus) {
        if (thisClass.mDestroyed) {
          // 页面已销毁：迟到的状态回调一律忽略（播放器内部已由 release 兜底）
          return;
        }
        thisClass.mState = status;
        if (status == IPlayStatus.INIT) {
          thisClass.mFirst = true;
          thisClass.showLoadIng();
        } else if (status == IPlayStatus.PREPARED) {
          thisClass.mFirst = false;
          thisClass.hideLoadIng();
          if (thisClass.startAt > 0) {
            // 续播：seek 到上次观看进度，seek 完成后播放器自动恢复播放
            BLog.i('BiliPlayer resume seekTo: ' + thisClass.startAt + 's');
            thisClass.player.seekTo(thisClass.startAt * 1000);
            thisClass.startAt = 0;
          }
        } else if (status == IPlayStatus.PLAY) {
          thisClass.hideLoadIng();
          thisClass.mDanmakuModel.resume();
        } else if (status == IPlayStatus.PAUSE) {
          thisClass.hideLoadIng();
          thisClass.mDanmakuModel.pause();
        } else if (status == IPlayStatus.ERROR) {
          thisClass.hideLoadIng();
          prompt.showToast({
            message: "亲，视频播放异常，系统开小差咯"
          });
        } else if (status == IPlayStatus.DONE) {
          thisClass.showRePlay();
          thisClass.slideEnable = false;
        }
      }
    });
    this.showLoadIng();
    this.setDataSource(url);
  }

  private setDataSource(url: string) {
    let headers = new Map([
      ["User-Agent", ApiConstants.userAgent],
      ["Connection", "keep-alive"],
      ["Referer", ApiConstants.biliBase]
    ]);
    this.player.setDataSource(url, headers);
  }

  private initDanmaku(source: ProtoSource) {
    let maxLinesPair: Map<number, number> = new Map();
    maxLinesPair.set(BaseDanmaku.TYPE_SCROLL_RL, 20); // 滚动弹幕最大显示5行
    // 设置是否禁止重叠
    let overlappingEnablePair: Map<number, boolean> = new Map();
    overlappingEnablePair.set(BaseDanmaku.TYPE_SCROLL_RL, true);
    overlappingEnablePair.set(BaseDanmaku.TYPE_FIX_TOP, true);
    this.mDanmakuContext = DanmakuContext.create();
    this.mDanmakuContext.setDanmakuStyle(DANMAKU_STYLE_STROKEN, 3)
      .setDuplicateMergingEnabled(false)
      .setScrollSpeedFactor(1.2)
      .setScaleTextSize(1.2)
      .setCacheStuffer(new SpannedCacheStuffer(), this.mCacheStufferAdapter) // 图文混排使用SpannedCacheStuffer
      .setMaximumLines(maxLinesPair)
      .preventOverlapping(overlappingEnablePair)
      .setDanmakuMargin(40);
    let that = this
    if (this.mDanmakuModel != null) {
      this.mParser = this.createParser(source);
      this.mDanmakuModel.setCallback(new class implements Callback {
        public updateTimer(timer: DanmakuTimer): void {
        }

        public drawingFinished(): void {

        }

        public danmakuShown(danmaku: BaseDanmaku): void {
        }

        public prepared(): void {
          if (that.mState == IPlayStatus.PLAY) {
            that.mDanmakuModel.start();
          }
        }
      });

      this.mDanmakuModel.setOnDanmakuClickListener(new class implements OnDanmakuClickListener {
        onDanmakuClick(danmakus: IDanmakus): boolean {
          BLog.i('DFM onDanmakuClick: danmakus size:' + danmakus.size())
          let latest: BaseDanmaku = danmakus.last()
          if (null != latest) {
            BLog.i('DFM onDanmakuClick: text of latest danmaku:' + latest.text)
            return true
          }
          return false
        };

        onDanmakuLongClick(danmakus: IDanmakus): boolean {
          return false
        };

        onViewClick(view: IDanmakuView): boolean {
          return false
        };
      })
      this.mDanmakuModel.prepare(this.mParser, this.mDanmakuContext);
      this.mDanmakuModel.showFPS(false);
    }
  }

  private updateDanmaku(source: ProtoSource) {
    if (this.mDanmakuModel != null) {
      this.mParser = this.createParser(source);
      this.mDanmakuModel.prepare(this.mParser, this.mDanmakuContext);
    }
  }
}

@Component
struct PlayerControlView {
  private player: IPlayer;
  private mDanmakuModel: DanmakuView.Model;
  @StorageLink('isPortrait') isPortrait: boolean = true;
  @StorageLink('playerFullScreen') mIsFullScreen: boolean = false;
  @Link loadingVisible: boolean;
  @Link replayVisible: boolean;
  @Link progressValue: number;
  @Link currentTime: string;
  @Link totalTime: string;
  @Link slideEnable: boolean;
  @Link mState: IPlayStatus;
  @Link mIsShowCtl: boolean;
  @Link danmakuPn: number;
  @Link mIsShowDanmaku: boolean;
  @State mShowSeekPreview: boolean = false;
  @State mSeekPreviewText: string = "";
  private mPanStartPos: number = 0;
  private mPanTargetPos: number = 0;

  build() {
    Column() {
      if (this.mIsShowCtl) {
        Row() {
          Image($r('app.media.ic_player_back_bold'))
            .width(24)
            .height(24)
            .onClick(_ => {
              if (this.mIsFullScreen) {
                this.mIsFullScreen = false;
              } else if (this.isPortrait) {
                router.back();
              } else {
                WindowManager.changeWindowDirection(window.Orientation.PORTRAIT)
                this.isPortrait = true
              }
            })

          Blank()

          Image($r('app.media.ic_player_setting_bold'))
            .width(24)
            .height(24)
            .onClick(_ => {
            })
        }.padding(8)
        .width('100%')
        .linearGradient({
          colors: [["#aa000000", 0.0], ["#00000000", 1.0]]
        })
      }
      Blank()
      if (this.mIsShowCtl) {
        Row() {
          Image(this.mState == IPlayStatus.PLAY ? $r('app.media.ic_player_pause') :
          $r('app.media.ic_player_play'))
            .width(28)
            .height(28)
            .enabled(this.mState != IPlayStatus.INIT)
            .onClick(_ => {
              if (this.mState == IPlayStatus.PLAY) {
                this.player.pause();
              } else {
                this.player.play();
              }
            })
          Slider({
            value: this.progressValue,
            min: 0,
            max: PROGRESS_MAX_VALUE,
            step: 1,
            style: SliderStyle.OutSet
          })
            .width(this.isPortrait ? '40%' : '70%')
            .margin({ left: 12 })
            .blockColor(Color.White)
            .trackColor(Color.Gray)
            .trackThickness(2)
            .selectedColor(Color.Red)
            .showSteps(true)
            .showTips(true)
            .enabled(this.slideEnable)
            .onChange((value: number, mode: SliderChangeMode) => {
              this.player.pause();
              this.showLoadIng();
              let seekValue = value * (this.player.getDuration() / 100);
              this.player.seekTo(seekValue);
              if ((this.danmakuPn-1) * DANMAKU_TIME <= seekValue && this.danmakuPn * DANMAKU_TIME > seekValue ) {
                this.mDanmakuModel.seekTo(seekValue - (this.danmakuPn-1) * DANMAKU_TIME);
              } else {
                this.danmakuPn = Math.floor(seekValue / DANMAKU_TIME) + 1;
              }
            })
          Text(this.currentTime + "/" + this.totalTime)
            .fontSize(12)
            .margin({ left: 8, right: 8 })
            .fontColor(Color.White)

          Blank()

          Image(this.mIsShowDanmaku? $r("app.media.ic_danmaku_switch_on") : $r("app.media.ic_danmaku_switch_off"))
          .width(24)
          .height(24)
          .onClick(() => {
            this.mIsShowDanmaku = !this.mIsShowDanmaku;
            this.mDanmakuModel.setVisibility(this.mIsShowDanmaku);
          });

          if (!this.mIsFullScreen) {
            Image($r('app.media.ic_player_toggle_zoom'))
              .width(24)
              .height(24)
              .onClick(() => {
                this.mIsFullScreen = true;
              })
          } else {
            Image($r('app.media.ic_player_fullscreen_switch_halfscreen'))
              .width(24)
              .height(24)
              .onClick(() => {
                this.mIsFullScreen = false;
              })
          }
        }.padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .width('100%')
        .linearGradient({
          colors: [["#00000000", 0.0], ["#aa000000", 1.0]]
        })
      }
      if (this.mShowSeekPreview) {
        Text(this.mSeekPreviewText)
          .fontSize(16)
          .fontColor(Color.White)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#99000000')
          .borderRadius(8)
          .position({ x: '50%', y: '50%' })
          .translate({ x: '-50%', y: '-50%' })
      }
    }.width('100%')
    .height('100%')
    .onClick(() => {
      this.mIsShowCtl = !this.mIsShowCtl
    })
    .gesture(GestureGroup(GestureMode.Exclusive,
      TapGesture({ count: 2 })
        .onAction(() => {
          this.togglePlayByTap();
        }),
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 8 })
        .onActionStart((event: GestureEvent) => {
          this.onPanStart(event);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.onPanUpdate(event);
        })
        .onActionEnd((event: GestureEvent) => {
          this.onPanEnd(event);
        })
    ))
  }

  // 双击切换播放/暂停
  private togglePlayByTap(): void {
    if (this.mState == IPlayStatus.PLAY) {
      this.player.pause();
    } else if (this.mState == IPlayStatus.PAUSE) {
      this.player.play();
    }
  }

  // 水平拖动慢速快进/快退（0.5 倍速），松手后执行 seek
  private onPanStart(event: GestureEvent): void {
    let duration: number = this.player.getDuration();
    if (duration <= 0) {
      return;
    }
    this.mPanStartPos = this.progressValue / 100 * duration;
    this.mPanTargetPos = this.mPanStartPos;
  }

  private onPanUpdate(event: GestureEvent): void {
    let duration: number = this.player.getDuration();
    if (duration <= 0) {
      return;
    }
    let dis = display.getDefaultDisplaySync();
    let ctlW: number = this.isPortrait ? dis.width : dis.height;
    if (ctlW <= 0) {
      return;
    }
    let deltaMs: number = event.offsetX / ctlW * duration * 0.5;
    let target: number = this.mPanStartPos + deltaMs;
    if (target < 0) {
      target = 0;
    }
    if (target > duration) {
      target = duration;
    }
    this.mPanTargetPos = target;
    this.mSeekPreviewText = StringUtil.stringForTime(target) + " / " + StringUtil.stringForTime(duration);
    this.mShowSeekPreview = true;
  }

  private onPanEnd(event: GestureEvent): void {
    this.mShowSeekPreview = false;
    if (this.player.getDuration() <= 0) {
      return;
    }
    let seekValue: number = this.mPanTargetPos;
    this.player.pause();
    this.showLoadIng();
    this.player.seekTo(seekValue);
    if ((this.danmakuPn-1) * DANMAKU_TIME <= seekValue && this.danmakuPn * DANMAKU_TIME > seekValue ) {
      this.mDanmakuModel.seekTo(seekValue - (this.danmakuPn-1) * DANMAKU_TIME);
    } else {
      this.danmakuPn = Math.floor(seekValue / DANMAKU_TIME) + 1;
    }
  }

  private showLoadIng() {
    this.loadingVisible = true;
    this.replayVisible = false;
  }
}