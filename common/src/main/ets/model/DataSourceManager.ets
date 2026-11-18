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
}