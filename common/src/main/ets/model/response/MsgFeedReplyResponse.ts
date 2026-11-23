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

/**
 * 回复我的消息（x/msgfeed/reply）
 * 字段全部可选防御式定义（BiliPai 端点，实测 JSON 后修正）
 */
export interface MsgFeedReplyResponse {
    code?: number
    message?: string
    data?: MsgFeedReplyData
}

export interface MsgFeedReplyData {
    cursor?: MsgFeedCursor
    items?: MsgFeedReplyItem[]
}

/** 消息流游标（reply/at/like 通用） */
export interface MsgFeedCursor {
    id?: number
    time?: number
    is_end?: boolean
}

/** 消息流用户（reply/at/like 通用） */
export interface MsgFeedUser {
    mid?: string
    nickname?: string
    avatar?: string
    fans?: number
}

export interface MsgFeedReplyItem {
    id?: number
    user?: MsgFeedUser
    item?: MsgFeedReplyItemDetail
}

export interface MsgFeedReplyItemDetail {
    topic_id?: string
    root_id?: string
    target_id?: string
    source_content?: string
    reply?: string
    type?: string
}
