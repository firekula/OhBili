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

import { BasicDataSource } from '../../model/BasicDataSource';

/**
 * 消息中心统一展示模型：
 * 回复/@我/收到的赞/系统通知 四流归一（字段名不确定风险 R1 隔离在页面转换层）
 */
export interface MessageEntry {
  /** 列表 key（消息 id） */
  key: string
  /** 头像（系统通知为封面，空串用占位图） */
  avatar: string
  /** 主标题（用户名/通知标题） */
  title: string
  /** 秒级时间戳（0=不显示时间） */
  time: number
  /** 消息摘要（回复内容/@内容/点赞对象/通知内容） */
  summary: string
  /** 来源标题（被回复的我的内容/视频标题等） */
  sourceTitle: string
  /** 跳转目标：可解析出 bvid 时跳视频页，空串不可跳 */
  bvid: string
}

/**
 * 消息中心列表数据源（LazyForEach + 游标分页）
 */
export class MessageFeedDataSource extends BasicDataSource {
  private dataArray: MessageEntry[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): MessageEntry {
    return this.dataArray[index];
  }

  public getAllData(): MessageEntry[] {
    return this.dataArray;
  }

  public setData(data: MessageEntry[]): void {
    this.dataArray.splice(0);
    this.addAllData(data);
  }

  public addAllData(data: MessageEntry[]): void {
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }

  public appendData(data: MessageEntry[]): void {
    if (data.length == 0) {
      return;
    }
    data.forEach(item => {
      this.dataArray.push(item);
    })
    this.notifyDataReload();
  }
}
