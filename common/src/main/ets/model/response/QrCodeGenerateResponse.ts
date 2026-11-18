import {BaseResponse} from './Response';

export interface QrCodeGenerateResponse extends BaseResponse<QrCodeData> {};

export interface QrCodeData {
  url: string;
  qrcode_key: string;
}
