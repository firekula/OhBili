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

export interface ReplyResponse extends BaseResponse<Reply> {

}

export interface Reply {
    cursor: ReplyCursor
    replies?: ReplyItem[]
}

export interface ReplyCursor {
    is_begin: boolean
    prev: number
    next: number
    is_end: boolean
    mode: number
    mode_text: string
    all_count: number
}

export interface ReplyItem {
    rpid: number
    mid: number
    count: number
    rcount: number
    like: number
    /** 当前用户对该评论的态度：0=无 1=已赞 2=已踩 */
    action?: number
    ctime: number
    member: ReplyItemMember
    content: MemberContent
    replies?: ReplyItem[]
    /** 评论区控制信息（IP 属地等） */
    reply_control?: ReplyControl
}

/** 评论控制信息 */
export interface ReplyControl {
    /** IP 属地（如"广东"），无则为空 */
    location?: string
}

export interface ReplyItemMember {
    uname: string
    mid: string
    avatar: string
    level_info: MemberLevel
    vip: MemberVip
}

export interface MemberLevel {
    current_level: number
}

export interface MemberVip {
    vipType: number
    vipStatus: number
}

export interface MemberContent {
    message: string
    max_line: number
    /** 表情映射：key 为 "[表情名]"，value 含表情图 URL */
    emote?: Record<string, ReplyEmote>
}

/** 评论内嵌表情（[doge] 等） */
export interface ReplyEmote {
    url: string
    /** 尺寸：1=小 2=大 */
    size?: number
    /** 表情名（部分接口返回） */
    text?: string
    width?: number
    height?: number
}