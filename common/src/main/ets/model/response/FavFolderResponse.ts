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
 * 收藏夹列表响应（GET x/v3/fav/folder/created/list-all，Cookie 鉴权）。
 * 携带 rid（视频 aid）时列表内每夹带 fav_state 标记该视频是否已收藏。
 */
export interface FavFolderResponse extends BaseResponse<FavFolderData> {

}

/**
 * 收藏夹列表数据：count 为收藏夹总数，list 为收藏夹列表。
 */
export interface FavFolderData {
    count?: number
    list?: FavFolder[]
}

/**
 * 收藏夹：id 与 media_id 同值（B 站特性），media_count 为夹内视频数，
 * fav_state 表示当前视频（请求携带 rid 时）是否已收藏于该夹。
 */
export interface FavFolder {
    id?: number
    fid?: number
    mid?: number
    title?: string
    media_count?: number
    fav_state?: number
    attr?: number
}
