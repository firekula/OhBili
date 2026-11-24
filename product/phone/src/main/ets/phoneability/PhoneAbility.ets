import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import { Configuration } from '@kit.AbilityKit';
import { WindowManager } from '@ohos/common';
import { DownloadManager } from '@ohos/common';
import { ThemeUtil } from '@ohos/common';
import { ImageKnife, ImageKnifeDrawFactory } from '@ohos/imageknife'
import { CustomEngineKeyImpl } from './CustomEngineKeyImpl';
import { BLog } from '@ohos/common';
import connection from '@ohos.net.connection';
import bundleManager from '@ohos.bundle.bundleManager';

export default class PhoneAbility extends UIAbility {
  private netConn: connection.NetConnection;

  onCreate(want, launchParam) {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    globalThis.appContext = this.context;
    globalThis.resourceMana = this.context.resourceManager;
    globalThis.ImageKnife = ImageKnife.with(this.context);
    globalThis.ImageKnife.setDefaultLifeCycle(ImageKnifeDrawFactory.createProgressLifeCycle("#10a5ff", 0.5));
    globalThis.ImageKnife.setEngineKeyImpl(new CustomEngineKeyImpl());
  }

  onDestroy() {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
    this.netConnUnregister();
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    globalThis.windowStage = windowStage;
    globalThis.filesDir = this.context.filesDir;
    BLog.init(this.context.filesDir);
    // 离线缓存：启动恢复 index.json（DOWNLOADING 中断残留降级 FAILED）
    DownloadManager.getInstance().init(this.context);
    AppStorage.SetOrCreate("netIsAvailable", true);
    this.netConnRegister();
    this.getAppBundleInfo();

    ThemeUtil.applyThemeBars();

    windowStage.loadContent('pages/Splash', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data) ?? '');
    });
  }

  onWindowStageDestroy() {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 跟随系统时，系统深浅色切换后刷新状态栏配色（页面颜色资源随配置自动切换）
    ThemeUtil.applyThemeBars();
  }

  onForeground() {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
    AppStorage.SetOrCreate('ohBiliAbilityBackground', false);
  }

  onBackground() {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
    AppStorage.SetOrCreate('ohBiliAbilityBackground', true);
  }

  netConnRegister() {
    let netCap = {
      bearerTypes: [connection.NetBearType.BEARER_CELLULAR,
      connection.NetBearType.BEARER_WIFI],
      networkCap: [connection.NetCap.NET_CAPABILITY_INTERNET],
    };
    let netSpec = {
      netCapabilities: netCap,
    };
    let timeout = 5 * 1000;
    this.netConn = connection.createNetConnection(netSpec, timeout);
    this.netConn.on('netAvailable', (data => {
      BLog.i("net is available, netId is " + data.netId);
      //this.netIsAvailable = true;
      AppStorage.SetOrCreate("netIsAvailable", true);
    }));
    this.netConn.on('netUnavailable', (data => {
      BLog.i("net is unavailable, data is " + JSON.stringify(data));
      //this.netIsAvailable = false;
      AppStorage.SetOrCreate("netIsAvailable", false);
    }));
    this.netConn.register((err, data) => { });
  }

  netConnUnregister() {
    this.netConn.unregister((err, data) => { });
  }

  getAppBundleInfo() {
    try {
      bundleManager.getBundleInfoForSelf(0).then(info => {
        BLog.i(`app info name: ${info.name}, versionName: ${info.versionName}`);
        AppStorage.SetOrCreate("appTargetVersion", info.targetVersion);
        AppStorage.SetOrCreate("appBundleName", info.name);
        AppStorage.SetOrCreate("appVersionName", info.versionName);
        AppStorage.SetOrCreate("appVendor", info.vendor);
      })
    } catch (err) {
      BLog.e(`getBundleInfo failed: ${err.message}`);
    }
  }
}
