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
import { ApiManager, BaseVideo, CacheTask, CacheTaskStatus, DownloadManager,
  EmptyBaseVideo, EmptyStat, OhNavBar, Owner, PlayUrlResponse, Stat } from '@ohos/common';

/**
 * 离线缓存管理页：
 * - 未登录仍可查看已缓存内容（本地数据不要求登录）；
 * - 任务列表（封面/标题/清晰度/状态与进度/大小），DownloadManager 监听实时刷新；
 * - 顶部存储占用统计；
 * - 行尾删除按钮（AlertDialog 二次确认，DownloadManager.remove）；
 * - FAILED 条目重试（重新请求 playurl 刷新直链后入队）；
 * - COMPLETED 条目点击跳 Video 本地播放（localPath）。
 */
@Entry
@Component
struct OfflineCache {
  @State tasks: CacheTask[] = [];
  @State totalSize: number = 0;
  @State retryingId: string = '';

  /** DownloadManager 变更监听（箭头函数保持 this 绑定，便于注销） */
  private updateTasks = (): void => {
    let all: CacheTask[] = DownloadManager.getInstance().getAllTasks();
    let copied: CacheTask[] = [];
    all.forEach(task => {
      copied.push(task);
    });
    this.tasks = copied;
    this.totalSize = DownloadManager.getInstance().getTotalSize();
  };

  aboutToAppear() {
    this.updateTasks();
    DownloadManager.getInstance().registerListener(this.updateTasks);
  }

  aboutToDisappear() {
    DownloadManager.getInstance().unregisterListener(this.updateTasks);
  }

  build() {
    Column() {
      OhNavBar({ title: "离线缓存", isBack: true })

      // 存储占用统计
      Row() {
        Text("已缓存 " + this.tasks.length + " 个视频")
          .fontSize(13)
          .fontColor('#666666')
        Blank()
        Text("占用 " + this.formatBytes(this.totalSize))
          .fontSize(13)
          .fontColor('#666666')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      if (this.tasks.length == 0) {
        // 空态
        Column() {
          Text("还没有缓存内容").fontSize(16).fontColor(Color.Black).fontWeight(FontWeight.Medium).margin({ top: 48 })
          Text("在视频页点\"缓存\"，离线也能看").fontSize(14).fontColor('#888888').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.tasks, (task: CacheTask) => {
            ListItem() {
              this.TaskRow(task)
            }
          }, (task: CacheTask) => task.id + '_' + task.status + '_' + task.receivedBytes)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, bottom: 8 })
        .edgeEffect(EdgeEffect.None)
      }
    }.width('100%').height('100%').backgroundColor('#eeeeee')
  }

  /**
   * 缓存任务行：封面 + 标题/UP/清晰度 + 状态与进度 + 行尾操作
   */
  @Builder
  private TaskRow(task: CacheTask) {
    Row() {
      Image(task.cover)
        .width(120)
        .height(74)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.ic_comment_avatar_default'))

      Column() {
        Text(task.title)
          .fontSize(14)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start)
        Text(task.upName)
          .fontSize(11)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
        Text(task.qualityDesc)
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 2 })

        if (task.status == CacheTaskStatus.WAITING || task.status == CacheTaskStatus.DOWNLOADING) {
          Progress({ value: this.progressPercent(task), total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(4)
            .margin({ top: 6 })
            .color('#fb7299')
          Text(this.statusText(task))
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 3 })
        } else if (task.status == CacheTaskStatus.FAILED) {
          Text(this.retryingId == task.id ? '重试中...' : '下载失败')
            .fontSize(10)
            .fontColor('#e25d5d')
            .margin({ top: 6 })
        } else {
          Text('已缓存 ' + this.formatBytes(task.totalBytes))
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .height(74)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10, right: 8 })

      if (task.status == CacheTaskStatus.FAILED) {
        Text("重试")
          .fontSize(12)
          .fontColor('#fb7299')
          .padding({ left: 8, right: 4, top: 8, bottom: 8 })
          .enabled(this.retryingId == '')
          .onClick(() => {
            this.retryTask(task);
          })
      }
      Text("删除")
        .fontSize(12)
        .fontColor('#999999')
        .padding({ left: 4, right: 4, top: 8, bottom: 8 })
        .onClick(() => {
          this.confirmRemove(task);
        })
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onItemClick(task);
    })
  }

  /**
   * 条目点击：COMPLETED 跳本地播放；其余不响应
   */
  private onItemClick(task: CacheTask): void {
    if (task.status != CacheTaskStatus.COMPLETED) {
      return;
    }
    let video: BaseVideo = EmptyBaseVideo(task.bvid);
    video.title = task.title;
    video.pic = task.cover;
    video.aid = task.aid;
    video.cid = task.cid;
    let owner: Owner = {
      mid: 0,
      name: task.upName,
      face: ''
    };
    video.owner = owner;
    video.stat = EmptyStat();
    let localPath: string = DownloadManager.getInstance().getLocalFilePath(task);
    router.pushUrl({ url: 'pages/Video', params: { vInfo: video, localPath: localPath } });
  }

  /**
   * 失败重试：刷新 playurl 直链后重新入队
   */
  private retryTask(task: CacheTask): void {
    this.retryingId = task.id;
    ApiManager.getInstance().requestPlayUrl(task.bvid, task.cid, task.quality)
      .then((response: PlayUrlResponse) => {
        this.retryingId = '';
        if (response == null || response.data == null
          || response.data.durl == null || response.data.durl.length == 0) {
          this.showToast('获取下载地址失败，请重试');
          return;
        }
        let ok: boolean = DownloadManager.getInstance().retry(task.id, response.data.durl[0].url);
        if (!ok) {
          this.showToast('重试失败，请稍后再试');
        }
      }).catch(() => {
        this.retryingId = '';
        this.showToast('获取下载地址失败，请重试');
      });
  }

  /**
   * 删除二次确认（FR-008）
   */
  private confirmRemove(task: CacheTask): void {
    AlertDialog.show({
      title: '删除缓存',
      message: '确定删除该缓存视频吗？将同时清理本地文件。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#fb7299',
        action: () => {
          DownloadManager.getInstance().remove(task.id);
        }
      }
    });
  }

  private progressPercent(task: CacheTask): number {
    if (task.totalBytes <= 0) {
      return 0;
    }
    let percent: number = Math.floor(task.receivedBytes * 100 / task.totalBytes);
    if (percent > 100) {
      percent = 100;
    }
    return percent;
  }

  private statusText(task: CacheTask): string {
    if (task.status == CacheTaskStatus.DOWNLOADING) {
      return this.progressPercent(task) + '% · ' + this.formatBytes(task.receivedBytes)
        + '/' + this.formatBytes(task.totalBytes);
    }
    return '排队等待中';
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
