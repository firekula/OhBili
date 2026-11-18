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
 * 空间用户资料响应（x/space/wbi/acc/info）
 */
export interface SpaceAccInfoResponse extends BaseResponse<SpaceAccInfo> {
}

export interface SpaceAccInfo {
  mid: number;
  name?: string;
  face?: string;
  sign?: string;
  level?: number;
  official?: SpaceOfficial;
}

export interface SpaceOfficial {
  role?: number;
  title?: string;
}

/**
 * 空间页聚合资料模型（ApiManager.requestSpaceInfo 组装）：
 * acc/info 提供资料（profileLoaded=true），失败时以 card 接口字段兜底（profileLoaded=false，签名/等级用占位）
 */
export class SpaceUserProfile {
  mid: number;
  name: string;
  face: string;
  sign: string;
  level: number;
  /** 关注数 */
  following: number;
  /** 粉丝数 */
  follower: number;
  /** 获赞数 */
  likeNum: number;
  /** 投稿数 */
  archiveCount: number;
  /** acc/info 是否成功（失败时签名/等级用占位） */
  profileLoaded: boolean;

  constructor(mid: number) {
    this.mid = mid;
    this.name = '';
    this.face = '';
    this.sign = '';
    this.level = 0;
    this.following = 0;
    this.follower = 0;
    this.likeNum = 0;
    this.archiveCount = 0;
    this.profileLoaded = false;
  }
}
