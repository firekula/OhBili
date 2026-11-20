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

import util from '@ohos.util';
import { ApiManager } from '../network/ApiManager';
import { BLog } from './BLog';

/**
 * B站扫码登录凭证与设备 Cookie 辅助类。
 * 登录凭证通过 AppStorage 持久化（键由 Splash.ets 的 PersistentStorage.PersistProp 声明）：
 * isOhBiliLoggedIn / ohBiliSessdata / ohBiliBiliJct / ohBiliDedeUserId /
 * ohBiliRefreshToken / ohBiliUname / ohBiliFace
 * 设备 Cookie（对齐网页版）：
 * ohBiliBuvid3 / ohBiliBuvid4（经指纹接口 x/frontend/finger/spi 获取）
 */
export class LoginHelper {
  private static readonly KEY_LOGGED_IN: string = 'isOhBiliLoggedIn';
  private static readonly KEY_SESSDATA: string = 'ohBiliSessdata';
  private static readonly KEY_BILI_JCT: string = 'ohBiliBiliJct';
  private static readonly KEY_DEDE_USER_ID: string = 'ohBiliDedeUserId';
  private static readonly KEY_REFRESH_TOKEN: string = 'ohBiliRefreshToken';
  private static readonly KEY_UNAME: string = 'ohBiliUname';
  private static readonly KEY_FACE: string = 'ohBiliFace';
  private static readonly KEY_BUVID3: string = 'ohBiliBuvid3';
  private static readonly KEY_BUVID4: string = 'ohBiliBuvid4';
  private static readonly KEY_VIP_STATUS: string = 'ohBiliVipStatus';

  /**
   * 从轮询成功返回的 crossDomain URL 中解析 query 参数（SESSDATA/bili_jct/DedeUserID 等）。
   * 非法输入返回空 Record。
   */
  static parseCrossDomainCookies(url: string): Record<string, string> {
    let result: Record<string, string> = {};
    if (url == null || url === '') {
      return result;
    }
    let queryPart: string = url;
    let queryIndex: number = url.indexOf('?');
    if (queryIndex >= 0) {
      queryPart = url.substring(queryIndex + 1);
    }
    let hashIndex: number = queryPart.indexOf('#');
    if (hashIndex >= 0) {
      queryPart = queryPart.substring(0, hashIndex);
    }
    let pairs: string[] = queryPart.split('&');
    for (let i = 0; i < pairs.length; i++) {
      let pair: string = pairs[i];
      if (pair === '') {
        continue;
      }
      let eqIndex: number = pair.indexOf('=');
      if (eqIndex <= 0) {
        continue;
      }
      let key: string = pair.substring(0, eqIndex);
      let value: string = pair.substring(eqIndex + 1);
      // Cookie 值保持 URL 编码原样存取（浏览器语义：Set-Cookie 原样存储、原样回传）。
      // SESSDATA 含编码逗号（%2C），若 decodeURIComponent 解码后再拼 Cookie 头回传，
      // 服务器比对不一致会判定未登录（isLogin=false），导致凭证被误清。故不做解码。
      if (key !== '') {
        result[key] = value;
      }
    }
    return result;
  }

  /**
   * 组装 Cookie 请求头（对齐网页版）：设备 Cookie（buvid3/buvid4，空值跳过）
   * + 已登录时叠加登录 Cookie（SESSDATA/bili_jct/DedeUserID）。全部为空返回空串。
   */
  static buildCookieHeader(): string {
    let parts: string[] = [];
    let buvid3: string = AppStorage.get<string>(LoginHelper.KEY_BUVID3) ?? '';
    let buvid4: string = AppStorage.get<string>(LoginHelper.KEY_BUVID4) ?? '';
    if (buvid3 !== '') {
      parts.push(`buvid3=${buvid3}`);
    }
    if (buvid4 !== '') {
      parts.push(`buvid4=${buvid4}`);
    }
    LoginHelper.appendLoginCookies(parts);
    return parts.join('; ');
  }

  /**
   * 组装仅含登录凭证的 Cookie 请求头（不含设备 buvid），用于搜索等 gaia 风控敏感接口：
   * 实测经 finger/spi 新铸的 buvid3 缺乏真实浏览历史，随搜索请求发送会触发
   * v_voucher 风控（返回无结果）；不带 buvid 的匿名/登录搜索均正常放行。
   * 未登录返回空串（空 Cookie 头等价匿名请求，风控放行）。
   */
  static buildLoginCookieHeader(): string {
    let parts: string[] = [];
    LoginHelper.appendLoginCookies(parts);
    return parts.join('; ');
  }

  private static appendLoginCookies(parts: string[]): void {
    let loggedIn: boolean = AppStorage.get<boolean>(LoginHelper.KEY_LOGGED_IN) ?? false;
    if (!loggedIn) {
      return;
    }
    let sessdata: string = AppStorage.get<string>(LoginHelper.KEY_SESSDATA) ?? '';
    let biliJct: string = AppStorage.get<string>(LoginHelper.KEY_BILI_JCT) ?? '';
    let dedeUserId: string = AppStorage.get<string>(LoginHelper.KEY_DEDE_USER_ID) ?? '';
    parts.push(`SESSDATA=${sessdata}`);
    parts.push(`bili_jct=${biliJct}`);
    parts.push(`DedeUserID=${dedeUserId}`);
  }

  /**
   * 确保设备 Cookie（buvid3/buvid4）就绪：
   * 键为空时经官方指纹接口（x/frontend/finger/spi）获取并持久化写入；
   * 获取失败使用本地随机 UUID 兜底（buvid3 形态对齐官方：UUID+infoc），并告警。
   */
  static async ensureDeviceCookies(): Promise<void> {
    let buvid3: string = AppStorage.get<string>(LoginHelper.KEY_BUVID3) ?? '';
    let buvid4: string = AppStorage.get<string>(LoginHelper.KEY_BUVID4) ?? '';
    if (buvid3 !== '' && buvid4 !== '') {
      return;
    }
    let fetchedB3: string = '';
    let fetchedB4: string = '';
    try {
      let spiResp = await ApiManager.getInstance().requestFingerSpi();
      if (spiResp != null && spiResp.data != null) {
        fetchedB3 = spiResp.data.b_3 ?? '';
        fetchedB4 = spiResp.data.b_4 ?? '';
      }
    } catch (err) {
      BLog.e("ensureDeviceCookies err=" + err);
    }
    if (buvid3 === '' && fetchedB3 !== '') {
      AppStorage.setOrCreate(LoginHelper.KEY_BUVID3, fetchedB3);
      buvid3 = fetchedB3;
    }
    if (buvid4 === '' && fetchedB4 !== '') {
      AppStorage.setOrCreate(LoginHelper.KEY_BUVID4, fetchedB4);
      buvid4 = fetchedB4;
    }
    if (buvid3 !== '' && buvid4 !== '') {
      BLog.i("ensureDeviceCookies ok");
      return;
    }
    // 指纹接口失败或字段缺失：本地随机值兜底，功能不中断
    BLog.w("ensureDeviceCookies fallback to random buvid");
    if (buvid3 === '') {
      AppStorage.setOrCreate(LoginHelper.KEY_BUVID3, util.generateRandomUUID().toUpperCase() + 'infoc');
    }
    if (buvid4 === '') {
      AppStorage.setOrCreate(LoginHelper.KEY_BUVID4, util.generateRandomUUID());
    }
  }

  /**
   * ticket 型 crossDomain URL 换取登录 Cookie：
   * B站 2024 起扫码轮询成功返回的 url 仅含 ticket（无 SESSDATA 参数），
   * 需以浏览器上下文（UA + 设备 Cookie）GET 该 url，从 302 响应的
   * Set-Cookie 中提取登录 Cookie。失败返回空 Record。
   */
  static async exchangeCrossDomainCookies(url: string): Promise<Record<string, string>> {
    // 兑换时未登录，buildCookieHeader 仅含设备 Cookie（buvid3/buvid4）
    let cookie: string = LoginHelper.buildCookieHeader();
    try {
      let result = await ApiManager.getInstance().exchangeCrossDomainTicket(url, cookie);
      if (result != null && result.cookieParams != null
        && result.cookieParams['SESSDATA'] != null && result.cookieParams['SESSDATA'] !== '') {
        BLog.i("exchangeCrossDomainCookies ok, keys=" + JSON.stringify(result.cookieParams));
        return result.cookieParams;
      }
      BLog.w("exchangeCrossDomainCookies no SESSDATA, code=" + (result == null ? -1 : result.responseCode));
    } catch (err) {
      BLog.e("exchangeCrossDomainCookies err=" + err);
    }
    return {};
  }

  /**
   * 保存扫码登录凭证（来自 crossDomain query 参数）与刷新令牌，并置登录态为 true。
   */
  static saveLoginCredentials(params: Record<string, string>, refreshToken: string): void {
    let sessdata: string = params['SESSDATA'] ?? '';
    let biliJct: string = params['bili_jct'] ?? '';
    let dedeUserId: string = params['DedeUserID'] ?? '';
    AppStorage.setOrCreate(LoginHelper.KEY_SESSDATA, sessdata);
    AppStorage.setOrCreate(LoginHelper.KEY_BILI_JCT, biliJct);
    AppStorage.setOrCreate(LoginHelper.KEY_DEDE_USER_ID, dedeUserId);
    AppStorage.setOrCreate(LoginHelper.KEY_REFRESH_TOKEN, refreshToken ?? '');
    AppStorage.setOrCreate(LoginHelper.KEY_LOGGED_IN, true);
  }

  /**
   * 清空全部登录相关键。
   */
  static clearLoginCredentials(): void {
    AppStorage.setOrCreate(LoginHelper.KEY_LOGGED_IN, false);
    AppStorage.setOrCreate(LoginHelper.KEY_SESSDATA, '');
    AppStorage.setOrCreate(LoginHelper.KEY_BILI_JCT, '');
    AppStorage.setOrCreate(LoginHelper.KEY_DEDE_USER_ID, '');
    AppStorage.setOrCreate(LoginHelper.KEY_REFRESH_TOKEN, '');
    AppStorage.setOrCreate(LoginHelper.KEY_UNAME, '');
    AppStorage.setOrCreate(LoginHelper.KEY_FACE, '');
    AppStorage.setOrCreate(LoginHelper.KEY_VIP_STATUS, 0);
  }

  /**
   * 用已存储凭证调用户导航接口校验登录态：
   * isLogin 为真则刷新昵称/头像缓存键并返回 true；
   * 服务器明确判定 isLogin=false 时清凭证返回 false；
   * 请求失败（网络异常等）保留凭证返回 false，待下次启动重试，避免误清登录态。
   */
  static async validateAndRestoreLoginState(): Promise<boolean> {
    // buildCookieHeader 现包含设备 Cookie（未登录非空），需按登录标志早退
    let loggedIn: boolean = AppStorage.get<boolean>(LoginHelper.KEY_LOGGED_IN) ?? false;
    if (!loggedIn) {
      return false;
    }
    let cookie: string = LoginHelper.buildCookieHeader();
    try {
      let navData = await ApiManager.getInstance().requestNavInfo(cookie);
      if (navData != null && navData.isLogin) {
        AppStorage.setOrCreate(LoginHelper.KEY_UNAME, navData.uname ?? '');
        AppStorage.setOrCreate(LoginHelper.KEY_FACE, navData.face ?? '');
        AppStorage.setOrCreate(LoginHelper.KEY_VIP_STATUS, navData.vipStatus ?? 0);
        AppStorage.setOrCreate(LoginHelper.KEY_LOGGED_IN, true);
        return true;
      }
      if (navData != null && !navData.isLogin) {
        // 服务器明确判定凭证无效，清空登录态
        LoginHelper.clearLoginCredentials();
        return false;
      }
      // navData 为 null：请求失败，保留凭证待下次校验
      BLog.w("validateAndRestoreLoginState nav unavailable, keep credentials");
      return false;
    } catch (err) {
      // 网络异常不清凭证，保留待下次校验
      BLog.e("validateAndRestoreLoginState err=" + err);
      return false;
    }
  }
}
