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
 * 番剧详情（pgc/view/web/season?season_id= 或 ep_id=）
 * payload 在 result 字段，字段全部可选防御式定义
 */
export interface BangumiSeasonResponse {
    code: number
    message?: string
    result?: BangumiSeason
}

export interface BangumiSeason {
    season_id?: number
    media_id?: number
    title?: string
    cover?: string
    evaluate?: string
    rating?: BangumiRating
    episodes?: BangumiEpisode[]
    sections?: BangumiSection[]
    seasons?: BangumiSeasonBrief[]
    stat?: BangumiSeasonStat
    user_status?: BangumiUserStatus
}

export interface BangumiRating {
    score?: number
    count?: number
}

export interface BangumiEpisode {
    ep_id?: number
    aid?: number
    cid?: number
    cover?: string
    index?: string
    index_title?: string
    long_title?: string
    status?: number
    badge?: string
    badge_type?: number
}

export interface BangumiSection {
    section_id?: number
    title?: string
    episodes?: BangumiEpisode[]
}

export interface BangumiSeasonBrief {
    season_id?: number
    season_title?: string
}

export interface BangumiSeasonStat {
    views?: number
    follow?: number
    danmus?: number
}

export interface BangumiUserStatus {
    follow?: number
}
