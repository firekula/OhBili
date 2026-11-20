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

import { ApiManager } from '../../network/ApiManager';
import { BaseVideo } from '../../model/response/Response';
import { FavFolder, FavFolderData } from '../../model/response/FavFolderResponse';
import { PlayUrlResponse } from '../../model/response/PlayUrlResponse';
import { VideoPartsResponse } from '../../model/response/VideoPartsResponse';
import { CacheTask } from '../../model/CacheTask';
import { DownloadManager } from '../../utils/DownloadManager';
import { NavHelper } from '../../utils/NavHelper';
import { StringUtil } from '../../utils/StringUtil';

/**
 * 视频页操作行：收藏 / 稍后再看 / 缓存 三按钮。
 * 收藏：弹收藏夹多选弹窗（fav_state 预勾选），确认 favDeal 提交 add/del 差集；
 * 稍后再看/缓存：占位禁用（后续用户故事启用）。
 * 未登录点击收藏引导登录。
 */
@Component
export struct VideoActionRow {
  vInfo: BaseVideo = null;
  @State isFav: boolean = false;
  private dialogController: CustomDialogController = null;

  build() {
    Row() {
      this.ActionButton('收藏', this.isFav ? '#fb7299' : $r('app.color.text_mid'), () => {
        this.onFavClick();
      })

      this.ActionButton('稍后再看', $r('app.color.text_mid'), () => {
        this.onWatchLaterClick();
      })

      this.ActionButton('缓存', $r('app.color.text_mid'), () => {
        this.onCacheClick();
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .padding({ top: 8, bottom: 8 })
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  private ActionButton(label: string, color: ResourceColor, onTap: () => void, enabled: boolean = true) {
    Text(label)
      .fontSize(13)
      .fontColor(color)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(14)
      .backgroundColor(enabled ? $r('app.color.surface_soft') : $r('app.color.surface_soft'))
      .onClick(() => {
        onTap();
      })
  }

  /**
   * 收藏点击：未登录引导登录；已登录解析 aid 后打开收藏夹多选弹窗
   */
  private onFavClick(): void {
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
      this.openFavDialog(aid);
    }).catch(() => {
      this.showToast('视频信息获取失败，请重试');
    });
  }

  /**
   * 稍后再看点击：未登录引导登录；已登录解析 aid 后添加并 toast
   */
  private onWatchLaterClick(): void {
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
      ApiManager.getInstance().addWatchLater(aid).then((ok: boolean) => {
        if (ok) {
          this.showToast('已加入稍后再看');
        } else {
          this.showToast('加入稍后再看失败，请重试');
        }
      }).catch(() => {
        this.showToast('加入稍后再看失败，请重试');
      });
    }).catch(() => {
      this.showToast('视频信息获取失败，请重试');
    });
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

  /**
   * 打开收藏夹多选弹窗（每次点击重建，传入最新 aid）
   */
  private openFavDialog(aid: number): void {
    this.dialogController = new CustomDialogController({
      builder: FavFolderDialog({
        aid: aid,
        onResult: (fav: boolean) => {
          this.isFav = fav;
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom
    });
    this.dialogController.open();
  }

  /**
   * 缓存点击：解析 cid 后弹清晰度选择弹窗
   */
  private onCacheClick(): void {
    this.resolveCid().then((cid: number) => {
      if (cid <= 0) {
        this.showToast('视频信息获取失败，请重试');
        return;
      }
      this.openCacheDialog(cid);
    }).catch(() => {
      this.showToast('视频信息获取失败，请重试');
    });
  }

  /**
   * 打开清晰度选择弹窗（每次点击重建，传入 cid）
   */
  private openCacheDialog(cid: number): void {
    this.dialogController = new CustomDialogController({
      builder: QualitySelectDialog({
        bvid: this.vInfo.bvid,
        cid: cid,
        onSelected: (qn: number, qualityDesc: string) => {
          this.confirmCacheSize(cid, qn, qualityDesc);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom
    });
    this.dialogController.open();
  }

  /**
   * 选定清晰度后：请求该 qn 的 playurl，以 durl.size 预估大小二次确认（AlertDialog），
   * 确认后构造 CacheTask 入队下载。
   */
  private confirmCacheSize(cid: number, qn: number, qualityDesc: string): void {
    ApiManager.getInstance().requestPlayUrl(this.vInfo.bvid, cid, qn)
      .then((response: PlayUrlResponse) => {
        if (response == null || response.data == null
          || response.data.durl == null || response.data.durl.length == 0) {
          this.showToast('获取下载地址失败，请重试');
          return;
        }
        let size: number = 0;
        response.data.durl.forEach(durl => {
          size += durl.size ?? 0;
        });
        let url: string = response.data.durl[0].url.replace(/\\u0026/g, '&');
        AlertDialog.show({
          title: '缓存视频',
          message: '清晰度：' + qualityDesc + '\n预计大小：' + this.formatBytes(size) + '\n确定开始缓存吗？',
          primaryButton: {
            value: '取消',
            action: () => {
            }
          },
          secondaryButton: {
            value: '开始缓存',
            fontColor: '#fb7299',
            action: () => {
              this.enqueueCacheTask(cid, qn, qualityDesc, url, size);
            }
          }
        });
      }).catch(() => {
        this.showToast('获取下载地址失败，请重试');
      });
  }

  /**
   * 构造 CacheTask 并入下载队列（同 id 去重）
   */
  private enqueueCacheTask(cid: number, qn: number, qualityDesc: string, url: string, size: number): void {
    let task: CacheTask = new CacheTask();
    task.id = this.vInfo.bvid + '_' + cid + '_' + qn;
    task.bvid = this.vInfo.bvid;
    task.cid = cid;
    task.aid = this.vInfo.aid ?? 0;
    task.title = this.vInfo.title ?? '';
    task.cover = this.vInfo.pic ?? '';
    task.upName = this.vInfo.owner == null ? '' : (this.vInfo.owner.name ?? '');
    task.quality = qn;
    task.qualityDesc = qualityDesc;
    task.totalBytes = size;
    task.localDir = 'offline/' + task.id;
    task.fileName = 'video.mp4';
    task.createTime = Math.floor(Date.now() / 1000);
    let ok: boolean = DownloadManager.getInstance().enqueue(task, url);
    if (ok) {
      this.showToast('已加入缓存队列');
    } else {
      this.showToast('该视频已在缓存列表中');
    }
  }

  /**
   * 解析视频 cid：BaseVideo.cid 缺失时经分P列表接口兜底取第一P
   */
  private async resolveCid(): Promise<number> {
    if (this.vInfo != null && this.vInfo.cid != null && this.vInfo.cid > 0) {
      return this.vInfo.cid;
    }
    let response: VideoPartsResponse =
      await ApiManager.getInstance().requestPageList(this.vInfo.bvid);
    if (response != null && response.data != null && response.data.length > 0) {
      let cid: number = response.data[0].cid;
      if (this.vInfo != null) {
        this.vInfo.cid = cid;
      }
      return cid;
    }
    return 0;
  }

  /**
   * 字节数格式化（B/KB/MB/GB）
   */
  private formatBytes(bytes: number): string {
    if (bytes < 0) {
      bytes = 0;
    }
    if (bytes < 1024) {
      return bytes + 'B';
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(1) + 'KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return (bytes / 1024 / 1024).toFixed(1) + 'MB';
    }
    return (bytes / 1024 / 1024 / 1024).toFixed(2) + 'GB';
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}

/**
 * 收藏夹多选弹窗：fav_state 预勾选，确认时 favDeal 提交 add/del 差集；
 * 成功后回调 onResult(anyChecked) 更新操作行收藏态。
 */
@CustomDialog
struct FavFolderDialog {
  controller?: CustomDialogController;
  private aid: number = 0;
  onResult: (fav: boolean) => void = () => {
  };
  @State folders: FavFolder[] = [];
  @State checked: boolean[] = [];
  @State loading: boolean = true;
  @State loadFailed: boolean = false;
  private originalChecked: boolean[] = [];

  aboutToAppear() {
    this.loadFolders();
  }

  build() {
    Column() {
      Text('选择收藏夹')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16, bottom: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .margin({ top: 24, bottom: 24 })
        }
      } else if (this.loadFailed) {
        Column() {
          Text('收藏夹加载失败').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 16 })
          Text('重试').fontSize(14).fontColor('#fb7299').padding(8).margin({ top: 4 }).onClick(() => {
            this.loadFolders();
          })
        }
      } else if (this.folders.length == 0) {
        Column() {
          Text('暂无收藏夹').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 16, bottom: 16 })
        }
      } else {
        Scroll() {
          Column() {
            ForEach(this.folders, (folder: FavFolder, index: number) => {
              Row() {
                Text(this.checked[index] ? '✓' : '')
                  .fontSize(14)
                  .fontColor('#fb7299')
                  .width(20)
                  .height(20)
                  .borderRadius(10)
                  .border({ width: 1, color: this.checked[index] ? '#fb7299' : $r('app.color.border') })
                  .textAlign(TextAlign.Center)

                Column() {
                  Text(folder.title ?? '')
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(StringUtil.generateCN(folder.media_count ?? 0) + '个内容')
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10, left: 16, right: 16 })
              .onClick(() => {
                this.checked[index] = !this.checked[index];
              })
            }, (folder: FavFolder, index: number) => 'folder_' + (folder.id ?? 0) + '_' + this.checked[index])
          }
          .width('100%')
        }
        .constraintSize({ maxHeight: 320 })
        .scrollBar(BarState.Auto)
      }

      Divider().margin({ top: 8 })

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor($r('app.color.text_mid'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.controller.close();
          })
        Divider().vertical(true).height(24)
        Text('收藏')
          .fontSize(15)
          .fontColor('#fb7299')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.confirmDeal();
          })
      }
      .width('100%')
    }
    .width('92%')
    .borderRadius(16)
    .backgroundColor($r('app.color.surface'))
    .padding({ bottom: 8 })
  }

  private loadFolders(): void {
    this.loading = true;
    this.loadFailed = false;
    let mid: number = Number(AppStorage.get<string>('ohBiliDedeUserId') ?? '0');
    ApiManager.getInstance().requestFavFolders(mid, this.aid).then((data: FavFolderData | null) => {
      this.loading = false;
      if (data == null || data.list == null) {
        this.loadFailed = true;
        return;
      }
      this.folders = data.list;
      let checkedArr: boolean[] = [];
      let origArr: boolean[] = [];
      this.folders.forEach((folder: FavFolder) => {
        let fav: boolean = (folder.fav_state ?? 0) == 1;
        checkedArr.push(fav);
        origArr.push(fav);
      });
      this.checked = checkedArr;
      this.originalChecked = origArr;
    }).catch(() => {
      this.loading = false;
      this.loadFailed = true;
    });
  }

  /**
   * 确认收藏：favDeal 提交勾选差集（add=新勾选，del=取消勾选）
   */
  private confirmDeal(): void {
    let addIds: number[] = [];
    let delIds: number[] = [];
    let anyChecked: boolean = false;
    for (let i = 0; i < this.folders.length; i++) {
      let mediaId: number = this.folders[i].id ?? 0;
      if (mediaId <= 0) {
        continue;
      }
      if (this.checked[i]) {
        anyChecked = true;
        if (!this.originalChecked[i]) {
          addIds.push(mediaId);
        }
      } else {
        if (this.originalChecked[i]) {
          delIds.push(mediaId);
        }
      }
    }
    if (addIds.length == 0 && delIds.length == 0) {
      // 无变更：直接关闭
      this.controller.close();
      if (this.onResult != null) {
        this.onResult(anyChecked);
      }
      return;
    }
    ApiManager.getInstance().favDeal(this.aid, addIds, delIds).then((ok: boolean) => {
      if (ok) {
        this.showToast(anyChecked ? '收藏成功' : '已取消收藏');
        this.controller.close();
        if (this.onResult != null) {
          this.onResult(anyChecked);
        }
      } else {
        this.showToast('收藏操作失败，请重试');
      }
    }).catch(() => {
      this.showToast('收藏操作失败，请重试');
    });
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}

/**
 * 清晰度选择弹窗：匿名请求 playurl 拿 accept_quality/accept_description 列表，
 * 点选某一档后回调 onSelected(qn, desc) 并关闭。
 */
@CustomDialog
struct QualitySelectDialog {
  controller?: CustomDialogController;
  private bvid: string = '';
  private cid: number = 0;
  onSelected: (qn: number, desc: string) => void = () => {
  };
  @State qualities: number[] = [];
  @State descriptions: string[] = [];
  @State loading: boolean = true;
  @State loadFailed: boolean = false;

  aboutToAppear() {
    this.loadQualities();
  }

  build() {
    Column() {
      Text('选择清晰度')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16, bottom: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .margin({ top: 24, bottom: 24 })
        }
      } else if (this.loadFailed) {
        Column() {
          Text('清晰度加载失败').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 16 })
          Text('重试').fontSize(14).fontColor('#fb7299').padding(8).margin({ top: 4 }).onClick(() => {
            this.loadQualities();
          })
        }
      } else if (this.qualities.length == 0) {
        Column() {
          Text('暂无可用清晰度').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 16, bottom: 16 })
        }
      } else {
        Scroll() {
          Column() {
            ForEach(this.descriptions, (desc: string, index: number) => {
              Row() {
                Text(desc)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text('缓存')
                  .fontSize(12)
                  .fontColor('#fb7299')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                this.selectQuality(index);
              })
            })
          }
        }
        .constraintSize({ maxHeight: 300 })
      }
    }
    .width('100%')
    .borderRadius(12)
    .backgroundColor($r('app.color.surface'))
    .padding({ bottom: 16 })
  }

  /**
   * 加载可用清晰度列表（匿名请求即可）
   */
  private loadQualities(): void {
    this.loading = true;
    this.loadFailed = false;
    ApiManager.getInstance().requestPlayUrl(this.bvid, this.cid)
      .then((response: PlayUrlResponse) => {
        this.loading = false;
        if (response == null || response.data == null
          || response.data.accept_quality == null || response.data.accept_quality.length == 0) {
          this.loadFailed = true;
          return;
        }
        this.qualities = response.data.accept_quality;
        if (response.data.accept_description != null
          && response.data.accept_description.length == this.qualities.length) {
          this.descriptions = response.data.accept_description;
        } else {
          // 描述缺失时以 qn 值兜底
          let descs: string[] = [];
          this.qualities.forEach(qn => {
            descs.push(qn + 'P');
          });
          this.descriptions = descs;
        }
      }).catch(() => {
        this.loading = false;
        this.loadFailed = true;
      });
  }

  /**
   * 点选清晰度：回调并关闭
   */
  private selectQuality(index: number): void {
    let qn: number = this.qualities[index];
    let desc: string = this.descriptions[index];
    this.controller.close();
    if (this.onSelected != null) {
      this.onSelected(qn, desc);
    }
  }
}
