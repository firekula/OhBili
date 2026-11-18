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

import { ApiManager, LoginHelper, OhNavBar, QrPollData, QrPollResponse } from '@ohos/common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import image from '@ohos.multimedia.image';
import { BarcodeFormat, BitMatrix, MultiFormatWriter } from '@ohos/zxing';

/** 二维码卡片尺寸（vp） */
const QR_CARD_SIZE: number = 240;
/** 二维码位图生成尺寸（px），大于卡片尺寸保证清晰度 */
const QR_BITMAP_SIZE: number = 480;
/** 扫码状态轮询间隔（ms） */
const POLL_INTERVAL_MS: number = 3000;
/** 连续轮询失败达到该次数后暂停轮询 */
const MAX_POLL_ERROR_COUNT: number = 3;

/** 轮询顶层业务码 */
const QR_CODE_SUCCESS: number = 0;
const QR_CODE_WAITING: number = 86101;
const QR_CODE_SCANNED: number = 86090;
const QR_CODE_EXPIRED: number = 86038;

/** 页面状态：loading 生成中 / waiting 等待扫码 / scanned 已扫码 / expired 已过期 / success 登录成功 / failed 生成失败 */
const STATE_LOADING: string = 'loading';
const STATE_WAITING: string = 'waiting';
const STATE_SCANNED: string = 'scanned';
const STATE_EXPIRED: string = 'expired';
const STATE_SUCCESS: string = 'success';
const STATE_FAILED: string = 'failed';

@Entry
@Component
struct Login {
  @State pageState: string = STATE_LOADING;
  @State statusText: string = '请使用B站App扫码登录';
  @State qrPixelMap: image.PixelMap | undefined = undefined;
  private qrcodeKey: string = '';
  private pollTimer: number = -1;
  private pollErrorCount: number = 0;
  private pollPaused: boolean = false;
  private isPageActive: boolean = true;
  private isGenerating: boolean = false;

  aboutToAppear() {
    this.isPageActive = true;
    this.generateAndShowQrCode();
  }

  aboutToDisappear() {
    this.isPageActive = false;
    this.stopPolling();
  }

  private async generateAndShowQrCode(): Promise<void> {
    if (this.isGenerating) {
      return;
    }
    this.isGenerating = true;
    this.stopPolling();
    this.pageState = STATE_LOADING;
    this.statusText = '请使用B站App扫码登录';
    try {
      let qrCodeData = await ApiManager.getInstance().requestQrCode();
      if (!this.isPageActive) {
        return;
      }
      if (qrCodeData == null || qrCodeData.url == null || qrCodeData.url === ''
        || qrCodeData.qrcode_key == null || qrCodeData.qrcode_key === '') {
        this.handleQrLoadFailed();
        return;
      }
      this.qrcodeKey = qrCodeData.qrcode_key;
      let pixelMap: image.PixelMap = await this.createQrPixelMap(qrCodeData.url);
      if (!this.isPageActive) {
        return;
      }
      this.qrPixelMap = pixelMap;
      this.pageState = STATE_WAITING;
      this.startPolling();
    } catch (err) {
      if (this.isPageActive) {
        this.handleQrLoadFailed();
      }
    } finally {
      this.isGenerating = false;
    }
  }

  private handleQrLoadFailed(): void {
    this.pageState = STATE_FAILED;
    this.statusText = '网络异常，请重试';
    promptAction.showToast({
      message: '网络异常，请重试',
      duration: 2000
    });
  }

  private startPolling(): void {
    this.stopPolling();
    this.pollErrorCount = 0;
    this.pollPaused = false;
    this.pollTimer = setInterval(() => {
      this.pollQrStatusOnce();
    }, POLL_INTERVAL_MS);
  }

  private stopPolling(): void {
    if (this.pollTimer > 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async pollQrStatusOnce(): Promise<void> {
    if (this.pollPaused || this.pageState === STATE_SUCCESS) {
      return;
    }
    let response: QrPollResponse = await ApiManager.getInstance().pollQrStatus(this.qrcodeKey);
    if (!this.isPageActive) {
      return;
    }
    // 外层 code 为传输层状态码（恒为 0 表示请求成功），业务码在 data.code 中
    if (response == null || response.code == null || response.code !== QR_CODE_SUCCESS) {
      this.handlePollError();
      return;
    }
    let data: QrPollData = response.data;
    if (data == null || data.code == null) {
      this.handlePollError();
      return;
    }
    this.pollErrorCount = 0;
    if (data.code === QR_CODE_WAITING) {
      this.pageState = STATE_WAITING;
      this.statusText = '请使用B站App扫码登录';
    } else if (data.code === QR_CODE_SCANNED) {
      this.pageState = STATE_SCANNED;
      this.statusText = '已扫码，请在手机上确认';
    } else if (data.code === QR_CODE_EXPIRED) {
      this.stopPolling();
      this.pageState = STATE_EXPIRED;
      this.statusText = '二维码已过期，点击刷新';
    } else if (data.code === QR_CODE_SUCCESS) {
      this.handleLoginSuccess(response);
    }
  }

  private handlePollError(): void {
    this.pollErrorCount++;
    if (this.pollErrorCount >= MAX_POLL_ERROR_COUNT) {
      this.pollPaused = true;
      this.statusText = '网络异常，点击二维码重试';
      promptAction.showToast({
        message: '网络异常，轮询已暂停',
        duration: 2000
      });
    }
  }

  private async handleLoginSuccess(response: QrPollResponse): Promise<void> {
    this.stopPolling();
    this.pageState = STATE_SUCCESS;
    let data: QrPollData = response.data;
    if (data == null || data.url == null || data.url === '') {
      this.statusText = '登录数据异常，请刷新重试';
      promptAction.showToast({
        message: '登录数据异常',
        duration: 2000
      });
      return;
    }
    let cookieParams: Record<string, string> = LoginHelper.parseCrossDomainCookies(data.url);
    let refreshToken: string = data.refresh_token != null ? data.refresh_token : '';
    // B站 2024 改版：轮询成功返回的 url 仅含 ticket（无 SESSDATA 参数），
    // 需 GET crossDomain URL 以 302 的 Set-Cookie 兑换登录 Cookie
    if (cookieParams['SESSDATA'] == null || cookieParams['SESSDATA'] === '') {
      this.statusText = '正在获取登录凭证...';
      let exchanged: Record<string, string> = await LoginHelper.exchangeCrossDomainCookies(data.url);
      if (exchanged['SESSDATA'] != null && exchanged['SESSDATA'] !== '') {
        cookieParams = exchanged;
      } else {
        // 兑换失败：不保存空凭证，停留本页提示重试（ticket 已消费，二维码需重新生成）
        this.statusText = '登录凭证获取失败，请刷新重试';
        promptAction.showToast({
          message: '登录凭证获取失败，请刷新重试',
          duration: 2000
        });
        return;
      }
    }
    LoginHelper.saveLoginCredentials(cookieParams, refreshToken);
    // 校验登录态并刷新昵称/头像缓存（异步，不阻塞返回）
    LoginHelper.validateAndRestoreLoginState();
    this.statusText = '登录成功';
    promptAction.showToast({
      message: '登录成功',
      duration: 1500
    });
    setTimeout(() => {
      if (this.isPageActive) {
        router.back();
      }
    }, 1500);
  }

  /**
   * 用 zxing 将登录 URL 编码为二维码并转换为 PixelMap（白底黑码，RGBA_8888）。
   */
  private async createQrPixelMap(content: string): Promise<image.PixelMap> {
    let writer: MultiFormatWriter = new MultiFormatWriter();
    let matrix: BitMatrix = writer.encode(content, BarcodeFormat.QR_CODE,
      QR_BITMAP_SIZE, QR_BITMAP_SIZE, null);
    let width: number = matrix.getWidth();
    let height: number = matrix.getHeight();
    let pixelBuffer: Uint8Array = new Uint8Array(width * height * 4);
    for (let y: number = 0; y < height; y++) {
      for (let x: number = 0; x < width; x++) {
        let offset: number = (y * width + x) * 4;
        if (matrix.get(x, y)) {
          pixelBuffer[offset] = 0;
          pixelBuffer[offset + 1] = 0;
          pixelBuffer[offset + 2] = 0;
          pixelBuffer[offset + 3] = 255;
        } else {
          pixelBuffer[offset] = 255;
          pixelBuffer[offset + 1] = 255;
          pixelBuffer[offset + 2] = 255;
          pixelBuffer[offset + 3] = 255;
        }
      }
    }
    let options: image.InitializationOptions = {
      size: { width: width, height: height },
      pixelFormat: image.PixelMapFormat.RGBA_8888
    };
    return await image.createPixelMap(pixelBuffer.buffer, options);
  }

  build() {
    Column() {
      OhNavBar({ title: '扫码登录' })

      Column() {
        if (this.pageState === STATE_LOADING || this.pageState === STATE_FAILED) {
          Column() {
            if (this.pageState === STATE_LOADING) {
              LoadingProgress().width(48).height(48)
              Text('二维码生成中...').fontSize(14).fontColor('#888888').margin({ top: 12 })
            } else {
              Text('二维码加载失败').fontSize(15).fontColor('#888888')
              Button('点击重试')
                .margin({ top: 16 })
                .onClick(() => {
                  this.generateAndShowQrCode();
                })
            }
          }
          .width(QR_CARD_SIZE)
          .height(QR_CARD_SIZE)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
        } else {
          Stack() {
            Column() {
              Image(this.qrPixelMap)
                .width(QR_CARD_SIZE)
                .height(QR_CARD_SIZE)
                .interpolation(ImageInterpolation.High)
            }
            .width(QR_CARD_SIZE)
            .height(QR_CARD_SIZE)
            .padding(12)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .onClick(() => {
              if (this.pollPaused) {
                this.startPolling();
                this.statusText = '请使用B站App扫码登录';
              }
            })

            if (this.pageState === STATE_EXPIRED) {
              Column() {
                Text('二维码已过期')
                  .fontSize(16)
                  .fontColor(Color.Black)
                  .fontWeight(FontWeight.Medium)
                Text('点击刷新')
                  .fontSize(14)
                  .fontColor('#666666')
                  .margin({ top: 8 })
              }
              .width(QR_CARD_SIZE)
              .height(QR_CARD_SIZE)
              .backgroundColor('rgba(255,255,255,0.92)')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.generateAndShowQrCode();
              })
            }
          }
        }

        Text(this.statusText)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 16 })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
