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
import { ApiManager, FavFolder, FavFolderData, NavHelper, OhNavBar, StringUtil } from '@ohos/common';

/** 页面加载状态 */
enum LoadState {
  Loading,
  Error,
  Content
}

/**
 * 我的收藏页：收藏夹列表（名称/数量），点击进入收藏夹内容页（FavDetail）；
 * 未登录页内登录引导（不发起请求）；空态/错误态可重试。
 */
@Entry
@Component
struct Favorite {
  @StorageLink('isOhBiliLoggedIn') @Watch('onLoginStateChanged') loginState: boolean = false;
  @State state: LoadState = LoadState.Loading;
  @State folders: FavFolder[] = [];

  aboutToAppear() {
    if (this.loginState) {
      this.loadFolders();
    } else {
      this.state = LoadState.Content;
    }
  }

  onLoginStateChanged() {
    if (this.loginState && this.folders.length == 0 && this.state != LoadState.Loading) {
      this.loadFolders();
    }
  }

  /**
   * 返回本页时静默刷新夹计数（FavDetail 内取消收藏后 media_count 变化）
   */
  onPageShow() {
    if (this.loginState && this.state == LoadState.Content) {
      this.refreshFolders();
    }
  }

  build() {
    Column() {
      OhNavBar({ title: "我的收藏", isBack: true })

      if (!this.loginState) {
        // 未登录：页内登录引导，不发起收藏夹请求
        Column() {
          Text("你还未登录").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("登录账号，查看你的收藏夹").fontSize(15).fontColor('#888888').margin({ top: 16 })
          Button("登录").width(240).margin({ top: 16 }).onClick(() => {
            NavHelper.goLogin();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.state == LoadState.Loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
          Text("加载中...")
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.state == LoadState.Error) {
        Column() {
          Text("收藏夹加载失败").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium)
          Text("登录已失效或网络异常，请重试").fontSize(14).fontColor('#888888').margin({ top: 12 })
          Button("重试").width(240).margin({ top: 16 }).onClick(() => {
            this.loadFolders();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.folders.length == 0) {
        // 空态
        Column() {
          Text("暂无收藏夹").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("收藏喜欢的视频试试").fontSize(14).fontColor('#888888').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.folders, (folder: FavFolder) => {
            ListItem() {
              this.FolderRow(folder)
            }
          }, (folder: FavFolder) => 'folder_' + (folder.id ?? 0))
        }
        .width('100%')
        .height('100%')
        .padding({ top: 8, bottom: 8, left: 12, right: 12 })
        .edgeEffect(EdgeEffect.None)
      }
    }.width('100%').height('100%').backgroundColor('#eeeeee')
  }

  /**
   * 收藏夹行：名称 + 内容数量 + 进入箭头
   */
  @Builder
  private FolderRow(folder: FavFolder) {
    Row() {
      Stack() {
        Text('藏')
          .fontSize(20)
          .fontColor(Color.White)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('#fb7299')
          .borderRadius(22)
      }
      .width(44)
      .height(44)

      Column() {
        Text(folder.title ?? '')
          .fontSize(15)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(StringUtil.generateCN(folder.media_count ?? 0) + '个内容')
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Text('›')
        .fontSize(20)
        .fontColor('#cccccc')
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/FavDetail',
        params: { mediaId: folder.id ?? 0, title: folder.title ?? '' }
      });
    })
  }

  private loadFolders(): void {
    this.state = LoadState.Loading;
    let mid: number = Number(AppStorage.get<string>('ohBiliDedeUserId') ?? '0');
    ApiManager.getInstance().requestFavFolders(mid).then((data: FavFolderData | null) => {
      if (data == null) {
        this.state = LoadState.Error;
        return;
      }
      this.folders = data.list ?? [];
      this.state = LoadState.Content;
    }).catch(() => {
      this.state = LoadState.Error;
    });
  }

  /**
   * 静默刷新夹列表（不进 Loading 态避免闪烁；失败保留原列表）
   */
  private refreshFolders(): void {
    let mid: number = Number(AppStorage.get<string>('ohBiliDedeUserId') ?? '0');
    ApiManager.getInstance().requestFavFolders(mid).then((data: FavFolderData | null) => {
      if (data != null) {
        this.folders = data.list ?? [];
      }
    }).catch(() => {
    });
  }
}
