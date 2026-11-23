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
 * 我的追番列表（x/space/bangumi/follow/list?vmid=&type=1&pn=&ps=30）
 * payload 在 data 字段，字段全部可选防御式定义
 */
export interface MyFollowBangumiResponse {
    code: number
    message?: string
    data?: MyFollowBangumiData
}

export interface MyFollowBangumiData {
    total?: number
    pn?: number
    ps?: number
    list?: FollowBangumiItem[]
}

export interface FollowBangumiItem {
    season_id?: number
    media_id?: number
    title?: string
    cover?: string
    progress?: string
    follow_status?: number
    season_type?: number
    new_ep?: FollowNewEp
}

export interface FollowNewEp {
    id?: number
    index_show?: string
    title?: string
}
