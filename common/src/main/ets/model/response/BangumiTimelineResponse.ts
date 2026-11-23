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
 * 新番时间表（pgc/web/timeline?types=1&before=3&after=7）
 * payload 在 result 字段（天数组），字段全部可选防御式定义
 */
export interface BangumiTimelineResponse {
    code: number
    message?: string
    result?: BangumiTimelineDay[]
}

export interface BangumiTimelineDay {
    date?: string
    date_ts?: number
    day_of_week?: number
    is_today?: boolean
    episodes?: BangumiTimelineEpisode[]
}

export interface BangumiTimelineEpisode {
    season_id?: number
    episode_id?: number
    cover?: string
    title?: string
    index?: string
    index_title?: string
    pub_ts?: number
    delay?: boolean
}
