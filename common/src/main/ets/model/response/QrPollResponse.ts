import {BaseResponse} from './Response';

export interface QrPollResponse extends BaseResponse<QrPollData> {};

export interface QrPollData {
  url: string;
  refresh_token: string;
  timestamp: number;
  code: number;
  message: string;
}
