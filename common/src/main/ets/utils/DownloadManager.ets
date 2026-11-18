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

import { request } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { CacheTask, CacheTaskStatus } from '../model/CacheTask';
import { ApiConstants } from '../network/ApiConstants';
import { BLog } from './BLog';

/** 进度持久化阈值：累计新增字节数超过该值时落盘一次 */
const PERSIST_THRESHOLD_BYTES: number = 1024 * 1024;

/**
 * 串行下载管理器（单例）：
 * - @ohos.request.agent 单文件下载（header 带 UA+Referer）；
 * - App 层串行队列：同一时刻仅 1 个任务处于 DOWNLOADING；
 * - filesDir/offline/index.json 元数据持久化与启动恢复
 *   （校验文件存在性，DOWNLOADING 中断残留降级为 FAILED）；
 * - 任务状态/进度监听器注册注销（UI 刷新）；
 * - remove 删除任务并清理文件；getTotalSize 聚合存储占用。
 * 下载 URL 为临时签名链接不持久化，enqueue/retry 时由调用方传入。
 */
export class DownloadManager {
  private static instance: DownloadManager = null;
  private context: common.BaseContext = null;
  private filesDir: string = '';
  private tasks: CacheTask[] = [];
  /** taskId → 下载直链（内存态，签名链接会过期） */
  private urlMap: Map<string, string> = new Map();
  private listeners: Array<() => void> = [];
  private isDownloading: boolean = false;
  private currentTaskId: string = '';
  private currentAgentTid: string = '';
  private lastPersistedBytes: number = 0;
  private initialized: boolean = false;

  public static getInstance(): DownloadManager {
    if (DownloadManager.instance == null) {
      DownloadManager.instance = new DownloadManager();
    }
    return DownloadManager.instance;
  }

  private constructor() {
  }

  /**
   * 初始化并启动恢复：读 index.json 恢复任务列表；
   * COMPLETED 校验文件存在性，DOWNLOADING 中断残留降级为 FAILED。
   * 由 Ability onCreate 调用。
   */
  public init(context: common.BaseContext): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    this.context = context;
    let filesDir: string = globalThis.filesDir;
    if (filesDir == null || filesDir === '') {
      BLog.e("DownloadManager init: filesDir missing, restore skipped");
      return;
    }
    this.filesDir = filesDir;
    this.restore();
  }

  /**
   * 新任务入队（同 id 去重），触发串行调度
   */
  public enqueue(task: CacheTask, downloadUrl: string): boolean {
    if (task == null || task.id == null || task.id === '') {
      return false;
    }
    if (this.findTask(task.id) != null) {
      return false;
    }
    task.status = CacheTaskStatus.WAITING;
    if (task.createTime <= 0) {
      task.createTime = Math.floor(Date.now() / 1000);
    }
    this.tasks.unshift(task);
    this.urlMap.set(task.id, downloadUrl);
    this.persist();
    this.notifyChange();
    this.scheduleNext();
    return true;
  }

  /**
   * FAILED 任务重新入队（调用方负责刷新下载直链）
   */
  public retry(id: string, downloadUrl: string): boolean {
    let task: CacheTask = this.findTask(id);
    if (task == null || task.status == CacheTaskStatus.COMPLETED) {
      return false;
    }
    task.status = CacheTaskStatus.WAITING;
    task.receivedBytes = 0;
    this.urlMap.set(id, downloadUrl);
    this.persist();
    this.notifyChange();
    this.scheduleNext();
    return true;
  }

  /**
   * 删除任务并清理文件（FR-008 要求调用方 AlertDialog 二次确认）；
   * 若为当前下载任务则先停止下载。
   */
  public remove(id: string): void {
    let task: CacheTask = this.findTask(id);
    if (task == null) {
      return;
    }
    if (this.currentTaskId == id) {
      // 停止当前下载任务
      if (this.currentAgentTid !== '') {
        let tid: string = this.currentAgentTid;
        request.agent.remove(tid).then(() => {
          BLog.i("DownloadManager removed running agent task " + tid);
        }).catch(() => {
        });
      }
      this.currentTaskId = '';
      this.currentAgentTid = '';
      this.isDownloading = false;
    }
    // 清理视频目录（文件 + 目录）
    this.removeLocalFiles(task);
    let remain: CacheTask[] = [];
    this.tasks.forEach(item => {
      if (item.id != id) {
        remain.push(item);
      }
    });
    this.tasks = remain;
    this.urlMap.delete(id);
    this.persist();
    this.notifyChange();
    this.scheduleNext();
  }

  public getAllTasks(): CacheTask[] {
    return this.tasks;
  }

  public getTaskById(id: string): CacheTask {
    return this.findTask(id);
  }

  /**
   * 聚合存储占用：完成态计入 totalBytes，其余计入已接收字节
   */
  public getTotalSize(): number {
    let total: number = 0;
    this.tasks.forEach(task => {
      if (task.status == CacheTaskStatus.COMPLETED) {
        total += task.totalBytes;
      } else {
        total += task.receivedBytes;
      }
    });
    return total;
  }

  public registerListener(listener: () => void): void {
    this.listeners.push(listener);
  }

  public unregisterListener(listener: () => void): void {
    let remain: Array<() => void> = [];
    this.listeners.forEach(item => {
      if (item != listener) {
        remain.push(item);
      }
    });
    this.listeners = remain;
  }

  /**
   * 获取任务本地视频文件绝对路径（COMPLETED 时供本地播放）
   */
  public getLocalFilePath(task: CacheTask): string {
    return this.filesDir + '/' + task.localDir + '/' + task.fileName;
  }

  /**
   * 串行调度：同一时刻仅 1 个任务下载中
   */
  private scheduleNext(): void {
    if (this.isDownloading || this.context == null) {
      return;
    }
    let next: CacheTask = null;
    this.tasks.forEach(task => {
      if (next == null && task.status == CacheTaskStatus.WAITING) {
        next = task;
      }
    });
    if (next == null) {
      return;
    }
    let task: CacheTask = next;
    let url: string = this.urlMap.get(task.id) ?? '';
    if (url === '') {
      // 无下载直链（如重启后残留的 WAITING 任务）：直接置失败等待重试
      task.status = CacheTaskStatus.FAILED;
      this.persist();
      this.notifyChange();
      this.scheduleNext();
      return;
    }
    this.isDownloading = true;
    this.currentTaskId = task.id;
    task.status = CacheTaskStatus.DOWNLOADING;
    task.receivedBytes = 0;
    this.lastPersistedBytes = 0;
    this.persist();
    this.notifyChange();
    this.startDownload(task, url);
  }

  private async startDownload(task: CacheTask, url: string): Promise<void> {
    try {
      let dirPath: string = this.filesDir + '/' + task.localDir;
      // 目录准备 + 残留文件清理（重试场景覆盖旧文件）
      if (!fs.accessSync(dirPath)) {
        fs.mkdirSync(dirPath, true);
      }
      let filePath: string = dirPath + '/' + task.fileName;
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
      }
      let config: request.agent.Config = {
        action: request.agent.Action.DOWNLOAD,
        url: url,
        saveas: filePath,
        mode: request.agent.Mode.FOREGROUND,
        overwrite: true,
        network: request.agent.Network.ANY,
        gauge: true,
        headers: {
          'User-Agent': ApiConstants.userAgent,
          'Referer': ApiConstants.biliBase + '/'
        } as Record<string, string>
      };
      let agentTask: request.agent.Task = await request.agent.create(this.context, config);
      this.currentAgentTid = agentTask.tid;
      agentTask.on('progress', (progress: request.agent.Progress) => {
        this.onProgress(task, progress.processed, progress.sizes);
      });
      agentTask.on('completed', (progress: request.agent.Progress) => {
        this.onCompleted(task, progress.processed);
      });
      agentTask.on('failed', (progress: request.agent.Progress) => {
        this.onFailed(task, JSON.stringify(progress));
      });
      agentTask.start().catch((error: object) => {
        BLog.e("DownloadManager task start failed: " + JSON.stringify(error));
        this.onFailed(task, JSON.stringify(error));
      });
    } catch (error) {
      BLog.e("DownloadManager startDownload exception: " + JSON.stringify(error));
      this.onFailed(task, JSON.stringify(error));
    }
  }

  private onProgress(task: CacheTask, processed: number, sizes: Array<number>): void {
    task.receivedBytes = processed;
    if (sizes != null && sizes.length > 0 && sizes[0] > 0) {
      task.totalBytes = sizes[0];
    }
    if (processed - this.lastPersistedBytes >= PERSIST_THRESHOLD_BYTES) {
      this.lastPersistedBytes = processed;
      this.persist();
    }
    this.notifyChange();
  }

  private onCompleted(task: CacheTask, processed: number): void {
    BLog.i("DownloadManager task completed: " + task.id);
    task.receivedBytes = processed > 0 ? processed : task.totalBytes;
    task.totalBytes = task.receivedBytes;
    task.status = CacheTaskStatus.COMPLETED;
    this.finishCurrent(task);
  }

  private onFailed(task: CacheTask, reason: string): void {
    BLog.e("DownloadManager task failed: " + task.id + ", reason=" + reason);
    task.status = CacheTaskStatus.FAILED;
    this.finishCurrent(task);
  }

  private finishCurrent(task: CacheTask): void {
    this.currentTaskId = '';
    this.currentAgentTid = '';
    this.isDownloading = false;
    this.persist();
    this.notifyChange();
    this.scheduleNext();
  }

  private findTask(id: string): CacheTask {
    let found: CacheTask = null;
    this.tasks.forEach(task => {
      if (found == null && task.id == id) {
        found = task;
      }
    });
    return found;
  }

  /**
   * 启动恢复：读 index.json，校验文件存在性；
   * DOWNLOADING/WAITING 中断残留降级为 FAILED
   */
  private restore(): void {
    let indexPath: string = this.filesDir + '/offline/index.json';
    try {
      if (!fs.accessSync(indexPath)) {
        return;
      }
      let raw: string = fs.readTextSync(indexPath);
      if (raw == null || raw === '') {
        return;
      }
      let parsed: CacheTask[] = JSON.parse(raw) as CacheTask[];
      if (parsed == null || !Array.isArray(parsed)) {
        return;
      }
      let restored: CacheTask[] = [];
      parsed.forEach(item => {
        if (item == null || item.id == null || item.bvid == null) {
          return;
        }
        let task: CacheTask = new CacheTask();
        task.id = item.id;
        task.bvid = item.bvid;
        task.cid = item.cid ?? 0;
        task.aid = item.aid ?? 0;
        task.title = item.title ?? '';
        task.cover = item.cover ?? '';
        task.upName = item.upName ?? '';
        task.quality = item.quality ?? 0;
        task.qualityDesc = item.qualityDesc ?? '';
        task.receivedBytes = item.receivedBytes ?? 0;
        task.totalBytes = item.totalBytes ?? 0;
        task.localDir = item.localDir ?? '';
        task.fileName = item.fileName ?? '';
        task.createTime = item.createTime ?? 0;
        let status: CacheTaskStatus = item.status as CacheTaskStatus;
        if (status == CacheTaskStatus.COMPLETED) {
          // 完成态校验文件存在性，丢失则降级 FAILED
          let filePath: string = this.filesDir + '/' + task.localDir + '/' + task.fileName;
          if (fs.accessSync(filePath)) {
            task.status = CacheTaskStatus.COMPLETED;
          } else {
            task.status = CacheTaskStatus.FAILED;
          }
        } else if (status == CacheTaskStatus.DOWNLOADING
          || status == CacheTaskStatus.WAITING) {
          // 中断残留降级 FAILED，待用户重试
          task.status = CacheTaskStatus.FAILED;
        } else {
          task.status = CacheTaskStatus.FAILED;
        }
        restored.push(task);
      });
      this.tasks = restored;
      this.persist();
      BLog.i("DownloadManager restored " + restored.length + " cache tasks");
    } catch (error) {
      BLog.e("DownloadManager restore exception: " + JSON.stringify(error));
    }
  }

  /**
   * 元数据持久化到 filesDir/offline/index.json
   */
  private persist(): void {
    if (this.filesDir == null || this.filesDir === '') {
      return;
    }
    try {
      let offlineDir: string = this.filesDir + '/offline';
      if (!fs.accessSync(offlineDir)) {
        fs.mkdirSync(offlineDir, true);
      }
      let indexPath: string = offlineDir + '/index.json';
      let file: fs.File = fs.openSync(indexPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(this.tasks));
      fs.closeSync(file);
    } catch (error) {
      BLog.e("DownloadManager persist exception: " + JSON.stringify(error));
    }
  }

  /**
   * 清理任务本地文件（视频文件 + 目录）
   */
  private removeLocalFiles(task: CacheTask): void {
    try {
      let dirPath: string = this.filesDir + '/' + task.localDir;
      let filePath: string = dirPath + '/' + task.fileName;
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
      }
      if (fs.accessSync(dirPath)) {
        fs.rmdirSync(dirPath);
      }
    } catch (error) {
      BLog.w("DownloadManager removeLocalFiles exception: " + JSON.stringify(error));
    }
  }

  private notifyChange(): void {
    this.listeners.forEach(listener => {
      listener();
    });
  }
}
