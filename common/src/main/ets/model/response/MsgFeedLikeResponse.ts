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

import { MsgFeedCursor, MsgFeedUser } from './MsgFeedReplyResponse';

/**
 * 收到的赞消息（x/msgfeed/like）
 * 字段全部可选防御式定义（BiliPai 端点，实测 JSON 后修正）
 */
export interface MsgFeedLikeResponse {
    code?: number
    message?: string
    data?: MsgFeedLikeData
}

export interface MsgFeedLikeData {
    total_count?: number
    cursor?: MsgFeedCursor
    items?: MsgFeedLikeItem[]
}

export interface MsgFeedLikeItem {
    id?: number
    user?: MsgFeedUser
    item?: MsgFeedLikeItemDetail
}

export interface MsgFeedLikeItemDetail {
    title?: string
    target_id?: string
    type?: string
    like_time?: number
}
