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
 * @我的消息（x/msgfeed/at）
 * 字段全部可选防御式定义（BiliPai 端点，实测 JSON 后修正）
 */
export interface MsgFeedAtResponse {
    code?: number
    message?: string
    data?: MsgFeedAtData
}

export interface MsgFeedAtData {
    cursor?: MsgFeedCursor
    items?: MsgFeedAtItem[]
}

export interface MsgFeedAtItem {
    id?: number
    user?: MsgFeedUser
    item?: MsgFeedAtItemDetail
}

export interface MsgFeedAtItemDetail {
    content?: string
    target_id?: string
    at_time?: number
    type?: string
    uri?: string
}
