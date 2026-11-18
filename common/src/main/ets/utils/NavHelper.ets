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

import router from '@ohos.router';
import deviceInfo from '@ohos.deviceInfo';
import { BusinessError } from '@ohos.base';
import { BLog } from './BLog';

/**
 * 设备门禁导航工具：UserSpace/Gallery 仅在 phone 注册路由，
 * common 组件在 tablet 等其他设备上调用时静默记录日志返回（行为与现状一致）。
 */
export class NavHelper {
  /**
   * 进入用户空间页（仅 phone 生效）
   * @param mid 用户 mid
   */
  static goUserSpace(mid: number): void {
    if (deviceInfo.deviceType !== 'phone') {
      BLog.i("NavHelper goUserSpace skip, deviceType=" + deviceInfo.deviceType);
      return;
    }
    router.pushUrl({ url: 'pages/UserSpace', params: { mid: mid } }).catch((error: BusinessError) => {
      BLog.e("NavHelper goUserSpace err=" + error.code + ", msg=" + error.message);
    });
  }

  /**
   * 进入全屏图片预览页（仅 phone 生效）
   * @param urls 图片 URL 列表
   * @param index 初始展示的图片下标
   */
  static goGallery(urls: string[], index: number): void {
    if (deviceInfo.deviceType !== 'phone') {
      BLog.i("NavHelper goGallery skip, deviceType=" + deviceInfo.deviceType);
      return;
    }
    router.pushUrl({ url: 'pages/Gallery', params: { urls: urls, index: index } }).catch((error: BusinessError) => {
      BLog.e("NavHelper goGallery err=" + error.code + ", msg=" + error.message);
    });
  }
}
