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

import { BaseResponse } from './Response';

/**
 * 动态流响应（x/polymer/web-dynamic/v1/feed/all）
 */
export interface DynamicFeedResponse extends BaseResponse<DynamicFeedData> {
}

export interface DynamicFeedData {
  has_more?: boolean;
  offset?: string;
  items?: DynamicItem[];
}

export interface DynamicItem {
  id_str: string;
  modules?: DynamicModules;
}

export interface DynamicModules {
  module_author?: ModuleAuthor;
  module_dynamic?: ModuleDynamic;
  module_stat?: ModuleStat;
}

export interface ModuleAuthor {
  mid: number;
  name?: string;
  face?: string;
  pub_time?: string;
  pub_action?: string;
  /** 发布时间戳（秒），部分响应缺失 */
  pub_ts?: number;
}

export interface ModuleDynamic {
  desc?: DynamicDesc;
  major?: DynamicMajor;
  /** 转发动态的原动态（仅一层） */
  orig?: ModuleDynamic;
  /** 原动态作者（orig 内可能携带） */
  module_author?: ModuleAuthor;
  module_tag?: ModuleTag;
}

export interface ModuleTag {
  text?: string;
}

export interface DynamicDesc {
  text?: string;
  rich_text_nodes?: DynamicRichTextNode[];
}

export interface DynamicRichTextNode {
  type?: string;
  text?: string;
}

/**
 * 动态主体：按实际存在的类型对象分发渲染，不依赖 type 数字枚举
 */
export interface DynamicMajor {
  archive?: MajorArchive;
  draw?: MajorDraw;
  opus?: MajorOpus;
  article?: MajorArticle;
  pgc?: MajorPgc;
  ugc_season?: MajorUgcSeason;
  live?: MajorLive;
  /** 新版直播动态（content 为内嵌 JSON 字符串） */
  live_rcmd?: MajorLiveRcmd;
}

export interface MajorArchive {
  aid?: number;
  bvid?: string;
  title?: string;
  cover?: string;
  desc?: string;
  /** 形如 "10:30" 的时长文本 */
  duration_text?: string;
  stat?: MajorArchiveStat;
}

export interface MajorArchiveStat {
  aid?: number;
  view?: string;
  danmaku?: string;
}

/** 旧版图文动态主体 */
export interface MajorDraw {
  items?: MajorDrawItem[];
}

/**
 * 图文动态图片项：多字段命名兼容
 * draw.items 实际用 url/width/height（接口实测）；兼容旧 src 与 opus.pics 的 img_src/img_width/img_height
 */
export interface MajorDrawItem {
  url?: string;
  src?: string;
  img_src?: string;
  width?: number;
  img_width?: number;
  height?: number;
  img_height?: number;
}

/** 新版图文动态主体（opus） */
export interface MajorOpus {
  title?: OpusTitle;
  summary?: DynamicDesc;
  pics?: MajorDrawItem[];
}

export interface OpusTitle {
  text?: string;
}

export interface MajorArticle {
  id?: number;
  title?: string;
  desc?: string;
  covers?: string[];
}

export interface MajorPgc {
  title?: string;
  cover?: string;
  season_id?: number;
  epid?: number;
}

export interface MajorUgcSeason {
  title?: string;
  cover?: string;
}

export interface MajorLive {
  title?: string;
  cover?: string;
}

/** 新版直播动态外壳（content 为内嵌 JSON 字符串） */
export interface MajorLiveRcmd {
  content?: string;
}

/** live_rcmd.content 内嵌 JSON 的原始结构 */
interface LiveRcmdRaw {
  live_play_info?: LivePlayInfo;
}

/** 直播间信息（live_rcmd.content.live_play_info） */
export interface LivePlayInfo {
  title?: string;
  cover?: string;
  area_name?: string;
  /** 直播状态：0 未开播 / 1 直播中 / 2 轮播中 */
  live_status?: number;
}

/**
 * 解析新版直播动态（major.live_rcmd.content 内嵌 JSON 字符串）为直播信息；
 * major 不含 live_rcmd 或 content 非法时返回 null。
 */
export function parseLiveRcmdInfo(major: DynamicMajor | undefined): LivePlayInfo | null {
  if (major == null || major.live_rcmd == null || major.live_rcmd.content == null) {
    return null;
  }
  try {
    let raw: LiveRcmdRaw = JSON.parse(major.live_rcmd.content) as LiveRcmdRaw;
    if (raw != null && raw.live_play_info != null) {
      return raw.live_play_info;
    }
  } catch (error) {
    // content 非法 JSON 时按无直播信息处理
  }
  return null;
}

export interface ModuleStat {
  forward?: ModuleStatCount;
  comment?: ModuleStatCount;
  like?: ModuleStatCount;
}

export interface ModuleStatCount {
  count?: number;
}

/**
 * 动态流请求结果（ApiManager.requestDynamicFeed 返回值）
 */
export class DynamicFeedResult {
  success: boolean = false;
  /** 登录失效（业务码 -101） */
  loginExpired: boolean = false;
  hasMore: boolean = false;
  nextOffset: string = '';

  constructor(success: boolean, loginExpired: boolean, hasMore: boolean, nextOffset: string) {
    this.success = success;
    this.loginExpired = loginExpired;
    this.hasMore = hasMore;
    this.nextOffset = nextOffset;
  }
}

/** 取图文图片项的图片 URL（多字段命名兼容；协议相对 "//host/..." 与 "http://" 规范化为 HTTPS，保证 Image 可加载） */
export function getDrawItemUrl(item: MajorDrawItem): string {
  if (item == null) {
    return '';
  }
  let url: string = item.url ?? item.src ?? item.img_src ?? '';
  if (url.startsWith('//')) {
    return 'https:' + url;
  }
  if (url.startsWith('http://')) {
    return 'https://' + url.substring('http://'.length);
  }
  return url;
}

/** 取图文图片项的宽度（多字段命名兼容，缺省 0） */
export function getDrawItemWidth(item: MajorDrawItem): number {
  if (item == null) {
    return 0;
  }
  return item.width ?? item.img_width ?? 0;
}

/** 取图文图片项的高度（多字段命名兼容，缺省 0） */
export function getDrawItemHeight(item: MajorDrawItem): number {
  if (item == null) {
    return 0;
  }
  return item.height ?? item.img_height ?? 0;
}

/**
 * "mm:ss" / "hh:mm:ss" 时长文本转秒数；解析失败返回 0
 */
export function parseDurationTextToSeconds(text: string): number {
  if (text == null || text === '') {
    return 0;
  }
  let parts: string[] = text.split(':');
  if (parts.length < 2) {
    return 0;
  }
  let seconds: number = 0;
  for (let i = 0; i < parts.length; i++) {
    let value: number = parseInt(parts[i]);
    if (isNaN(value)) {
      return 0;
    }
    seconds = seconds * 60 + value;
  }
  return seconds;
}

/**
 * 计数文本转数字："1.2万" → 12000，"3" → 3，"1.5亿" → 150000000；解析失败返回 0
 */
export function parseCountTextToNumber(text: string): number {
  if (text == null || text === '') {
    return 0;
  }
  let trimmed: string = text.trim();
  if (trimmed.endsWith('万')) {
    let value: number = parseFloat(trimmed.substring(0, trimmed.length - 1));
    return isNaN(value) ? 0 : Math.round(value * 10000);
  }
  if (trimmed.endsWith('亿')) {
    let value: number = parseFloat(trimmed.substring(0, trimmed.length - 1));
    return isNaN(value) ? 0 : Math.round(value * 100000000);
  }
  let value: number = parseFloat(trimmed);
  return isNaN(value) ? 0 : Math.round(value);
}
