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

/**
 * 收藏夹内容列表响应（GET x/v3/fav/resource/list，Cookie 鉴权，pn/ps 分页）。
 */
export interface FavResourceResponse extends BaseResponse<FavResourceData> {

}

/**
 * 收藏夹内容数据：medias 为收藏视频列表，has_more 为分页标志。
 */
export interface FavResourceData {
    medias?: FavMedia[]
    has_more?: boolean
    info?: FavResourceInfo
    ttl?: number
}

/**
 * 收藏夹元信息（标题/数量/封面）。
 */
export interface FavResourceInfo {
    id?: number
    title?: string
    cover?: string
    media_count?: number
}

/**
 * 收藏的视频条目：attr 为时效标记（bit9=0x200 表示已失效），
 * 失效视频 bvid 为空且不可播放，前端置灰降级。
 */
export interface FavMedia {
    id?: number
    bvid?: string
    title?: string
    cover?: string
    intro?: string
    page?: number
    duration?: number
    upper?: FavUpper
    attr?: number
    fav_time?: number
    bv_id?: string
    cnt_info?: FavCntInfo
}

/**
 * 收藏视频的 UP 主信息。
 */
export interface FavUpper {
    mid?: number
    name?: string
    face?: string
}

/**
 * 收藏视频的计数信息（播放/弹幕/收藏）。
 */
export interface FavCntInfo {
    collect?: number
    play?: number
    danmaku?: number
}

/**
 * 判断收藏视频是否已失效（审核下架/UP 删除）：attr bit9 置位或 bvid 缺失。
 */
export function isFavMediaInvalid(item: FavMedia): boolean {
    if (item == null) {
        return true;
    }
    let attr: number = item.attr ?? 0;
    if ((attr & 0x200) != 0) {
        return true;
    }
    return item.bvid == null || item.bvid === '';
}

/**
 * 收藏夹内容请求结果：success 本次请求是否成功；
 * loginExpired 登录失效（业务码 -101）；
 * hasMore 是否还有下一页（服务端 has_more）。
 */
export class FavResourceResult {
    public success: boolean = false;
    public loginExpired: boolean = false;
    public hasMore: boolean = false;

    constructor(success: boolean, loginExpired: boolean, hasMore: boolean) {
        this.success = success;
        this.loginExpired = loginExpired;
        this.hasMore = hasMore;
    }
}
