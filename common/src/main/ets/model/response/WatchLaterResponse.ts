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
 * 稍后再看列表响应（GET x/v2/history/toview/web，Cookie 鉴权，全量单页返回）。
 */
export interface WatchLaterResponse extends BaseResponse<WatchLaterData> {

}

/**
 * 稍后再看数据：count 为条目总数，list 为视频列表（上限约 300 条）。
 */
export interface WatchLaterData {
    count?: number
    list?: WatchLaterItem[]
}

/**
 * 稍后再看条目：attr 为时效标记（bit9=0x200 表示已失效，置灰不可播放）。
 */
export interface WatchLaterItem {
    aid?: number
    bvid?: string
    cid?: number
    videos?: number
    tid?: number
    tname?: string
    pic?: string
    title?: string
    pubdate?: number
    ctime?: number
    desc?: string
    duration?: number
    owner?: WatchLaterOwner
    stat?: Record<string, number>
    add_dt?: number
    attr?: number
}

/**
 * 稍后再看条目的 UP 主信息。
 */
export interface WatchLaterOwner {
    mid?: number
    name?: string
    face?: string
}

/**
 * 判断稍后再看条目是否已失效：attr bit9 置位或 bvid 缺失。
 */
export function isWatchLaterItemInvalid(item: WatchLaterItem): boolean {
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
 * 稍后再看请求结果：success 本次请求是否成功；
 * loginExpired 登录失效（业务码 -101）。
 */
export class WatchLaterResult {
    public success: boolean = false;
    public loginExpired: boolean = false;

    constructor(success: boolean, loginExpired: boolean) {
        this.success = success;
        this.loginExpired = loginExpired;
    }
}
