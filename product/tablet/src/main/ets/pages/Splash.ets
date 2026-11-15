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
import { ApiManager } from '@ohos/common';
import { BLog } from '@ohos/common';

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

    this.initTask();
    setTimeout(() => {
      router.replaceUrl({ url: "pages/Index" });
    }, 1000);
  }

  async initTask() {
    ApiManager.getInstance().requestRecommend(1, true);
    ApiManager.getInstance().requestPopular(1);
  }

  onPageShow() {
    WindowManager.setLayoutFullScreen(false, WindowManager.COLOR_WHITE,
      WindowManager.COLOR_BLACK, WindowManager.COLOR_WHITE, WindowManager.COLOR_BLACK);
  }

  build() {
    Column() {
      Image($r('app.media.bilibili'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
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

  PersistentStorage.PersistProp('appLogDebug', '0');
  PersistentStorage.PersistProp('appUuid', 'undefined');
}