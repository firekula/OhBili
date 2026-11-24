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
    /** DASH 音视频分离流（fnval=4048 时返回） */
    dash?: BiliDash
}

export interface PlayUrlDurl {
    length: number
    size: number
    url: string
}

/** B站 DASH 流集合（fnval=4048 响应的 dash 字段） */
export interface BiliDash {
    duration?: number
    min_buffer_time?: number
    video?: BiliDashStream[]
    audio?: BiliDashStream[]
    flac?: BiliDashAudioGroup
    dolby?: BiliDashDolby
}

/** DASH 单条流（视频/音频通用） */
export interface BiliDashStream {
    id: number
    baseUrl: string
    backupUrl?: string[]
    bandwidth?: number
    mimeType?: string
    codecs?: string
    width?: number
    height?: number
    frameRate?: string
    sar?: string
    startWithSap?: number
    SegmentBase?: BiliSegmentBase
}

/** 单文件 fMP4 的字节区间描述（初始化段 + sidx 索引区间） */
export interface BiliSegmentBase {
    Initialization: string
    indexRange: string
}

/** Hi-Res 无损音质组 */
export interface BiliDashAudioGroup {
    display?: string
    audio?: BiliDashStream[]
}

/** 杜比音质组 */
export interface BiliDashDolby {
    type?: number
    audio?: BiliDashStream[]
}