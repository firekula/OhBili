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
}
