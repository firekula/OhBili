import { BaseResponse } from './Response';

/**
 * x/relation/stat 粉丝/关注数响应（公开接口，无需登录）
 */
export interface RelationStatResponse extends BaseResponse<RelationStatData> {};

export interface RelationStatData {
  mid: number;
  /** 关注数 */
  following: number;
  /** 悄悄关注数 */
  whisper: number;
  /** 黑名单数 */
  black: number;
  /** 粉丝数 */
  follower: number;
}
