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

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import util from '@ohos.util';
import { TaskManager } from '../network/TaskManager';
import { LoginHelper } from './LoginHelper';
import { BLog } from './BLog';

/**
 * B站 Web 端 WBI 接口签名器。
 * 签名流程（与网页版一致）：
 * 1. nav 接口返回 wbi_img.img_url/sub_url，取 URL 末段文件名去扩展名得 img_key/sub_key
 * 2. (img_key + sub_key) 按 64 项置换表取字符拼接前 32 位得 mixinKey
 * 3. 参数加 wts（秒级时间戳）→ 值过滤 !'()* → 键 ASCII 排序 → encodeURIComponent 拼接 query
 * 4. w_rid = MD5(query + mixinKey) 十六进制小写
 * 密钥内存缓存；获取失败降级为不签名请求并告警，不阻塞主流程。
 */
const WBI_MIXIN_KEY_ENC_TAB: number[] = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50,
  10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
  33, 9, 42, 19, 29, 28, 14, 39, 12, 38,
  41, 13, 37, 48, 7, 16, 24, 55, 40, 61,
  26, 17, 0, 1, 60, 51, 30, 4, 22, 25,
  54, 21, 56, 59, 6, 63, 57, 62, 11, 36,
  20, 34, 44, 52
];

export class WbiSigner {
  /** 混合密钥内存缓存（进程级） */
  private static mixinKey: string = '';

  /**
   * 获取 WBI 签名密钥并缓存。
   * 经 nav 接口链路（TaskManager.requestNavInfo）提取 img_key/sub_key 生成 mixinKey。
   * @param forceRefresh 强制刷新缓存
   * @returns 成功返回 true；失败返回 false（调用方应降级为不签名请求）
   */
  static async getWbiKeys(forceRefresh: boolean): Promise<boolean> {
    if (!forceRefresh && WbiSigner.mixinKey !== '') {
      return true;
    }
    try {
      let cookie: string = LoginHelper.buildCookieHeader();
      let response = await TaskManager.getInstance().requestNavInfo(cookie);
      if (response.result != null && response.result.data != null &&
        response.result.data.wbi_img != null) {
        let wbiImg = response.result.data.wbi_img;
        let imgKey: string = WbiSigner.extractKeyFromUrl(wbiImg.img_url);
        let subKey: string = WbiSigner.extractKeyFromUrl(wbiImg.sub_url);
        let raw: string = imgKey + subKey;
        if (raw.length >= 64) {
          WbiSigner.mixinKey = WbiSigner.buildMixinKey(raw);
          BLog.d("WbiSigner keys ready, len=" + WbiSigner.mixinKey.length);
          return true;
        }
        BLog.w("WbiSigner raw key too short: " + raw.length);
      }
    } catch (err) {
      BLog.e("WbiSigner getWbiKeys err=" + err);
    }
    BLog.w("WbiSigner getWbiKeys failed, will degrade to unsigned request");
    return false;
  }

  /**
   * 对参数进行 WBI 签名。
   * @param params 待签名参数（键值均为字符串）
   * @returns 追加了 wts / w_rid 的参数副本；无密钥时降级返回原参数（不签名）并告警
   */
  static async signParams(params: Record<string, string>): Promise<Record<string, string>> {
    if (WbiSigner.mixinKey === '') {
      let ready: boolean = await WbiSigner.getWbiKeys(false);
      if (!ready) {
        BLog.w("WbiSigner signParams degrade: send request unsigned");
        return params;
      }
    }
    let wts: string = Math.floor(Date.now() / 1000).toString();
    let merged: Record<string, string> = {};
    let paramKeys: string[] = Object.keys(params);
    for (let i = 0; i < paramKeys.length; i++) {
      merged[paramKeys[i]] = params[paramKeys[i]];
    }
    merged['wts'] = wts;
    try {
      let sortedKeys: string[] = Object.keys(merged).sort();
      let queryItems: string[] = [];
      for (let i = 0; i < sortedKeys.length; i++) {
        let key: string = sortedKeys[i];
        queryItems.push(key + '=' + encodeURIComponent(WbiSigner.filterValue(merged[key])));
      }
      let wRid: string = await WbiSigner.md5Hex(queryItems.join('&') + WbiSigner.mixinKey);
      merged['w_rid'] = wRid;
    } catch (err) {
      // 摘要计算失败：降级为不签名请求（带 wts 无 w_rid），不阻塞主流程
      BLog.e("WbiSigner signParams err=" + err + ", degrade to unsigned request");
    }
    return merged;
  }

  /**
   * 从 wbi_img 图片 URL 提取密钥：取路径末段文件名并去掉扩展名。
   */
  private static extractKeyFromUrl(url: string): string {
    if (url == null || url === '') {
      return '';
    }
    let fileName: string = url.substring(url.lastIndexOf('/') + 1);
    let dotIndex: number = fileName.indexOf('.');
    if (dotIndex > 0) {
      fileName = fileName.substring(0, dotIndex);
    }
    return fileName;
  }

  /**
   * 按置换表从原始密钥串取字符拼接前 32 位混合密钥。
   */
  private static buildMixinKey(raw: string): string {
    let result: string = '';
    for (let i = 0; i < 32; i++) {
      result += raw.charAt(WBI_MIXIN_KEY_ENC_TAB[i]);
    }
    return result;
  }

  /**
   * 签名计算前过滤值中的特殊字符 ! ' ( ) *（与网页版一致）。
   */
  private static filterValue(value: string): string {
    let result: string = '';
    for (let i = 0; i < value.length; i++) {
      let ch: string = value.charAt(i);
      if (ch !== '!' && ch !== "'" && ch !== '(' && ch !== ')' && ch !== '*') {
        result += ch;
      }
    }
    return result;
  }

  /**
   * MD5 摘要，返回十六进制小写字符串（@kit.CryptoArchitectureKit cryptoFramework）。
   */
  private static async md5Hex(input: string): Promise<string> {
    let md: cryptoFramework.Md = cryptoFramework.createMd('MD5');
    let bytes: Uint8Array = new util.TextEncoder().encodeInto(input);
    let blob: cryptoFramework.DataBlob = { data: bytes };
    await md.update(blob);
    let digest: cryptoFramework.DataBlob = await md.digest();
    return WbiSigner.toHexString(digest.data);
  }

  private static toHexString(bytes: Uint8Array): string {
    let result: string = '';
    for (let i = 0; i < bytes.length; i++) {
      let hex: string = bytes[i].toString(16);
      if (hex.length < 2) {
        hex = '0' + hex;
      }
      result += hex;
    }
    return result;
  }
}
