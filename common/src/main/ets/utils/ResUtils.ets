export class ResUtils {
  static getLevel(level: number): Resource {
    switch (level) {
      case 0:
        return $r('app.media.dy_level_0');
      case 1:
        return $r('app.media.dy_level_1');
      case 2:
        return $r('app.media.dy_level_2');
      case 3:
        return $r('app.media.dy_level_3');
      case 4:
        return $r('app.media.dy_level_4');
      case 5:
        return $r('app.media.dy_level_5');
      default:
        return $r('app.media.dy_level_6');
    }
  }

  /**
   * 弹幕描边色：浅色弹幕配黑边、深色弹幕配白边。
   * 必须返回带 alpha 的 ARGB 值——danmakuflamemaster 以 0 作为 textShadowColor
   * "未设置"哨兵值（hasStroke 判定 textShadowColor != 0），纯黑 0x000000 会被
   * 误判为未设置导致白色弹幕描边失效，故用 0xFF000000 / 0xFFFFFFFF。
   */
  static getShadowColor(color: number): number {
    let red = (color >> 16) & 0xFF
    let green = (color >> 8) & 0xFF
    let blue = color & 0xFF
    let g = red * 0.299 + green * 0.587 + blue * 0.114;
    if (g >= 192) {
      return 0xFF000000;
    } else {
      return 0xFFFFFFFF;
    }
  }
}