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

import { ConfigurationConstant } from '@kit.AbilityKit';
import { WindowManager } from './WindowManager';

/**
 * 深浅色主题工具：
 * - 颜色资源（$r('app.color.*')）由 base/dark 资源目录随系统或应用深色模式自动切换；
 * - 应用内通过 AppStorage['ohBiliColorMode']（'跟随系统' | '浅色' | '深色'）持久化用户选择；
 * - 状态栏等窗口属性不支持资源自动切换，需在切换时手动刷新（applyThemeBars）。
 */
export class ThemeUtil {
  static readonly MODE_FOLLOW_SYSTEM: string = '跟随系统';
  static readonly MODE_LIGHT: string = '浅色';
  static readonly MODE_DARK: string = '深色';

  /**
   * 当前是否深色模式：
   * 用户选了 浅色/深色 时以选择为准；跟随系统时读取当前生效配置。
   */
  static isDarkMode(): boolean {
    let mode: string = AppStorage.get<string>('ohBiliColorMode') ?? ThemeUtil.MODE_FOLLOW_SYSTEM;
    if (mode === ThemeUtil.MODE_DARK) {
      return true;
    }
    if (mode === ThemeUtil.MODE_LIGHT) {
      return false;
    }
    try {
      let ctx = globalThis.appContext;
      if (ctx != undefined) {
        return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      }
    } catch (err) {
      // 配置读取失败按浅色处理
    }
    return false;
  }

  /**
   * 按用户选择应用深浅色模式（'跟随系统' | '浅色' | '深色'）
   */
  static applyColorMode(label: string): void {
    try {
      let ctx = globalThis.appContext;
      if (ctx != undefined) {
        let appCtx = ctx.getApplicationContext();
        if (label === ThemeUtil.MODE_DARK) {
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
        } else if (label === ThemeUtil.MODE_LIGHT) {
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
        } else {
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        }
      }
    } catch (err) {
      // 上下文未就绪时忽略，由 Splash 启动时再应用
    }
  }

  /**
   * 标准页面状态栏背景色（深浅色自适应，与页面 surface 一致）
   */
  static statusBarBgColor(): string {
    return ThemeUtil.isDarkMode() ? '#1E1E1E' : WindowManager.COLOR_WHITE;
  }

  /**
   * 标准页面状态栏内容色（深浅色自适应）
   */
  static statusBarContentColor(): string {
    return ThemeUtil.isDarkMode() ? '#E6E6E6' : WindowManager.COLOR_BLACK;
  }

  /**
   * 标准页面窗口配色（非沉浸式，状态栏/导航条背景与内容色随主题切换），
   * 并同步窗口背景色：未显式设置背景的页面（首页/我的/搜索等）以窗口底色兜底
   */
  static applyThemeBars(): void {
    WindowManager.setLayoutFullScreen(false, ThemeUtil.statusBarBgColor(), ThemeUtil.statusBarContentColor(),
      ThemeUtil.statusBarBgColor(), ThemeUtil.statusBarContentColor());
    let win = WindowManager.getMainWindow();
    if (win != null) {
      try {
        win.setWindowBackgroundColor(ThemeUtil.isDarkMode() ? '#121212' : '#FFFFFF');
      } catch (err) {
        // 忽略：窗口未就绪
      }
    }
  }
}
