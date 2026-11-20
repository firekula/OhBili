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
 * 首页随机推荐视频数据源
 */

import { BasicDataSource } from './BasicDataSource';
import { ReplyItem } from './response/ReplyResponse';

export class ReplyDataSource extends BasicDataSource {
  private dataArray: ReplyItem[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): any {
    return this.dataArray[index];
  }

  public getAllData(): ReplyItem[] {
    return this.dataArray;
  }

  public addData(index: number, data: ReplyItem): void {
    this.dataArray.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public setData(data: ReplyItem[]): void {
    this.dataArray.splice(0);
    this.addAllData(data);
  }

  public addAllData(data: ReplyItem[]): void {
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }

  public pushData(data: ReplyItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  /**
   * 按对象引用移除一条评论（删除自己的评论用），未命中返回 false
   */
  public removeData(data: ReplyItem): boolean {
    const idx: number = this.dataArray.indexOf(data);
    if (idx < 0) {
      return false;
    }
    this.dataArray.splice(idx, 1);
    this.notifyDataDelete(idx);
    return true;
  }
}