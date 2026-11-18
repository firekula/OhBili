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

let updateProgressTimer;

export class AvPlayer extends IPlayer {
    xController: XComponentController = new XComponentController()
    private avPlayer: any;
    private count: number = 0;
    private surfaceId: string; // surfaceID用于播放画面显示
    private isSeek: boolean = true; // 用于区分模式是否支持seek操作
    /** 本地播放文件句柄（fdSrc 播放期间需保持打开，切换数据源时关闭上一个） */
    private localFd: number = -1;

    public initPlay(context: object): Promise<void> {
        this.xController.setXComponentSurfaceSize({surfaceWidth:1920,surfaceHeight:1080});
        this.surfaceId = this.xController.getXComponentSurfaceId();
        let thisClass = this;
        var promise = new Promise<void>(function (resolve, reject) {
            media.createAVPlayer().then(player => {
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
        return "xcomponent";
    }

    public setDataSource(url: string, headers?:Map<string,string>) {
        this.isSeek = false;
        if (url.startsWith('/')) {
            // 本地文件：fs.open 取 fd 走 fdSrc 播放（AVPlayer.url 不支持沙箱绝对路径）
            this.openLocalFile(url);
            return;
        }
        if (headers !== undefined && headers.size > 0) {
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
            this.avPlayer.setMediaSource(mediaSource).catch((error: BusinessError) => {
                console.error(`setMediaSource failed, code is ${error.code}, message is ${error.message}`);
                this.avPlayer.url = url;
            });
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
        this.avPlayer.play();
    }

    public pause() {
        this.avPlayer.pause();
    }

    public stop() {
        this.avPlayer.stop();
    }

    public seekTo(value: number) {
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
        return this.avPlayer.duration;
    }

    public setPlayId(playId: string) {
    }

    public getPlayId(): string {
        return "";
    }

    // 注册avplayer回调函数
    private setAVPlayerCallback() {
        // seek操作结果回调函数
        this.avPlayer.on('seekDone', (seekDoneTime) => {
            console.info(`AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
            this.avPlayer.play();
        })
        // error回调监听函数,当avPlayer在操作过程中出现错误时调用reset接口触发重置流程
        this.avPlayer.on('error', (err) => {
            this.updateState(IPlayStatus.ERROR);
            console.error(`Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
            this.avPlayer.reset(); // 调用reset重置资源，触发idle状态
        })
        // 状态机变化回调函数
        this.avPlayer.on('stateChange', async (state, reason) => {
            switch (state) {
                case 'idle': // 成功调用reset接口后触发该状态机上报
                    console.info('AVPlayer state idle called.');
                    this.avPlayer.release(); // 调用release接口销毁实例对象
                    break;
                case 'initialized': // avplayer 设置播放源后触发该状态上报
                    this.updateState(IPlayStatus.INIT);
                    console.info('AVPlayerstate initialized called.');
                    this.avPlayer.surfaceId = this.surfaceId; // 设置显示画面，当播放的资源为纯音频时无需设置
                    this.avPlayer.prepare().then(() => {
                        console.info('AVPlayer prepare succeeded.');
                    }, (err) => {
                        console.error(`Invoke prepare failed, code is ${err.code}, message is ${err.message}`);
                    });
                    break;
                case 'prepared': // prepare调用成功后上报该状态机
                    console.info('AVPlayer state prepared called.');
                    this.updateState(IPlayStatus.PREPARED);
                    if (this.mOnSizeChangeCallback) {
                        this.mOnSizeChangeCallback.OnSizeChange(this.avPlayer.width, this.avPlayer.height);
                    }
                    // surface 缓冲区初始为 1920x1080，与视频实际宽高比不一致可能导致拉伸，
                    // 播放前把缓冲区调整为视频实际宽高比（最大边 1920 封顶）
                    this.updateSurfaceSize(this.avPlayer.width, this.avPlayer.height);
                    this.avPlayer.play(); // 调用播放接口开始播放
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
                    this.avPlayer.reset(); // 调用reset接口初始化avplayer状态
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
        updateProgressTimer = setInterval(function () {
            console.info("AVPlayer startProgressTask");
            thisClass.setProgress();
        }, 1000);
    }

    private stopProgressTask() {
        console.info("AVPlayer stopProgressTask");
        clearInterval(updateProgressTimer);
    }
}