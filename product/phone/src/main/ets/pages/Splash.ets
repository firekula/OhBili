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
import util from '@ohos.util';
import { WindowManager } from '@ohos/common';
import { ThemeUtil } from '@ohos/common';
import { ApiManager } from '@ohos/common';
import { BLog } from '@ohos/common';
import { LoginHelper } from '@ohos/common';

storageInit();

@Entry
@Component
struct Splash {
  @StorageLink('appLogDebug') appLogDebug: string = '0';
  @StorageLink('appUuid') appUuid: string = 'undefined';

  aboutToAppear() {
    BLog.setDebug(this.appLogDebug == '1');

    if (this.appUuid == 'undefined') {
      this.appUuid = util.generateRandomUUID();
    }
    BLog.i("appUuid: " + this.appUuid);

    // 深浅色模式：应用持久化选择（跟随系统/浅色/深色）并刷新状态栏配色
    let colorMode: string = AppStorage.get<string>('ohBiliColorMode') ?? ThemeUtil.MODE_FOLLOW_SYSTEM;
    ThemeUtil.applyColorMode(colorMode);
    ThemeUtil.applyThemeBars();

    this.initTask();
    setTimeout(() => {
      // [SPIKE 一次性验证代码] 临时直跳 DASH 验证页，验证后还原为 pages/Index
      router.replaceUrl({ url: "pages/DashSpike" });
    }, 1000);
  }

  async initTask() {
    ApiManager.getInstance().requestRecommend(1, true);
    ApiManager.getInstance().requestPopular(1);
    // 异步校验并恢复登录态，不阻塞 1 秒跳转
    LoginHelper.validateAndRestoreLoginState().then((isValid: boolean) => {
      BLog.i("validateAndRestoreLoginState: " + isValid);
    });
    // 异步预取设备 Cookie（buvid3/buvid4，官方指纹接口），不阻塞跳转
    LoginHelper.ensureDeviceCookies().then(() => {
      BLog.i("ensureDeviceCookies done");
    });
  }

  onPageShow() {
    ThemeUtil.applyThemeBars();
  }

  build() {
    Column() {
      Image($r('app.media.bilibili'))
        .width('100%')
        .height('100%')
    }.width('100%').height('100%')
  }
}

function storageInit() {
  PersistentStorage.PersistProp('checkUpdates', '1');
  PersistentStorage.PersistProp('showDefaultKeyword', '1');
  PersistentStorage.PersistProp('showTopSearch', '1');

  PersistentStorage.PersistProp('openDanmu', '1');
  PersistentStorage.PersistProp('danmuFontSize', '1.0X');
  PersistentStorage.PersistProp('danmuOpacity', '100%');

  PersistentStorage.PersistProp('pagePlayOver', '1');
  PersistentStorage.PersistProp('videoQuality', '1080P');
  PersistentStorage.PersistProp('playSpeed', '1.0X');
  // 播放器内选择的清晰度档位（qn，0=未指定走默认链路），跨启动记忆
  PersistentStorage.PersistProp('ohBiliPlayQn', 0);

  PersistentStorage.PersistProp('appLogDebug', '0');
  PersistentStorage.PersistProp('appUuid', 'undefined');

  // 深浅色模式（'跟随系统' | '浅色' | '深色'）
  PersistentStorage.PersistProp('ohBiliColorMode', '跟随系统');

  // 扫码登录相关持久化键
  PersistentStorage.PersistProp('isOhBiliLoggedIn', false);
  PersistentStorage.PersistProp('ohBiliSessdata', '');
  PersistentStorage.PersistProp('ohBiliBiliJct', '');
  PersistentStorage.PersistProp('ohBiliDedeUserId', '');
  PersistentStorage.PersistProp('ohBiliRefreshToken', '');
  PersistentStorage.PersistProp('ohBiliUname', '');
  PersistentStorage.PersistProp('ohBiliFace', '');

  // 设备 Cookie（对齐网页版：指纹接口获取 buvid3/buvid4）
  PersistentStorage.PersistProp('ohBiliBuvid3', '');
  PersistentStorage.PersistProp('ohBiliBuvid4', '');
}