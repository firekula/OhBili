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

import { BaseResponse } from './Response';

export interface PlayUrlResponse extends BaseResponse<PlayUrl> {
    /** 番剧 playurl 接口（pgc/player/web/playurl）将数据嵌在 result 字段而非 data */
    result?: PlayUrl
}

export interface PlayUrl {
    quality: number
    format: string
    seek_param: string
    seek_type: string
    durl: PlayUrlDurl[]
    /** 可用清晰度档位值列表（如 16/32/64/80），缓存选档使用 */
    accept_quality?: number[]
    /** 可用清晰度档位描述列表（与 accept_quality 下标对应） */
    accept_description?: string[]
    /** 视频总时长（毫秒） */
    timelength?: number
    /** DASH 音视频分离流（fnval=4048 时返回，durl 线路为 null） */
    dash?: BiliDash | null
}

export interface PlayUrlDurl {
    length: number
    size: number
    url: string
}

/** B站 DASH 流集合（fnval=4048 响应的 dash 字段） */
export interface BiliDash {
    /** 视频总时长（秒） */
    duration: number
    /** 最小缓冲时长（秒） */
    min_buffer_time?: number
    video: BiliDashStream[]
    audio: BiliDashAudioStream[]
    /** 杜比音质组（本期不消费，仅建模） */
    dolby?: BiliDashDolby
    /** Hi-Res 无损音质（本期不消费，仅建模） */
    flac?: BiliDashAudioStream | null
}

/** DASH 视频流（id 即清晰度 qn：16/32/64/80/112/120…） */
export interface BiliDashStream {
    id: number
    baseUrl: string
    backupUrl: string[]
    /** 编码标识，如 "avc1.640032" / "hev1.1.6.L120.90" / "av01.0.08M.08" */
    codecs: string
    bandwidth: number
    mimeType: string
    width: number
    height: number
    /** 帧率（如 "25.000"） */
    frameRate?: string
    /** 采样纵横比（如 "1:1"） */
    sar?: string
    startWithSap?: number
    SegmentBase: BiliSegmentBase
}

/** DASH 音频流（无 width/height，id 如 30216/30280/30250/30251） */
export interface BiliDashAudioStream {
    id: number
    baseUrl: string
    backupUrl: string[]
    codecs: string
    bandwidth: number
    mimeType: string
    SegmentBase: BiliSegmentBase
}

/** 单文件 fMP4 的字节区间描述（初始化段 + sidx 索引区间） */
export interface BiliSegmentBase {
    Initialization: string
    indexRange: string
}

/** 杜比音质组 */
export interface BiliDashDolby {
    type: number
    audio: BiliDashAudioStream[]
}