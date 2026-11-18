import {BaseResponse} from './Response';

export interface CardInfoResponse extends BaseResponse<CardInfo> {};

export interface CardInfo {
  following: boolean;
  archive_count: number;
  article_count: number;
  follower: number;
  likeNum: number;
  /** 用户卡片详情（昵称/头像/签名/等级等，acc/info 失败时兜底） */
  card?: UserCardInfo;
}

export interface UserCardInfo {
  mid?: number;
  name?: string;
  face?: string;
  sign?: string;
  /** 粉丝数 */
  fans?: number;
  /** 关注数 */
  friend?: number;
  /** 是否关注 TA */
  attention?: number;
  level_info?: UserLevelInfo;
}

export interface UserLevelInfo {
  current_level?: number;
}
