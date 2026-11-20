import {BaseResponse} from './Response';

export interface NavResponse extends BaseResponse<NavData> {};

export interface WbiImg {
  img_url: string;
  sub_url: string;
}

export interface NavData {
  isLogin: boolean;
  mid: number;
  uname: string;
  face: string;
  wbi_img?: WbiImg;
  /** 大会员状态：0 非大会员，1 大会员（清晰度档位解锁用） */
  vipStatus?: number;
  /** 会员类型：0 无，1 月度大会员，2 年度及以上大会员 */
  vipType?: number;
}
