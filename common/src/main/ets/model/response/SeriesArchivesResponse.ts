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
 * 投稿列表降级响应（x/series/recArchivesByKeywords，arc/search 风控时使用）
 */
export interface SeriesArchivesResponse extends BaseResponse<SeriesArchivesData> {
}

export interface SeriesArchivesData {
  archives?: SeriesArchiveItem[];
  page?: SeriesPage;
}

export interface SeriesPage {
  num?: number;
  size?: number;
  total?: number;
}

export interface SeriesArchiveItem {
  aid?: number;
  bvid: string;
  title?: string;
  pic?: string;
  /** 时长（秒） */
  duration?: number;
  /** 发布时间戳（秒） */
  pubdate?: number;
  sta?: SeriesStat;
  owner?: SeriesOwner;
}

export interface SeriesStat {
  view?: number;
  danmaku?: number;
}

export interface SeriesOwner {
  mid?: number;
  name?: string;
  face?: string;
}
