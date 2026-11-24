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

import { IPlayer } from './IPlayer';
import { IPlayStatus } from './IPlayStatus';
import media from '@ohos.multimedia.media';
import fs from '@ohos.file.fs';
import { BusinessError } from '@ohos.base';
import { StringUtil } from '../utils/StringUtil';

let xcSeq: number = 0;

export class AvPlayer extends IPlayer {
    xController: XComponentController = new XComponentController()
    private avPlayer: any;
    private count: number = 0;
    private surfaceId: string; // surfaceID用于播放画面显示
    private isSeek: boolean = true; // 用于区分模式是否支持seek操作
    /** 本地播放文件句柄（fdSrc 播放期间需保持打开，切换数据源时关闭上一个） */
    private localFd: number = -1;
    /** 已释放标记：release 后所有异步回调（prepare/seekDone 等）一律不再起播 */
    private isReleased: boolean = false;
    /** prepared 后是否自动起播（页面隐藏时置 false，防止被覆盖时自动出声） */
    private autoPlay: boolean = true;
    /** 播放实例标识（多视频页叠栈时保证 XComponent id 唯一） */
    private myId: string = "xcomponent_" + (xcSeq++);
    /** 本实例的 playId（原为空实现导致上层 bvid==getPlayId() 恒 false，离开页面从不停止播放） */
    private playId: string = "";
    private updateProgressTimer: number = -1;
    /** 清晰度切换中：reset→idle 时不 release，改设新数据源 */
    private isSwitchingSource: boolean = false;
    /** 待切换的数据源（reset→idle 回调后应用） */
    private pendingSourceUrl: string = "";
    private pendingSourceHeaders: Map<string, string> | null = null;

    public initPlay(context: object): Promise<void> {
        this.xController.setXComponentSurfaceSize({surfaceWidth:1920,surfaceHeight:1080});
        this.surfaceId = this.xController.getXComponentSurfaceId();
        let thisClass = this;
        var promise = new Promise<void>(function (resolve, reject) {
            media.createAVPlayer().then(player => {
                if (thisClass.isReleased) {
                    // 页面已销毁：直接释放新建实例，避免起播出"幽灵"声音
                    player.release();
                    resolve();
                    return;
                }
                thisClass.avPlayer = player;
                thisClass.setAVPlayerCallback();
                resolve();
            });
        });
        return promise;
    }

    public controller(): XComponentController {
        return this.xController;
    }

    public libraryName(): string {
        return null;
    }

    public id(): string {
        return this.myId;
    }

    public setDataSource(url: string, headers?:Map<string,string>, strategy?: media.PlaybackStrategy) {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        this.isSeek = false;
        this.applySource(url, headers, strategy);
    }

    /**
     * 播放中切换数据源（清晰度切换）：复用播放器实例，
     * reset 回到 idle 后设新源重新 prepare，由上层在 prepared 后 seek 续播。
     */
    public switchSource(url: string, headers?: Map<string, string>): void {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        let state: string = this.avPlayer.state;
        if (state === 'idle') {
            this.isSeek = false;
            this.applySource(url, headers);
            return;
        }
        this.pendingSourceUrl = url;
        this.pendingSourceHeaders = headers ?? null;
        this.isSwitchingSource = true;
        this.stopProgressTask();
        this.avPlayer.reset();
    }

    /** 实际设置数据源（本地 fdSrc / 带头 MediaSource / 直连 url）；strategy 存在时作为 ABR 起播档位提示传入 */
    private applySource(url: string, headers?: Map<string, string>, strategy?: media.PlaybackStrategy): void {
        if (url.startsWith('/')) {
            // 本地文件：fs.open 取 fd 走 fdSrc 播放（AVPlayer.url 不支持沙箱绝对路径）
            this.openLocalFile(url);
            return;
        }
        if (headers !== undefined && headers !== null && headers.size > 0) {
            // 系统播放器默认 HTTP 请求不携带自定义头，B站 CDN 校验 User-Agent/Referer，
            // 直接赋值 url 会得到 403（content-type: text/html 错误页 → 5400106）。
            // 须通过 MediaSource 携带自定义请求头（API 12+）。
            let headerRecord: Record<string, string> = {};
            headers.forEach((value: string, key: string) => {
                if (key !== 'Connection') {
                    headerRecord[key] = value;
                }
            });
            let mediaSource: media.MediaSource = media.createMediaSourceWithUrl(url, headerRecord);
            if (strategy !== undefined && strategy !== null) {
                this.avPlayer.setMediaSource(mediaSource, strategy).catch((error: BusinessError) => {
                    console.error(`setMediaSource with strategy failed, code is ${error.code}, message is ${error.message}`);
                    this.avPlayer.url = url;
                });
            } else {
                this.avPlayer.setMediaSource(mediaSource).catch((error: BusinessError) => {
                    console.error(`setMediaSource failed, code is ${error.code}, message is ${error.message}`);
                    this.avPlayer.url = url;
                });
            }
        } else {
            this.avPlayer.url = url;
        }
    }

    /**
     * 打开本地文件以 fdSrc 方式播放
     */
    private openLocalFile(path: string): void {
        this.closeLocalFile();
        try {
            let file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
            this.localFd = file.fd;
            this.avPlayer.fdSrc = { fd: file.fd };
        } catch (error) {
            console.error(`AvPlayer openLocalFile failed, path: ${path}, error: ${JSON.stringify(error)}`);
        }
    }

    /**
     * 关闭上一次本地播放的文件句柄（fdSrc 播放期间须保持打开）
     */
    private closeLocalFile(): void {
        if (this.localFd >= 0) {
            try {
                fs.closeSync(this.localFd);
            } catch (error) {
                console.warn(`AvPlayer closeLocalFile failed: ${JSON.stringify(error)}`);
            }
            this.localFd = -1;
        }
    }

    public play() {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        this.avPlayer.play();
    }

    public pause() {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        if (this.avPlayer.state === 'playing') {
            this.avPlayer.pause();
        }
    }

    public stop() {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        this.avPlayer.stop();
    }

    public release(): void {
        if (this.isReleased) {
            return;
        }
        this.isReleased = true;
        this.stopProgressTask();
        this.closeLocalFile();
        try {
            if (this.avPlayer) {
                this.avPlayer.release();
            }
        } catch (error) {
            console.warn(`AvPlayer release failed: ${JSON.stringify(error)}`);
        }
    }

    public setAutoPlay(auto: boolean): void {
        this.autoPlay = auto;
    }

    public seekTo(value: number) {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        this.avPlayer.seek(value);
    }

    // 将 XComponent 的 surface 缓冲区调整为视频实际宽高比，避免非 16:9 视频拉伸
    private updateSurfaceSize(videoWidth: number, videoHeight: number): void {
        if (videoWidth <= 0 || videoHeight <= 0) {
            return;
        }
        let targetWidth: number = videoWidth;
        let targetHeight: number = videoHeight;
        let maxDim: number = Math.max(targetWidth, targetHeight);
        if (maxDim > 1920) {
            let scale: number = 1920 / maxDim;
            targetWidth = Math.round(targetWidth * scale);
            targetHeight = Math.round(targetHeight * scale);
        }
        this.xController.setXComponentSurfaceSize({surfaceWidth: targetWidth, surfaceHeight: targetHeight});
    }

    public setScreenOn(on: boolean) {
    }

    public getDuration(): number {
        if (this.isReleased || !this.avPlayer) {
            return 0;
        }
        return this.avPlayer.duration;
    }

    public getCurrentTime(): number {
        if (this.isReleased || !this.avPlayer) {
            return 0;
        }
        let state: string = this.avPlayer.state;
        if (state === 'idle' || state === 'initialized' || state === 'released') {
            return 0;
        }
        let time: number = this.avPlayer.currentTime;
        return time > 0 ? time : 0;
    }

    public setSpeed(speed: number): void {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        let state: string = this.avPlayer.state;
        if (state !== 'prepared' && state !== 'playing' && state !== 'paused' && state !== 'completed') {
            // 未就绪：由上层在 prepared 后重新下发
            return;
        }
        // AVPlayer 仅支持 0.75/1.0/1.25/1.75/2.0 五档，就近吸附
        let playbackSpeed: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
        if (speed < 0.875) {
            playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
        } else if (speed < 1.125) {
            playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
        } else if (speed < 1.5) {
            playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
        } else if (speed < 1.875) {
            playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
        } else {
            playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
        }
        try {
            this.avPlayer.speed = playbackSpeed;
        } catch (error) {
            console.warn(`AvPlayer setSpeed failed: ${JSON.stringify(error)}`);
        }
    }

    public setLoop(loop: boolean): void {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        try {
            this.avPlayer.loop = loop;
        } catch (error) {
            console.warn(`AvPlayer setLoop failed: ${JSON.stringify(error)}`);
        }
    }

    public setVolume(volume: number): void {
        if (this.isReleased || !this.avPlayer) {
            return;
        }
        let v: number = volume;
        if (v < 0.0) {
            v = 0.0;
        } else if (v > 1.0) {
            v = 1.0;
        }
        try {
            this.avPlayer.setVolume(v);
        } catch (error) {
            console.warn(`AvPlayer setVolume failed: ${JSON.stringify(error)}`);
        }
    }

    public getVolume(): number {
        if (this.isReleased || !this.avPlayer) {
            return 1.0;
        }
        try {
            let v: number = this.avPlayer.volume;
            if (v == null || isNaN(v) || v < 0.0) {
                return 1.0;
            }
            return Math.min(v, 1.0);
        } catch (error) {
            return 1.0;
        }
    }

    public setPlayId(playId: string) {
        this.playId = playId;
    }

    public getPlayId(): string {
        return this.playId;
    }

    // 注册avplayer回调函数
    private setAVPlayerCallback() {
        // seek操作结果回调函数
        this.avPlayer.on('seekDone', (seekDoneTime) => {
            console.info(`AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
            // 页面已销毁或隐藏时不再自动恢复播放，防止"幽灵"起播
            if (this.isReleased || !this.autoPlay) {
                return;
            }
            this.avPlayer.play();
        })
        // error回调监听函数,当avPlayer在操作过程中出现错误时调用reset接口触发重置流程
        this.avPlayer.on('error', (err) => {
            console.error(`Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
            if (this.isReleased) {
                return;
            }
            this.updateState(IPlayStatus.ERROR);
            this.avPlayer.reset(); // 调用reset重置资源，触发idle状态
        })
        // 状态机变化回调函数
        this.avPlayer.on('stateChange', async (state, reason) => {
            switch (state) {
                case 'idle': // 成功调用reset接口后触发该状态机上报
                    console.info('AVPlayer state idle called.');
                    if (this.isSwitchingSource) {
                        // 清晰度切换：复用实例重设数据源，不销毁
                        this.isSwitchingSource = false;
                        this.isSeek = false;
                        this.applySource(this.pendingSourceUrl, this.pendingSourceHeaders ?? undefined);
                        this.pendingSourceUrl = '';
                        this.pendingSourceHeaders = null;
                        break;
                    }
                    this.avPlayer.release(); // 调用release接口销毁实例对象
                    break;
                case 'initialized': // avplayer 设置播放源后触发该状态上报
                    console.info('AVPlayerstate initialized called.');
                    if (this.isReleased) {
                        // 页面已销毁：不再 prepare，直接释放，防止 prepare 完成后自动起播
                        this.avPlayer.release();
                        break;
                    }
                    this.updateState(IPlayStatus.INIT);
                    this.avPlayer.surfaceId = this.surfaceId; // 设置显示画面，当播放的资源为纯音频时无需设置
                    this.avPlayer.prepare().then(() => {
                        console.info('AVPlayer prepare succeeded.');
                    }, (err) => {
                        console.error(`Invoke prepare failed, code is ${err.code}, message is ${err.message}`);
                    });
                    break;
                case 'prepared': // prepare调用成功后上报该状态机
                    console.info('AVPlayer state prepared called.');
                    if (this.isReleased) {
                        this.avPlayer.release();
                        break;
                    }
                    this.updateState(IPlayStatus.PREPARED);
                    if (this.mOnSizeChangeCallback) {
                        this.mOnSizeChangeCallback.OnSizeChange(this.avPlayer.width, this.avPlayer.height);
                    }
                    // surface 缓冲区初始为 1920x1080，与视频实际宽高比不一致可能导致拉伸，
                    // 播放前把缓冲区调整为视频实际宽高比（最大边 1920 封顶）
                    this.updateSurfaceSize(this.avPlayer.width, this.avPlayer.height);
                    // 页面隐藏（被其他视频页覆盖）时不自动起播，防止上一个视频在后台出声
                    if (this.autoPlay) {
                        this.avPlayer.play(); // 调用播放接口开始播放
                    }
                    break;
                case 'playing': // play成功调用后触发该状态机上报
                    this.updateState(IPlayStatus.PLAY);
                    this.stopProgressTask();
                    this.startProgressTask();
                    console.info('AVPlayer state playing called.');
                    break;
                case 'paused': // pause成功调用后触发该状态机上报
                    this.updateState(IPlayStatus.PAUSE);
                    this.stopProgressTask();
                    console.info('AVPlayer state paused called.');
                    break;
                case 'completed': // 播放结束后触发该状态机上报
                    this.updateState(IPlayStatus.DONE);
                    this.stopProgressTask();
                    console.info('AVPlayer state completed called.');
                    // this.avPlayer.stop(); //调用播放结束接口
                    break;
                case 'stopped': // stop接口成功调用后触发该状态机上报
                    this.updateState(IPlayStatus.DONE);
                    this.stopProgressTask();
                    console.info('AVPlayer state stopped called.');
                    if (!this.isReleased) {
                        this.avPlayer.reset(); // 调用reset接口初始化avplayer状态
                    }
                    break;
                case 'released':
                    console.info('AVPlayer state released called.');
                    break;
                default:
                    console.info('AVPlayer state unknown called.');
                    break;
            }
        })
    }

    private updateState(state: IPlayStatus) {
        if (this.mOnStateChangeCallback) {
            this.mOnStateChangeCallback.OnStateChange(state);
        }
    }

    private setProgress() {
        let position = this.avPlayer.currentTime;
        let duration = this.avPlayer.duration;
        let pos = 0;

        if (this.mOnTimeUpdateCallback) {
            this.mOnTimeUpdateCallback.onTimeUpdate(position, duration)
        }

        if (duration > 0) {
            let curPercent = position / duration;
            pos = curPercent * 100;
        }
        console.info("setProgress position:" + position + ",duration:" + duration + ",progressValue:" + pos);
        let totalTime = StringUtil.stringForTime(duration);
        if (position > duration) {
            position = duration;
        }
        let currentTime = StringUtil.stringForTime(position);

        if (this.mOnTimeStrUpdateCallback) {
            this.mOnTimeStrUpdateCallback.onTimeStrUpdate(currentTime, totalTime)
        }

    }

    private startProgressTask() {
        let thisClass = this;
        this.updateProgressTimer = setInterval(function () {
            console.info("AVPlayer startProgressTask");
            thisClass.setProgress();
        }, 1000);
    }

    private stopProgressTask() {
        console.info("AVPlayer stopProgressTask");
        clearInterval(this.updateProgressTimer);
        this.updateProgressTimer = -1;
    }
}