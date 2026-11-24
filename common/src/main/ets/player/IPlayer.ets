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

import { OnTimeUpdateCallback, OnTimeStrUpdateCallback,
    OnStateChangeCallback, OnSizeChangeCallback } from './IPlayerCallback';
import { media } from '@kit.MediaKit';

export abstract class IPlayer {
    protected mOnTimeUpdateCallback: OnTimeUpdateCallback;
    protected mOnTimeStrUpdateCallback: OnTimeStrUpdateCallback;
    protected mOnStateChangeCallback: OnStateChangeCallback;
    protected mOnSizeChangeCallback: OnSizeChangeCallback;

    setOnTimeUpdateCallback(callback: OnTimeUpdateCallback) {
        this.mOnTimeUpdateCallback = callback;
    }

    setOnTimeStrUpdateCallback(callback: OnTimeStrUpdateCallback) {
        this.mOnTimeStrUpdateCallback = callback;
    }

    setOnStateChangeCallback(callback: OnStateChangeCallback) {
        this.mOnStateChangeCallback = callback;
    }

    setOnSizeChangeCallback(callback: OnSizeChangeCallback) {
        this.mOnSizeChangeCallback = callback;
    }

    abstract initPlay(context: object): Promise<void>

    abstract controller(): XComponentController

    abstract libraryName(): string

    abstract id(): string

    abstract setDataSource(url: string, headers?:Map<string,string>, strategy?: media.PlaybackStrategy): void

    abstract play(): void

    abstract pause(): void

    abstract stop(): void

    abstract seekTo(value: number): void

    /** 页面销毁时释放播放器资源（幂等；进行中的异步 prepare 完成后不得再起播） */
    abstract release(): void

    /** 设置 prepared 后是否自动起播（页面隐藏时置 false，防止后台/被覆盖时自动出声） */
    abstract setAutoPlay(auto: boolean): void

    abstract setScreenOn(on: boolean): void

    abstract getDuration(): number

    /** 当前播放位置（毫秒），未起播返回 0 */
    abstract getCurrentTime(): number

    /** 设置倍速（AvPlayer 支持 0.75/1.0/1.25/1.75/2.0） */
    abstract setSpeed(speed: number): void

    /** 设置是否循环播放 */
    abstract setLoop(loop: boolean): void

    /** 设置播放器实例音量（0.0-1.0，不影响系统音量；默认空实现） */
    setVolume(volume: number): void {
    }

    /** 当前播放器实例音量（0.0-1.0；默认 1.0） */
    getVolume(): number {
        return 1.0;
    }

    /** 播放中切换数据源（复用实例，用于清晰度切换；prepared 后由上层 seek 续播） */
    abstract switchSource(url: string, headers?: Map<string,string>): void

    abstract setPlayId(playId: string)

    abstract getPlayId(): string
}