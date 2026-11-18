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

import { VideoDataSource } from './VideoDataSource';
import { ReplyDataSource } from './ReplyDataSource';
import { SearchDataSource } from './SearchDataSource';
import { BasicDataSource } from './BasicDataSource';
import { DynamicItem } from './response/DynamicFeedResponse';
import { SpaceArcItem } from './response/SpaceArcSearchResponse';
import { HistoryItem } from './response/HistoryResponse';
import { FavMedia } from './response/FavResourceResponse';
import { WatchLaterItem } from './response/WatchLaterResponse';

/**
 * 动态流数据源（LazyForEach 消费）
 */
export class DynamicDataSource extends BasicDataSource {
  private dataArray: DynamicItem[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): any {
    return this.dataArray[index];
  }

  public getAllData(): DynamicItem[] {
    return this.dataArray;
  }

  public setData(data: DynamicItem[]): void {
    this.dataArray.splice(0);
    this.addAllData(data);
  }

  public addAllData(data: DynamicItem[]): void {
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }

  public pushData(data: DynamicItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }
}

/**
 * 用户空间投稿列表数据源（按 mid 实例隔离）
 */
export class SpaceArcDataSource extends BasicDataSource {
  private dataArray: SpaceArcItem[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): any {
    return this.dataArray[index];
  }

  public getAllData(): SpaceArcItem[] {
    return this.dataArray;
  }

  public setData(data: SpaceArcItem[]): void {
    this.dataArray.splice(0);
    this.addAllData(data);
  }

  public addAllData(data: SpaceArcItem[]): void {
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }

  public pushData(data: SpaceArcItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }
}

/**
 * 历史记录数据源（云端历史列表，LazyForEach 消费）
 */
export class HistoryDataSource extends BasicDataSource {
  private dataArray: HistoryItem[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): any {
    return this.dataArray[index];
  }

  public getAllData(): HistoryItem[] {
    return this.dataArray;
  }

  public setData(data: HistoryItem[]): void {
    this.dataArray.splice(0);
    this.addAllData(data);
  }

  public addAllData(data: HistoryItem[]): void {
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }

  public pushData(data: HistoryItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public deleteData(index: number): void {
    if (index >= 0 && index < this.dataArray.length) {
      this.dataArray.splice(index, 1);
      this.notifyDataDelete(index);
    }
  }
}

/**
 * 收藏夹内容数据源（按收藏夹 media_id 实例隔离）
 */
export class FavMediaDataSource extends BasicDataSource {
  private dataArray: FavMedia[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): any {
    return this.dataArray[index];
  }

  public getAllData(): FavMedia[] {
    return this.dataArray;
  }

  public setData(data: FavMedia[]): void {
    this.dataArray.splice(0);
    this.addAllData(data);
  }

  public addAllData(data: FavMedia[]): void {
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }

  public pushData(data: FavMedia): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public deleteData(index: number): void {
    if (index >= 0 && index < this.dataArray.length) {
      this.dataArray.splice(index, 1);
      this.notifyDataDelete(index);
    }
  }
}

/**
 * 稍后再看数据源（全量单页，LazyForEach 消费）
 */
export class WatchLaterDataSource extends BasicDataSource {
  private dataArray: WatchLaterItem[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): any {
    return this.dataArray[index];
  }

  public getAllData(): WatchLaterItem[] {
    return this.dataArray;
  }

  public setData(data: WatchLaterItem[]): void {
    this.dataArray.splice(0);
    this.addAllData(data);
  }

  public addAllData(data: WatchLaterItem[]): void {
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }

  public pushData(data: WatchLaterItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public deleteData(index: number): void {
    if (index >= 0 && index < this.dataArray.length) {
      this.dataArray.splice(index, 1);
      this.notifyDataDelete(index);
    }
  }
}

export class DataSourceManager {
  public static initData() {
    globalThis.recommendSource = new VideoDataSource();
    globalThis.popularSource = new VideoDataSource();
    globalThis.relatedMapSource = new Map<string, VideoDataSource>();
    globalThis.replyMapSource = new Map<string, ReplyDataSource>();
    globalThis.replyDetailSource = new ReplyDataSource();
    globalThis.searchSource = new SearchDataSource();
    globalThis.dynamicSource = new DynamicDataSource();
    globalThis.spaceArcMapSource = new Map<string, SpaceArcDataSource>();
    globalThis.historySource = new HistoryDataSource();
    globalThis.favMediaMapSource = new Map<string, FavMediaDataSource>();
    globalThis.watchLaterSource = new WatchLaterDataSource();
  }

  public static getRecommendSource(): VideoDataSource {
    if (globalThis.recommendSource != undefined) {
      return globalThis.recommendSource;
    }
    return new VideoDataSource();
  }

  public static getPopularSource(): VideoDataSource {
    if (globalThis.popularSource != undefined) {
      return globalThis.popularSource;
    }
    return new VideoDataSource();
  }

  public static setRelatedMapSource(key: string) {
    if (globalThis.relatedMapSource != undefined) {
      globalThis.relatedMapSource.set(key, new VideoDataSource());
    }
  }

  public static deleteRelatedMapSource(key: string) {
    if (globalThis.relatedMapSource != undefined) {
      globalThis.relatedMapSource.delete(key);
    }
  }

  public static getRelatedSource(key?: string): VideoDataSource {
    if (key != null && globalThis.relatedMapSource != undefined &&
    globalThis.relatedMapSource.has(key)) {
      return globalThis.relatedMapSource.get(key);
    }
    return new VideoDataSource();
  }

  public static setReplyMapSource(key: string) {
    if (globalThis.replyMapSource != undefined) {
      globalThis.replyMapSource.set(key, new ReplyDataSource());
    }
  }

  public static deleteReplyMapSource(key: string) {
    if (globalThis.replyMapSource != undefined) {
      globalThis.replyMapSource.delete(key);
    }
  }

  public static getReplySource(key?: string): ReplyDataSource {
    if (key != null && globalThis.replyMapSource != undefined &&
    globalThis.replyMapSource.has(key)) {
      return globalThis.replyMapSource.get(key);
    }
    return new ReplyDataSource();
  }

  public static getReplyDetailSource(): ReplyDataSource {
    if (globalThis.replyDetailSource != undefined) {
      return globalThis.replyDetailSource;
    }
    return new ReplyDataSource();
  }

  public static getSearchSource(): SearchDataSource {
    if (globalThis.searchSource != undefined) {
      return globalThis.searchSource;
    }
    return new SearchDataSource();
  }

  public static getDynamicSource(): DynamicDataSource {
    if (globalThis.dynamicSource != undefined) {
      return globalThis.dynamicSource;
    }
    return new DynamicDataSource();
  }

  /**
   * 获取指定用户的投稿列表数据源：不存在时自动创建并缓存（按 mid 实例隔离）
   */
  public static getSpaceArcSource(mid: string): SpaceArcDataSource {
    if (globalThis.spaceArcMapSource == undefined) {
      globalThis.spaceArcMapSource = new Map<string, SpaceArcDataSource>();
    }
    let mapSource: Map<string, SpaceArcDataSource> = globalThis.spaceArcMapSource;
    if (mapSource.has(mid)) {
      return mapSource.get(mid);
    }
    let source: SpaceArcDataSource = new SpaceArcDataSource();
    mapSource.set(mid, source);
    return source;
  }

  /**
   * 清理指定用户的投稿列表数据源（空间页退出时调用）
   */
  public static deleteSpaceArcSource(mid: string): void {
    if (globalThis.spaceArcMapSource != undefined) {
      globalThis.spaceArcMapSource.delete(mid);
    }
  }

  public static getHistorySource(): HistoryDataSource {
    if (globalThis.historySource != undefined) {
      return globalThis.historySource;
    }
    return new HistoryDataSource();
  }

  /**
   * 获取指定收藏夹的内容数据源：不存在时自动创建并缓存（按 media_id 实例隔离）
   */
  public static getFavMediaSource(mediaId: string): FavMediaDataSource {
    if (globalThis.favMediaMapSource == undefined) {
      globalThis.favMediaMapSource = new Map<string, FavMediaDataSource>();
    }
    let mapSource: Map<string, FavMediaDataSource> = globalThis.favMediaMapSource;
    if (mapSource.has(mediaId)) {
      return mapSource.get(mediaId);
    }
    let source: FavMediaDataSource = new FavMediaDataSource();
    mapSource.set(mediaId, source);
    return source;
  }

  /**
   * 清理指定收藏夹的内容数据源（收藏夹内容页退出时调用）
   */
  public static deleteFavMediaSource(mediaId: string): void {
    if (globalThis.favMediaMapSource != undefined) {
      globalThis.favMediaMapSource.delete(mediaId);
    }
  }

  public static getWatchLaterSource(): WatchLaterDataSource {
    if (globalThis.watchLaterSource != undefined) {
      return globalThis.watchLaterSource;
    }
    return new WatchLaterDataSource();
  }
}