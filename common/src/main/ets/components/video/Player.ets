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
  DanmakuTimer,
  DanmakuUtils
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
import { NavHelper } from '../../utils/NavHelper';

let PROGRESS_MAX_VALUE: number = 100;
let DANMAKU_TIME: number = 360000;
// 统一使用系统 AvPlayer：
// 1. ijkplayer 的 HAR 只提供 arm32/arm64 原生库，无 x86_64 版本（模拟器本就不可用）；
// 2. 其 2022 年构建的原生渲染层（libijksdl）在 HarmonyOS 7.0 新 GPU 驱动上
//    创建 EGL 窗口表面失败（hilog: EGL_BAD_MATCH → egl.eglCreateWindowSurface error），
//    真机表现为有声音无画面（全部视频黑屏），HAR 无源码不可修补；
// 3. API 12+ 的 AvPlayer 已支持 MediaSource 携带自定义请求头（B站 CDN 需 UA/Referer），
//    不再需要 ijkplayer 的自带头能力。
let playerType = "AvPlayer";

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
  @StorageLink('playerFullScreen') mIsFullScreen: boolean = false;
  @StorageLink('playerLocked') mIsLocked: boolean = false;
  /** 窗口尺寸（vp）：窗口旋转后由 windowSizeChange 更新，全屏布局跟随窗口实际尺寸 */
  @State mWinW: number = 0;
  @State mWinH: number = 0;
  private mWindow: window.Window | null = null;
  /** 待进入全屏意图：旋转窗口前置位，由 windowSizeChange 消费，
   * 用于区分"旋转到竖屏是进入竖屏视频全屏"还是"退出横屏全屏"（平板横屏等场景） */
  private mPendingFsEnter: boolean = false;
  private mSizeCb: (size: window.Size) => void = (size: window.Size) => {
    this.onWindowSizeChange(size.width, size.height);
  };
  @State mIsShowDanmaku: boolean = true;
  /** 清晰度档位表（qn 与描述下标对应，来自 playurl 响应） */
  @State mAcceptQuality: number[] = [];
  @State mAcceptDesc: string[] = [];
  /** 当前清晰度 qn */
  @State mCurrentQn: number = 0;
  /** 大会员（高清档位解锁） */
  @State mIsVip: boolean = false;
  /** 播放倍速（AVPlayer 支持 0.75/1.0/1.25/1.75/2.0） */
  @State mSpeed: number = 1.0;
  /** 循环播放 */
  @State mLoopPlay: boolean = false;
  /** 弹幕设置（与设置页共享持久化键，经回调即时应用到弹幕上下文） */
  @StorageLink('danmuFontSize') danmuFontSize: string = '1.0X';
  @StorageLink('danmuOpacity') danmuOpacity: string = '100%';
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
  /** 弹幕发送输入条 */
  @State mDanmakuInputVisible: boolean = false;
  @State mDanmakuInputText: string = '';
  @State mDanmakuSending: boolean = false;
  /** 视频 aid（发弹幕接口需要，懒解析缓存） */
  private mAid: number = 0;

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
    if (this.mWindow != null) {
      this.mWindow.off('windowSizeChange', this.mSizeCb);
      this.mWindow = null;
    }
    this.player.setAutoPlay(false);
    this.player.release();
    if (this.mIsFullScreen) {
      // 状态清理（页面销毁兜底），窗口/系统栏恢复由页面侧处理
      this.mIsFullScreen = false;
    }
  }

  onDanmakuPnUpdated(propName: string): void {
    this.getDanmaku(false);
  }

  aboutToAppear() {
    // 初始化窗口尺寸并监听变化：窗口旋转（横竖屏切换）后布局在 windowSizeChange 中跟随，
    // 布局永远不先于窗口旋转（官方最佳实践"方式一"）
    this.mWindow = WindowManager.getMainWindow();
    if (this.mWindow != null) {
      try {
        let rect = this.mWindow.getWindowProperties().windowRect;
        if (rect.width > 0 && rect.height > 0) {
          this.mWinW = px2vp(rect.width);
          this.mWinH = px2vp(rect.height);
        }
      } catch (err) {
        BLog.e('BiliPlayer getWindowProperties failed: ' + JSON.stringify(err));
      }
      this.mWindow.on('windowSizeChange', this.mSizeCb);
    }
    if (this.mWinW <= 0 || this.mWinH <= 0) {
      // 兜底：主窗口不可用时取屏幕物理尺寸
      let dis = display.getDefaultDisplaySync();
      if (dis != null) {
        this.mWinW = px2vp(dis.width);
        this.mWinH = px2vp(dis.height);
      }
    }
    this.player.setPlayId(this.bvid);
    // 大会员状态（清晰度档位解锁）、默认弹幕开关、记忆倍速
    this.mIsVip = (AppStorage.get<number>('ohBiliVipStatus') ?? 0) === 1;
    this.mIsShowDanmaku = (AppStorage.get<string>('openDanmu') ?? '1') !== '0';
    let storedSpeed: string = AppStorage.get<string>('playSpeed') ?? '1.0X';
    let parsedSpeed: number = parseFloat(storedSpeed);
    if (!isNaN(parsedSpeed) && parsedSpeed > 0 && parsedSpeed <= 2.0) {
      this.mSpeed = parsedSpeed;
    }
    if (this.cid > 0) {
      this.getDanmaku(true);
    }
  }

  /**
   * 窗口尺寸变化（旋转/分屏等）：全屏布局的唯一驱动源。
   * 横屏（w>h）→ 全屏布局生效；竖屏 → 若处于全屏则退出并恢复系统栏
   */
  private onWindowSizeChange(wPx: number, hPx: number): void {
    this.mWinW = px2vp(wPx);
    this.mWinH = px2vp(hPx);
    BLog.i('BiliPlayer onWindowSizeChange: ' + wPx + 'x' + hPx
      + ', fullScreen: ' + this.mIsFullScreen + ', pendingFsEnter: ' + this.mPendingFsEnter);
    if (wPx > hPx) {
      // 窗口已旋转为横屏：全屏布局跟随生效（不预先改布局，避免割裂）
      this.isPortrait = false;
      this.mPendingFsEnter = false;
      this.mIsFullScreen = true;
    } else {
      this.isPortrait = true;
      if (this.mPendingFsEnter) {
        // 竖屏视频全屏的进入旋转（横窗→竖窗，平板横屏场景）：旋转完成即进入全屏
        this.mPendingFsEnter = false;
        this.mIsFullScreen = true;
      } else if (this.mIsFullScreen) {
        // 横屏全屏退出：恢复布局与系统栏
        this.mIsLocked = false;
        this.mIsFullScreen = false;
        WindowManager.setFullScreen(true);
      }
    }
  }

  /**
   * 进入全屏（控制栏按钮触发）：横屏视频旋转窗口到横屏，系统旋转动画即过渡动画，
   * 布局由 windowSizeChange 跟随；竖屏视频保持竖屏窗口直接放大（B站样式）；
   * 窗口已处于目标方向（平板横屏）时不旋转，直接切换全屏布局
   */
  private enterFullScreen(): void {
    BLog.i('BiliPlayer enterFullScreen, aspRatio: ' + this.aspRatio
      + ', isPortrait: ' + this.isPortrait);
    WindowManager.setFullScreen(false);
    if (this.aspRatio >= 1) {
      if (this.isPortrait) {
        // 竖窗 → 横窗：全屏布局跟随旋转
        this.mPendingFsEnter = true;
        WindowManager.changeWindowDirection(window.Orientation.LANDSCAPE);
      } else {
        // 窗口已是横屏（平板横屏）：直接进入全屏布局
        this.getUIContext().animateTo({
          duration: 300,
          curve: Curve.EaseOut
        }, () => {
          this.mIsFullScreen = true;
        });
      }
    } else {
      if (this.isPortrait) {
        // 竖屏视频 + 竖窗（手机）：B站样式直接放大
        this.getUIContext().animateTo({
          duration: 300,
          curve: Curve.EaseOut
        }, () => {
          this.mIsFullScreen = true;
        });
      } else {
        // 竖屏视频 + 横窗（平板横屏）：旋转回竖窗，旋转完成进入全屏
        this.mPendingFsEnter = true;
        WindowManager.rotateWindowPortrait();
      }
    }
  }

  /**
   * 退出全屏：横屏全屏旋转窗口回竖屏（布局由 windowSizeChange 恢复）；
   * 竖屏视频全屏动画收起，结束后恢复系统栏
   */
  private exitFullScreen(): void {
    BLog.i('BiliPlayer exitFullScreen, isPortrait: ' + this.isPortrait);
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
        this.mIsFullScreen = false;
      });
    }
  }

  // 全屏模式下视频宽度：视频宽高比窄于容器时按容器做信箱式留黑（不裁剪、不拉伸）
  private fsXcWidth(): Length {
    if (!this.mIsFullScreen) {
      return '100%';
    }
    // 全屏容器即窗口本身（横屏全屏为旋转后的横窗、竖屏视频全屏为竖窗）
    let containerRatio: number = this.mWinW > 0 && this.mWinH > 0 ? this.mWinW / this.mWinH : this.aspRatio;
    if (containerRatio <= 0 || this.aspRatio >= containerRatio) {
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
        mIsShowDanmaku: $mIsShowDanmaku,
        mAcceptQuality: $mAcceptQuality,
        mAcceptDesc: $mAcceptDesc,
        mCurrentQn: $mCurrentQn,
        mIsVip: this.mIsVip,
        mSpeed: $mSpeed,
        mLoopPlay: $mLoopPlay,
        onRequestDanmakuInput: (): void => {
          this.openDanmakuInput();
        },
        requestEnterFullScreen: (): void => {
          this.enterFullScreen();
        },
        requestExitFullScreen: (): void => {
          this.exitFullScreen();
        },
        onSwitchQuality: (qn: number): void => {
          this.switchQuality(qn);
        },
        onSetSpeed: (speed: number): void => {
          this.setPlaySpeed(speed);
        },
        onDanmakuSettingsChanged: (): void => {
          this.onDanmakuSettingsChanged();
        }
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
        // 透传模式：重播按钮自身可点，遮罩其余区域不拦截下层控制视图的触摸
        .hitTestBehavior(HitTestMode.Transparent)
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

      if (this.mDanmakuInputVisible) {
        // 弹幕输入条：底部深色条内输入+发送，点击输入条外区域收起
        Column() {
          Blank()
          Row({ space: 8 }) {
            TextInput({ text: this.mDanmakuInputText, placeholder: '发个弹幕见证当下' })
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .fontColor(Color.White)
              .caretColor(Color.White)
              .placeholderColor('#99ffffff')
              .placeholderFont({ size: 13 })
              .backgroundColor('#33ffffff')
              .borderRadius(18)
              .padding({ left: 14, right: 14 })
              .defaultFocus(true)
              .onChange((value: string) => {
                this.mDanmakuInputText = value;
              })
              .onSubmit(() => {
                this.sendDanmaku();
              })
            Text(this.mDanmakuSending ? '发送中' : '发送')
              .fontSize(14)
              .fontColor(this.mDanmakuSending ? '#80ffffff' : '#fb7299')
              .height(36)
              .padding({ left: 16, right: 4 })
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.sendDanmaku();
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 10 })
          .backgroundColor('#66000000')
        }
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.closeDanmakuInput();
        })
      }

    }.width('100%')
    .aspectRatio(this.mIsFullScreen && this.mWinW > 0 && this.mWinH > 0 ? this.mWinW / this.mWinH : this.aspRatio)
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
    let preferredQn: number = AppStorage.get<number>('ohBiliPlayQn') ?? 0;
    ApiManager.getInstance().requestPlayUrl(bvid, cid, preferredQn > 0 ? preferredQn : undefined)
      .then((resp: PlayUrlResponse) => {
      if (this.mDestroyed || resp == null || resp.data == null) {
        return;
      }
      this.updateQualityInfo(resp);
      this.mPlayUrl = resp.data.durl[0].url.replace(/\\u0026/g, '&')
      BLog.i("requestPlayUrl Response Data url=" + this.mPlayUrl);
      this.initPlay(this.mPlayUrl);
    });
  }

  /** 记录 playurl 响应中的清晰度档位表与当前档位（清晰度菜单数据源） */
  private updateQualityInfo(resp: PlayUrlResponse): void {
    if (resp == null || resp.data == null) {
      return;
    }
    this.mCurrentQn = resp.data.quality ?? 0;
    if (resp.data.accept_quality != null && resp.data.accept_quality.length > 0) {
      this.mAcceptQuality = resp.data.accept_quality;
      this.mAcceptDesc = resp.data.accept_description ?? [];
    }
  }

  /** 切换清晰度：记忆播放位置与弹幕分段，重设数据源后 seek 续播 */
  private switchQuality(qn: number): void {
    if (qn === this.mCurrentQn || this.mDestroyed || this.localPath != '' || this.cid <= 0) {
      return;
    }
    let curMs: number = this.player.getCurrentTime();
    this.showLoadIng();
    ApiManager.getInstance().requestPlayUrl(this.bvid, this.cid, qn).then((resp: PlayUrlResponse) => {
      if (this.mDestroyed) {
        return;
      }
      if (resp == null || resp.data == null || resp.data.durl == null
        || resp.data.durl.length === 0) {
        this.hideLoadIng();
        this.getUIContext().getPromptAction().showToast({ message: '清晰度切换失败，请稍后重试' });
        return;
      }
      this.updateQualityInfo(resp);
      this.mPlayUrl = resp.data.durl[0].url.replace(/\\u0026/g, '&');
      BLog.i('BiliPlayer switchQuality qn=' + qn + ', resumeMs=' + curMs);
      // 记忆用户选择的清晰度档位（下次起播优先使用）
      AppStorage.setOrCreate('ohBiliPlayQn', qn);
      this.startAt = curMs / 1000.0;
      // 服务端回退（如 html5 线路最高 720P）时提示实际档位
      const gotQn: number = resp.data.quality ?? 0;
      if (gotQn > 0 && gotQn !== qn) {
        let gotDesc: string = '';
        for (let i = 0; i < this.mAcceptQuality.length; i++) {
          if (this.mAcceptQuality[i] === gotQn) {
            gotDesc = this.mAcceptDesc.length > i ? this.mAcceptDesc[i] : '';
            break;
          }
        }
        this.getUIContext().getPromptAction()
          .showToast({ message: '当前播放线路最高支持' + (gotDesc !== '' ? ' ' + gotDesc : '') + '，已为您切换' });
      }
      // 弹幕分段对齐（与进度条 seek 相同规则）
      if ((this.danmakuPn - 1) * DANMAKU_TIME <= curMs && this.danmakuPn * DANMAKU_TIME > curMs) {
        // 同段：重设数据源后弹幕计时随播放恢复
      } else {
        this.danmakuPn = Math.floor(curMs / DANMAKU_TIME) + 1;
      }
      let headers = new Map([
        ["User-Agent", ApiConstants.userAgent],
        ["Connection", "keep-alive"],
        ["Referer", ApiConstants.biliBase]
      ]);
      this.player.switchSource(this.mPlayUrl, headers);
    });
  }

  /** 设置倍速并持久化（设置页"播放速度"共享该键） */
  private setPlaySpeed(speed: number): void {
    this.mSpeed = speed;
    this.player.setSpeed(speed);
    AppStorage.setOrCreate('playSpeed', this.speedLabelOf(speed));
  }

  private speedLabelOf(speed: number): string {
    if (speed === Math.round(speed)) {
      return speed.toFixed(1) + 'X';
    }
    return speed.toFixed(2) + 'X';
  }

  /** 弹幕字号倍率（相对基准 1.2，'1.0X' → 1.0） */
  private danmakuScaleValue(): number {
    let v: number = parseFloat(this.danmuFontSize);
    if (isNaN(v) || v <= 0) {
      return 1.0;
    }
    return v;
  }

  /** 弹幕不透明度（'100%' → 1.0） */
  private danmakuOpacityNum(): number {
    let v: number = parseFloat(this.danmuOpacity);
    if (isNaN(v) || v <= 0) {
      return 1.0;
    }
    return Math.min(v / 100.0, 1.0);
  }

  /** 弹幕设置变更（设置页/播放器菜单）：即时应用到弹幕上下文 */
  onDanmakuSettingsChanged(): void {
    if (this.mDanmakuContext != null) {
      this.mDanmakuContext.setScaleTextSize(1.2 * this.danmakuScaleValue());
      this.mDanmakuContext.setDanmakuTransparency(this.danmakuOpacityNum());
    }
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
          if (thisClass.mSpeed != 1.0) {
            thisClass.player.setSpeed(thisClass.mSpeed);
          }
          if (thisClass.mLoopPlay) {
            thisClass.player.setLoop(true);
          }
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
      // 字号/不透明度来自用户设置（与设置页/播放器菜单共享键）
      .setScaleTextSize(1.2 * this.danmakuScaleValue())
      .setDanmakuTransparency(this.danmakuOpacityNum())
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
      if (!this.mIsShowDanmaku) {
        // 设置页"默认打开弹幕"关闭：初始隐藏
        this.mDanmakuModel.setVisibility(false);
      }
    }
  }

  private updateDanmaku(source: ProtoSource) {
    if (this.mDanmakuModel != null) {
      this.mParser = this.createParser(source);
      this.mDanmakuModel.prepare(this.mParser, this.mDanmakuContext);
    }
  }

  /**
   * 打开弹幕输入条：未登录引导登录
   */
  private openDanmakuInput(): void {
    let loggedIn: boolean = AppStorage.get<boolean>('isOhBiliLoggedIn') ?? false;
    if (!loggedIn) {
      NavHelper.goLogin();
      return;
    }
    this.mDanmakuInputVisible = true;
  }

  private closeDanmakuInput(): void {
    this.mDanmakuInputVisible = false;
  }

  /**
   * 发送弹幕：当前播放位置（毫秒）提交服务端，成功后本地即时上屏
   */
  private sendDanmaku(): void {
    if (this.mDanmakuSending) {
      return;
    }
    let text: string = this.mDanmakuInputText.trim();
    if (text.length == 0) {
      this.getUIContext().getPromptAction().showToast({ message: '弹幕内容不能为空' });
      return;
    }
    if (this.cid <= 0) {
      this.getUIContext().getPromptAction().showToast({ message: '视频信息未就绪，请稍后再试' });
      return;
    }
    this.mDanmakuSending = true;
    this.resolveAid().then((aid: number) => {
      if (aid <= 0) {
        this.mDanmakuSending = false;
        this.getUIContext().getPromptAction().showToast({ message: '视频信息获取失败，请重试' });
        return;
      }
      let progressMs: number = this.player.getCurrentTime();
      ApiManager.getInstance().sendDanmaku(this.cid, aid, text, progressMs, 1)
        .then((code: number) => {
          this.mDanmakuSending = false;
          if (code == 0) {
            this.getUIContext().getPromptAction().showToast({ message: '弹幕发送成功' });
            this.mDanmakuInputText = '';
            this.mDanmakuInputVisible = false;
            this.showDanmakuLocally(text);
            return;
          }
          if (code == -101) {
            this.getUIContext().getPromptAction().showToast({ message: '登录已失效，请重新登录' });
            NavHelper.goLogin();
            return;
          }
          this.getUIContext().getPromptAction().showToast({ message: '弹幕发送失败，请重试' });
        })
        .catch(() => {
          this.mDanmakuSending = false;
          this.getUIContext().getPromptAction().showToast({ message: '弹幕发送失败，请重试' });
        });
    }).catch(() => {
      this.mDanmakuSending = false;
      this.getUIContext().getPromptAction().showToast({ message: '视频信息获取失败，请重试' });
    });
  }

  /**
   * 发送成功后本地即时上屏：isLive 弹幕进实时渲染队列立即滚入；
   * time 取弹幕视图当前播放时刻（分段相对），使其落入当前屏幕渲染窗口；
   * 字号/描边样式与 DanmakuParser 解析规则一致
   */
  private showDanmakuLocally(text: string): void {
    if (this.mDanmakuContext == null || this.mDanmakuModel == null) {
      return;
    }
    let item: BaseDanmaku = this.mDanmakuContext.mDanmakuFactory
      .createDanmakuByContext(BaseDanmaku.TYPE_SCROLL_RL, this.mDanmakuContext);
    if (item == null) {
      return;
    }
    item.isLive = true;
    item.setTime(this.mDanmakuModel.getCurrentTime());
    item.text = text;
    item.textColor = 0xffffff;
    item.textSize = 25 * this.danmakuScaleValue();
    DanmakuUtils.fillText(item, item.text);
    this.mDanmakuModel.addDanmaku(item);
  }

  /**
   * 解析视频 aid：番剧场景直接取详情页传入的集 aid；
   * BaseVideo 场景下经 archive/stat 接口获取（结果缓存）
   */
  private async resolveAid(): Promise<number> {
    if (this.mAid > 0) {
      return this.mAid;
    }
    let response = await ApiManager.getInstance().requestArchiveStat(this.bvid);
    if (response != null && response.data != null && response.data.aid != null) {
      this.mAid = response.data.aid;
      return this.mAid;
    }
    return 0;
  }
}

@Component
struct PlayerControlView {
  private player: IPlayer;
  private mDanmakuModel: DanmakuView.Model;
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
  /** 清晰度档位表（与 PlayerView 同源） */
  @Link mAcceptQuality: number[];
  @Link mAcceptDesc: string[];
  @Link mCurrentQn: number;
  private mIsVip: boolean = false;
  @Link mSpeed: number;
  @Link mLoopPlay: boolean;
  /** 三点菜单弹层 */
  @State mSheetVisible: boolean = false;
  /** 弹层当前页：menu | danmaku | quality | speed */
  @State mSheetMode: string = 'menu';
  /** 弹幕设置滑条（与设置页共享持久化键，变更经 PlayerView @Watch 即时生效） */
  @StorageLink('danmuFontSize') mDanmakuScaleStr: string = '1.0X';
  @StorageLink('danmuOpacity') mDanmakuOpacityStr: string = '100%';
  /** 进入/退出全屏请求：全屏时机与窗口旋转由 PlayerView 统一决策（需要视频宽高比） */
  requestEnterFullScreen: () => void = () => {
  };
  requestExitFullScreen: () => void = () => {
  };
  /** 弹幕输入拉起请求（PlayerView 打开弹幕输入条） */
  onRequestDanmakuInput: () => void = () => {
  };
  onSwitchQuality: (qn: number) => void = (qn: number) => {
  };
  onSetSpeed: (speed: number) => void = (speed: number) => {
  };
  /** 弹幕设置变更（滑条即时生效回调，由 PlayerView 应用到弹幕上下文） */
  onDanmakuSettingsChanged: () => void = () => {
  };
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
                this.requestExitFullScreen();
              } else {
                router.back();
              }
            })

          Blank()

          Image($r('app.media.ic_player_setting_bold'))
            .width(24)
            .height(24)
            .onClick(_ => {
              this.mSheetMode = 'menu';
              this.mSheetVisible = true;
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
            .width(this.mIsFullScreen ? '70%' : '40%')
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

          // 弹幕输入入口：点击拉起底部弹幕输入条
          Text('发个弹幕见证当下')
            .fontSize(12)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 140 })
            .height(28)
            .padding({ left: 12, right: 12 })
            .borderRadius(14)
            .backgroundColor('#4d000000')
            .margin({ right: 8 })
            .onClick(() => {
              this.onRequestDanmakuInput();
            })

          // 弹幕开关：圆形按钮加大热区，开/关状态背景与透明度区分
          Row() {
            Image(this.mIsShowDanmaku ? $r("app.media.ic_danmaku_switch_on") :
            $r("app.media.ic_danmaku_switch_off"))
              .width(22)
              .height(22)
              .fillColor(Color.White)
          }
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor(this.mIsShowDanmaku ? '#4d000000' : '#26000000')
          .opacity(this.mIsShowDanmaku ? 1.0 : 0.7)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.mIsShowDanmaku = !this.mIsShowDanmaku;
            this.mDanmakuModel.setVisibility(this.mIsShowDanmaku);
          });

          if (!this.mIsFullScreen) {
            Image($r('app.media.ic_player_toggle_zoom'))
              .width(24)
              .height(24)
              .onClick(() => {
                this.requestEnterFullScreen();
              })
          } else {
            Image($r('app.media.ic_player_fullscreen_switch_halfscreen'))
              .width(24)
              .height(24)
              .onClick(() => {
                this.requestExitFullScreen();
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
    // 弹层锚定常驻根节点：避免 if(mIsShowCtl) 内的图标卸载导致弹层被连带关闭
    .bindSheet($$this.mSheetVisible, this.playerSettingsSheet(), {
      height: 400,
      dragBar: true,
      showClose: false,
      onDisappear: () => {
        this.mSheetMode = 'menu';
      }
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
    let ctlW: number = this.mIsFullScreen ? dis.height : dis.width;
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

  /** 三点菜单弹层：主菜单 / 弹幕设置 / 清晰度选择 / 播放速度 */
  @Builder
  playerSettingsSheet() {
    Column() {
      Row() {
        if (this.mSheetMode !== 'menu') {
          Image($r('app.media.ic_player_back_bold'))
            .width(20)
            .height(20)
            .onClick(() => {
              this.mSheetMode = 'menu';
            })
        }
        Text(this.sheetTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .margin({ left: this.mSheetMode !== 'menu' ? 8 : 0 })
        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      Divider()
        .color('#f0f0f0')
        .margin({ left: 16, right: 16 })
      Scroll() {
        Column() {
          if (this.mSheetMode === 'menu') {
            this.menuPane()
          } else if (this.mSheetMode === 'danmaku') {
            this.danmakuPane()
          } else if (this.mSheetMode === 'quality') {
            this.qualityPane()
          } else {
            this.speedPane()
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }

  private sheetTitle(): string {
    if (this.mSheetMode === 'danmaku') {
      return '弹幕设置';
    }
    if (this.mSheetMode === 'quality') {
      return '清晰度选择';
    }
    if (this.mSheetMode === 'speed') {
      return '播放速度';
    }
    return '播放设置';
  }

  @Builder
  menuPane() {
    Column() {
      this.menuRow('弹幕设置', '', () => {
        this.mSheetMode = 'danmaku';
      })
      this.menuRow('清晰度选择', this.currentQualityDesc(), () => {
        this.mSheetMode = 'quality';
      })
      this.menuRow('播放速度', this.speedLabel(), () => {
        this.mSheetMode = 'speed';
      })
      Row() {
        Text('循环播放')
          .fontSize(15)
          .fontColor('#333333')
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.mLoopPlay })
          .selectedColor('#fb7299')
          .onChange((isOn: boolean) => {
            this.mLoopPlay = isOn;
            this.player.setLoop(isOn);
          })
      }
      .width('100%')
      .height(48)
    }
    .width('100%')
  }

  @Builder
  menuRow(title: string, value: string, onTap: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor('#333333')
      Blank()
      if (value !== '') {
        Text(value)
          .fontSize(13)
          .fontColor('#999999')
          .margin({ right: 4 })
          .maxLines(1)
      }
      Text('›')
        .fontSize(18)
        .fontColor('#cccccc')
    }
    .width('100%')
    .height(48)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  danmakuPane() {
    Column() {
      Row() {
        Text('弹幕字号')
          .fontSize(15)
          .fontColor('#333333')
        Blank()
        Text(this.mDanmakuScaleStr)
          .fontSize(13)
          .fontColor('#fb7299')
      }
      .width('100%')
      .height(40)
      Slider({
        value: this.scaleSliderValue(),
        min: 0.6,
        max: 1.6,
        step: 0.1,
        style: SliderStyle.InSet
      })
        .width('100%')
        .blockColor('#fb7299')
        .trackColor('#f0f0f0')
        .selectedColor('#fb7299')
        .onChange((value: number, mode: SliderChangeMode) => {
          this.mDanmakuScaleStr = value.toFixed(1) + 'X';
          this.onDanmakuSettingsChanged();
        })
      Row() {
        Text('弹幕不透明度')
          .fontSize(15)
          .fontColor('#333333')
        Blank()
        Text(this.mDanmakuOpacityStr)
          .fontSize(13)
          .fontColor('#fb7299')
      }
      .width('100%')
      .height(40)
      .margin({ top: 8 })
      Slider({
        value: this.opacitySliderValue(),
        min: 0.5,
        max: 1.0,
        step: 0.05,
        style: SliderStyle.InSet
      })
        .width('100%')
        .blockColor('#fb7299')
        .trackColor('#f0f0f0')
        .selectedColor('#fb7299')
        .onChange((value: number, mode: SliderChangeMode) => {
          this.mDanmakuOpacityStr = Math.round(value * 100) + '%';
          this.onDanmakuSettingsChanged();
        })
    }
    .width('100%')
  }

  @Builder
  qualityPane() {
    Column() {
      if (this.mAcceptQuality.length === 0) {
        Text('暂无可用清晰度信息')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 24 })
      }
      ForEach(this.mAcceptQuality, (qn: number) => {
        Row() {
          Text(this.qualityDescAt(qn))
            .fontSize(15)
            .fontColor(this.mCurrentQn === qn ? '#fb7299' :
            (this.qualitySelectable(qn) ? '#333333' : '#bbbbbb'))
          if (this.isVipQn(qn)) {
            Text('大会员')
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor(this.qualitySelectable(qn) ? '#fb7299' : '#bbbbbb')
              .borderRadius(4)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .margin({ left: 8 })
          }
          Blank()
          if (this.mCurrentQn === qn) {
            Text('✓')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fb7299')
          }
        }
        .width('100%')
        .height(46)
        .onClick(() => {
          this.onQualityTap(qn);
        })
      }, (qn: number) => 'qn_' + qn)
    }
    .width('100%')
  }

  @Builder
  speedPane() {
    Column() {
      ForEach(this.speedOptions(), (speed: number) => {
        Row() {
          Text(this.speedLabelOf(speed))
            .fontSize(15)
            .fontColor(this.mSpeed === speed ? '#fb7299' : '#333333')
          Blank()
          if (this.mSpeed === speed) {
            Text('✓')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fb7299')
          }
        }
        .width('100%')
        .height(46)
        .onClick(() => {
          this.onSetSpeed(speed);
        })
      }, (speed: number) => 'speed_' + speed)
    }
    .width('100%')
  }

  /** 弹幕字号滑条当前值（'1.2X' → 1.2） */
  private scaleSliderValue(): number {
    let v: number = parseFloat(this.mDanmakuScaleStr);
    if (isNaN(v) || v < 0.6) {
      return 1.0;
    }
    return Math.min(v, 1.6);
  }

  /** 弹幕不透明度滑条当前值（'100%' → 1.0） */
  private opacitySliderValue(): number {
    let v: number = parseFloat(this.mDanmakuOpacityStr);
    if (isNaN(v) || v < 50) {
      return 1.0;
    }
    return Math.min(v / 100.0, 1.0);
  }

  /** 当前清晰度描述（菜单行右侧值） */
  private currentQualityDesc(): string {
    if (this.mCurrentQn <= 0) {
      return '';
    }
    return this.qualityDescAt(this.mCurrentQn);
  }

  /** qn → 描述：优先 playurl 返回的描述表，缺失时静态兜底 */
  private qualityDescAt(qn: number): string {
    let idx: number = this.mAcceptQuality.indexOf(qn);
    if (idx >= 0 && idx < this.mAcceptDesc.length) {
      let desc: string = this.mAcceptDesc[idx];
      if (desc != null && desc !== '') {
        return desc;
      }
    }
    return PlayerControlView.qnDescFallback(qn);
  }

  private static qnDescFallback(qn: number): string {
    if (qn >= 127) {
      return '8K 超高清';
    }
    if (qn >= 126) {
      return '杜比视界';
    }
    if (qn >= 125) {
      return 'HDR 真彩';
    }
    if (qn >= 120) {
      return '4K 超清';
    }
    if (qn >= 116) {
      return '1080P60';
    }
    if (qn >= 112) {
      return '1080P 高码率';
    }
    if (qn >= 80) {
      return '1080P 高清';
    }
    if (qn >= 74) {
      return '720P60';
    }
    if (qn >= 64) {
      return '720P 高清';
    }
    if (qn >= 32) {
      return '480P 清晰';
    }
    return '360P 流畅';
  }

  /** 720P60 及以上为大会员专享档位 */
  private isVipQn(qn: number): boolean {
    return qn >= 74;
  }

  private qualitySelectable(qn: number): boolean {
    return !this.isVipQn(qn) || this.mIsVip;
  }

  private onQualityTap(qn: number): void {
    if (!this.qualitySelectable(qn)) {
      this.getUIContext().getPromptAction().showToast({ message: '该清晰度为大会员专享' });
      return;
    }
    if (qn === this.mCurrentQn) {
      return;
    }
    this.mSheetVisible = false;
    this.onSwitchQuality(qn);
  }

  private speedOptions(): number[] {
    // AVPlayer 仅支持这五档倍速
    return [0.75, 1.0, 1.25, 1.75, 2.0];
  }

  private speedLabelOf(speed: number): string {
    if (speed === Math.round(speed)) {
      return speed.toFixed(1) + 'X';
    }
    return speed.toFixed(2) + 'X';
  }

  private speedLabel(): string {
    return this.speedLabelOf(this.mSpeed);
  }

  private showLoadIng() {
    this.loadingVisible = true;
    this.replayVisible = false;
  }
}