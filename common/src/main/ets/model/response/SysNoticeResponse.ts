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
 * 系统通知（message.bilibili.com/x/sys-msg/query_notify_list）
 * 字段全部可选防御式定义（BiliPai 端点，实测 JSON 后修正）
 */
export interface SysNoticeResponse {
    code?: number
    message?: string
    data?: SysNoticeData
}

export interface SysNoticeData {
    notify_list?: SysNoticeItem[]
}

export interface SysNoticeItem {
    id?: string
    title?: string
    content?: string
    cover?: string
    link?: string
    time?: number
    type?: number
}
