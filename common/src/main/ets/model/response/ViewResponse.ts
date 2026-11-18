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

import { BaseResponse, Owner, Stat } from './Response';

/**
 * 视频详情响应（GET x/web-interface/view，网页版视频页主接口）。
 * 端点勘误：旧 x/web-interface/archive/stat 已下线（浏览器 UA 亦 404），
 * aid/cid/互动数据（Stat）统一改经本接口获取；匿名可访问（无需 WBI 签名与登录 Cookie），
 * 但必须携带浏览器 User-Agent，否则 HTTP 412 风控拦截。
 */
export interface ViewResponse extends BaseResponse<ViewData> {

}

/**
 * 视频详情数据：aid/cid/标题/封面/简介/UP 主/互动数据。
 */
export interface ViewData {
    aid?: number
    bvid?: string
    cid?: number
    videos?: number
    tid?: number
    title?: string
    pic?: string
    desc?: string
    duration?: number
    pubdate?: number
    owner?: Owner
    stat?: Stat
}
