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

import { BaseVideo } from './../../model/response/Response';
import { StringUtil } from './../../utils/StringUtil';
import { ApiManager } from './../../network/ApiManager';
import { NavHelper } from './../../utils/NavHelper';
import { CoinDialog } from './CoinDialog';

/**
 * 视频页顶部操作栏：点赞（可切换）/点踩（纯计数）/投币（弹窗）/收藏（纯计数）/分享（纯计数）。
 * 点赞/投币状态由页面级 isLiked/isCoined 注入（@Link 双向），
 * 未登录点击引导登录；aid 缺失时经 archive/stat 兜底解析。
 */
@Component
export struct VideoTopBar {
  @Link vInfo: BaseVideo;
  @Link isLiked: boolean;
  @Link isCoined: boolean;
  private dialogController: CustomDialogController = null;

  build() {
    Row() {
      Column() {
        Image(this.isLiked ? $r('app.media.ic_topbar_liked_bold') : $r('app.media.ic_topbar_like_bold'))
          .width(24)
          .height(24)
        Text(StringUtil.generateCN(this.vInfo.stat.like))
          .fontSize(12)
          .fontColor(this.isLiked ? '#fb7299' : '#333333')
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .onClick(() => {
        this.onLikeClick();
      })

      Column() {
        Image($r('app.media.ic_topbar_dislike_bold'))
          .width(24)
          .height(24)
        Text($r('app.string.dislike'))
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 8 })
      }.layoutWeight(1)

      Column() {
        Image(this.isCoined ? $r('app.media.ic_topbar_coined_bold') : $r('app.media.ic_topbar_coin_bold'))
          .width(24)
          .height(24)
        Text(StringUtil.generateCN(this.vInfo.stat.coin == undefined ? 0 : this.vInfo.stat.coin))
          .fontSize(12)
          .fontColor(this.isCoined ? '#fb7299' : '#333333')
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .onClick(() => {
        this.onCoinClick();
      })

      Column() {
        Image($r('app.media.ic_topbar_favorite_bold'))
          .width(24)
          .height(24)
        Text(StringUtil.generateCN(this.vInfo.stat.favorite == undefined ? 0 : this.vInfo.stat.favorite))
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 8 })
      }.layoutWeight(1)

      Column() {
        Image($r('app.media.ic_topbar_share_bold'))
          .width(24)
          .height(24)
        Text(StringUtil.generateCN(this.vInfo.stat.share == undefined ? 0 : this.vInfo.stat.share))
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 8 })
      }.layoutWeight(1)
    }.width('100%').padding(16)
  }

  /**
   * 点赞点击：未登录引导登录；已赞再点取消（like=2），成功后同步计数与选中态
   */
  private onLikeClick(): void {
    let loggedIn: boolean = AppStorage.get<boolean>('isOhBiliLoggedIn') ?? false;
    if (!loggedIn) {
      NavHelper.goLogin();
      return;
    }
    this.resolveAid().then((aid: number) => {
      if (aid <= 0) {
        this.showToast('视频信息获取失败，请重试');
        return;
      }
      let like: number = this.isLiked ? 2 : 1;
      ApiManager.getInstance().likeVideo(aid, like).then((code: number) => {
        if (code == 0) {
          if (like == 1) {
            this.isLiked = true;
            this.vInfo.stat.like = this.vInfo.stat.like + 1;
          } else {
            this.isLiked = false;
            this.vInfo.stat.like = Math.max(0, this.vInfo.stat.like - 1);
          }
          return;
        }
        if (code == 65006 && like == 1) {
          // 65006：已点赞，视为成功
          this.isLiked = true;
          return;
        }
        if (code == -101) {
          this.showToast('登录已失效，请重新登录');
          NavHelper.goLogin();
          return;
        }
        this.showToast('操作失败，请重试');
      }).catch(() => {
        this.showToast('操作失败，请重试');
      });
    }).catch(() => {
      this.showToast('视频信息获取失败，请重试');
    });
  }

  /**
   * 投币点击：未登录引导登录；已投过提示；否则弹投币弹窗
   */
  private onCoinClick(): void {
    let loggedIn: boolean = AppStorage.get<boolean>('isOhBiliLoggedIn') ?? false;
    if (!loggedIn) {
      NavHelper.goLogin();
      return;
    }
    if (this.isCoined) {
      this.showToast('已经投过币啦');
      return;
    }
    this.resolveAid().then((aid: number) => {
      if (aid <= 0) {
        this.showToast('视频信息获取失败，请重试');
        return;
      }
      this.openCoinDialog(aid);
    }).catch(() => {
      this.showToast('视频信息获取失败，请重试');
    });
  }

  /**
   * 打开投币弹窗（每次点击重建，传入最新 aid）
   */
  private openCoinDialog(aid: number): void {
    this.dialogController = new CustomDialogController({
      builder: CoinDialog({
        aid: aid,
        onResult: (multiply: number, liked: boolean) => {
          if (multiply > 0 && !this.isCoined) {
            this.isCoined = true;
            this.vInfo.stat.coin = (this.vInfo.stat.coin ?? 0) + multiply;
          }
          if (liked && !this.isLiked) {
            this.isLiked = true;
            this.vInfo.stat.like = this.vInfo.stat.like + 1;
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom
    });
    this.dialogController.open();
  }

  /**
   * 解析视频 aid：BaseVideo.aid 缺失时经 archive/stat 接口兜底获取
   */
  private async resolveAid(): Promise<number> {
    if (this.vInfo != null && this.vInfo.aid != null && this.vInfo.aid > 0) {
      return this.vInfo.aid;
    }
    let response = await ApiManager.getInstance().requestArchiveStat(this.vInfo.bvid);
    if (response != null && response.data != null && response.data.aid != null) {
      let aid: number = response.data.aid;
      if (this.vInfo != null) {
        this.vInfo.aid = aid;
      }
      return aid;
    }
    return 0;
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}
