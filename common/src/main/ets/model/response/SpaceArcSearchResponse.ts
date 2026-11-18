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
 * 投稿列表响应（x/space/wbi/arc/search）
 */
export interface SpaceArcSearchResponse extends BaseResponse<SpaceArcData> {
}

export interface SpaceArcData {
  list?: SpaceArcList;
  page?: SpaceArcPage;
}

export interface SpaceArcList {
  vlist?: SpaceArcItem[];
}

export interface SpaceArcPage {
  pn?: number;
  ps?: number;
  count?: number;
}

export interface SpaceArcItem {
  bvid: string;
  title?: string;
  pic?: string;
  /** 发布时间戳（秒） */
  created?: number;
  /** 形如 "mm:ss" 的时长文本 */
  length?: string;
  play?: number;
  author?: string;
  description?: string;
}

/**
 * 投稿列表请求结果（ApiManager.requestSpaceArchives 返回值）
 */
export class SpaceArcResult {
  success: boolean = false;
  hasMore: boolean = false;

  constructor(success: boolean, hasMore: boolean) {
    this.success = success;
    this.hasMore = hasMore;
  }
}
