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
}

export interface PlayUrlDurl {
    length: number
    size: number
    url: string
}