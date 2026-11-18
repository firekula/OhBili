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
 * 历史记录列表响应（GET x/web-interface/history/cursor，Cookie 鉴权）。
 * data 为游标分页结构：list 为本页历史条目，cursor 为下一页游标
 * （服务端返回，值等于本页末条的 view_at 与 history.business，
 * 客户端亦可由末条直接推导）。
 */
export interface HistoryResponse extends BaseResponse<HistoryCursorData> {

}

/**
 * 历史记录游标分页数据：list 本页条目数组；cursor 下一页游标。
 */
export interface HistoryCursorData {
    list?: HistoryItem[]
    cursor?: HistoryCursor
}

/**
 * 下一页游标：max/view_at 同值（末条 view_at），business 为末条业务类型。
 */
export interface HistoryCursor {
    max?: number
    view_at?: number
    business?: string
}

/**
 * 历史条目（普通视频/番剧/影视/直播回放等统一结构）：
 * 普通视频的 bvid/cid 在 history 子对象内；非视频类型（番剧/影视等）
 * 以 badge 标注且 history.bvid 缺失，前端据此降级为不可点击条目。
 */
export interface HistoryItem {
    title?: string
    cover?: string
    covers?: string[]
    uri?: string
    history?: HistoryEntry
    videos?: number
    author_name?: string
    author_face?: string
    author_mid?: string
    view_at?: number
    progress?: number
    duration?: number
    badge?: string
    show_title?: string
    current?: string
    total?: number
    new_desc?: string
    is_finish?: number
    is_fav?: number
    kid?: number
    tag_name?: string
    live_status?: number
    /** 顶层冗余字段：普通视频部分响应含 aid/bvid/cid，权威取值在 history 子对象 */
    aid?: number
    bvid?: string
    cid?: number
}

/**
 * 历史条目内的观看记录子对象：普通视频含实际 bvid/cid，
 * business 为业务类型（archive=普通视频，pgc=番剧影视等）。
 */
export interface HistoryEntry {
    oid?: number
    epid?: number
    bvid?: string
    page?: number
    cid?: number
    part?: string
    business?: string
    dt?: number
}

/**
 * 判断历史条目是否为可播放的普通视频：
 * business=archive 且 history.bvid 非空。
 */
export function isPlayableHistoryItem(item: HistoryItem): boolean {
    if (item == null || item.history == null) {
        return false;
    }
    let entry: HistoryEntry = item.history;
    if (entry.bvid == null || entry.bvid === '') {
        return false;
    }
    if (entry.business != null && entry.business !== 'archive') {
        return false;
    }
    return true;
}

/**
 * 历史记录请求结果：success 本次请求是否成功；
 * loginExpired 登录失效（业务码 -101，页面引导重新登录）；
 * hasMore 是否还有下一页（本页条数达到 ps）。
 */
export class HistoryResult {
    public success: boolean = false;
    public loginExpired: boolean = false;
    public hasMore: boolean = false;

    constructor(success: boolean, loginExpired: boolean, hasMore: boolean) {
        this.success = success;
        this.loginExpired = loginExpired;
        this.hasMore = hasMore;
    }
}
