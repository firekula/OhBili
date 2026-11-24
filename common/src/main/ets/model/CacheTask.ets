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

/**
 * 离线缓存任务状态。
 * WAITING：已入队等待下载；DOWNLOADING：下载中；
 * COMPLETED：已完成；FAILED：失败（可重试）。
 */
export enum CacheTaskStatus {
  WAITING = 'WAITING',
  DOWNLOADING = 'DOWNLOADING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED'
}

/**
 * 离线缓存任务本地模型（DownloadManager 持久化到 filesDir/offline/index.json）。
 * id 为 bvid_cid_qn 唯一标识；localDir/fileName 为相对 filesDir 的存储位置；
 * 下载 URL 为临时签名链接，不持久化，重试时由调用方重新获取。
 * @Observed：下载进度原地更新时配合 @ObjectLink 行组件细粒度刷新（封面不重载）
 */
@Observed
export class CacheTask {
  public id: string = '';
  public bvid: string = '';
  public cid: number = 0;
  public aid: number = 0;
  public title: string = '';
  public cover: string = '';
  public upName: string = '';
  public quality: number = 0;
  public qualityDesc: string = '';
  public status: CacheTaskStatus = CacheTaskStatus.WAITING;
  public receivedBytes: number = 0;
  public totalBytes: number = 0;
  /** 相对 filesDir 的视频目录，如 offline/<id> */
  public localDir: string = '';
  public fileName: string = '';
  public createTime: number = 0;
}
