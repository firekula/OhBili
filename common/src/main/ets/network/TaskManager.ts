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

import axios from '@ohos/retrofit';
import taskPool from '@ohos.taskpool';
import http from '@ohos.net.http';
import { Response, ServiceBuilder } from '@ohos/retrofit';
import { DataService } from './Api';
import { RelatedResponse } from '../model/response/RelatedResponse';
import { RecommendResponse } from '../model/response/RecommendResponse';
import { PopularResponse } from '../model/response/PopularResponse';
import { PlayUrlResponse } from '../model/response/PlayUrlResponse';
import { ReplyResponse } from '../model/response/ReplyResponse';
import { ApiConstants } from './ApiConstants';
import { RankingResponse } from '../model/response/RankingResponse';
import { SearchResponse } from '../model/response/SearchResponse';
import { VideoPartsResponse } from '../model/response/VideoPartsResponse';
import { SearchDefaultResponse } from '../model/response/SearchDefaultResponse';
import { ReplyDetailResponse } from '../model/response/ReplyDetailResponse';
import { ApiResponse, EmptyResponse, StringResponse } from '../model/response/Response';
import { ArchiveStatResponse } from '../model/response/ArchiveStatResponse';
import { ViewResponse } from '../model/response/ViewResponse';
import { CountryListResponse } from '../model/response/GenericCountryListResponse';
import { SendSmsCaptchaResponse } from '../model/response/SendSmsCaptchaResponse';
import { SmsLoginResponse } from '../model/response/SmsLoginResponse';
import { CardInfoResponse } from '../model/response/UserCardInfoResponse';
import { NavResponse } from '../model/response/NavResponse';
import { FingerSpiResponse } from '../model/response/FingerSpiResponse';
import { QrCodeGenerateResponse } from '../model/response/QrCodeGenerateResponse';
import { QrPollResponse } from '../model/response/QrPollResponse';
import { CrossDomainResult } from '../model/response/CrossDomainResult';
import { DynamicFeedResponse } from '../model/response/DynamicFeedResponse';
import { SpaceAccInfoResponse } from '../model/response/SpaceAccInfoResponse';
import { SpaceArcSearchResponse } from '../model/response/SpaceArcSearchResponse';
import { SeriesArchivesResponse } from '../model/response/SeriesArchivesResponse';
import { HistoryResponse } from '../model/response/HistoryResponse';
import { FavFolderResponse } from '../model/response/FavFolderResponse';
import { FavResourceResponse } from '../model/response/FavResourceResponse';
import { WatchLaterResponse } from '../model/response/WatchLaterResponse';

export class TaskManager {
  public static getInstance(): TaskManager {
    if (globalThis.taskManager == null) {
      globalThis.taskManager = new TaskManager();
    }
    return globalThis.taskManager;
  }

  async requestRelated(bvid: string): Promise<ApiResponse<RelatedResponse>> {
    var task = new taskPool.Task(requestRelatedTask, bvid);
    var response = await taskPool.execute(task) as ApiResponse<RelatedResponse>;
    return response
  }

  async requestRecommend(cookie: string, ps: number, freshIdx1h: number, freshIdx4h: number,
                         freshIdx: number, freshType: number, feedVersion: string,
                         wRid: string, wts: string): Promise<ApiResponse<RecommendResponse>> {
    var task = new taskPool.Task(requestRecommendTask, cookie, ps, freshIdx1h, freshIdx4h,
      freshIdx, freshType, feedVersion, wRid, wts);
    var response = await taskPool.execute(task) as ApiResponse<RecommendResponse>;
    return response
  }

  async requestPopular(cookie: string, ps: number, pn: number): Promise<ApiResponse<PopularResponse>> {
    var task = new taskPool.Task(requestPopularTask, cookie, ps, pn);
    var response = await taskPool.execute(task) as ApiResponse<PopularResponse>;
    return response
  }

  async requestPlayUrl(bvid: string, cid: number): Promise<ApiResponse<PlayUrlResponse>> {
    var task = new taskPool.Task(requestPlayUrlTask, bvid, cid);
    var response = await taskPool.execute(task) as ApiResponse<PlayUrlResponse>;
    return response;
  }

  async requestReply(oid: string, ps: number, next: number,
                                  type: number, sort: number): Promise<ApiResponse<ReplyResponse>> {
    var task = new taskPool.Task(requestReplyTask, oid, ps, next, type, sort);
    var response = await taskPool.execute(task) as ApiResponse<ReplyResponse>;
    return response;
  }

  async requestReplyDetail(oid: string, root: number, ps: number,
                                        pn: number, type: number): Promise<ApiResponse<ReplyDetailResponse>> {
    var task = new taskPool.Task(requestReplyDetailTask, oid, root, ps, pn, type);
    var response = await taskPool.execute(task) as ApiResponse<ReplyDetailResponse>;
    return response;
  }


  async requestDmList(oid: number, type: number, index: number): Promise<ApiResponse<Uint8Array>> {
    var task = new taskPool.Task(requestDmListTask, oid, type, index);
    var response = await taskPool.execute(task) as ApiResponse<Uint8Array>;
    return response;
  }

  async requestRanking(): Promise<ApiResponse<RankingResponse>> {
    var task = new taskPool.Task(requestRankingTask);
    var response = await taskPool.execute(task) as ApiResponse<RankingResponse>;
    return response;
  }

  async requestSearch(cookies: string, type: string,
                                    keyword: string, pn: number,
                                    wRid: string, wts: string): Promise<ApiResponse<SearchResponse>> {
    var task = new taskPool.Task(requestSearchTask, cookies, type, keyword, pn, wRid, wts);
    var response = await taskPool.execute(task) as ApiResponse<SearchResponse>;
    return response;
  }

  async requestPageList(bvid: string): Promise<ApiResponse<VideoPartsResponse>> {
    var task = new taskPool.Task(requestPageListTask, bvid);
    var response = await taskPool.execute(task) as ApiResponse<VideoPartsResponse>;
    return response;
  }

  async requestSearchDefault(): Promise<ApiResponse<SearchDefaultResponse>> {
    var task = new taskPool.Task(requestSearchDefaultTask);
    var response = await taskPool.execute(task) as ApiResponse<SearchDefaultResponse>;
    return response;
  }

  async requestArchiveStat(bvid: string): Promise<ApiResponse<ArchiveStatResponse>> {
    var task = new taskPool.Task(requestArchiveStatTask, bvid);
    var response = await taskPool.execute(task) as ApiResponse<ArchiveStatResponse>;
    return response;
  }

  async requestArchiveDesc(bvid: string): Promise<ApiResponse<StringResponse>> {
    var task = new taskPool.Task(requestArchiveDescTask, bvid);
    var response = await taskPool.execute(task) as ApiResponse<StringResponse>;
    return response;
  }

  async requestGenericCountryList(): Promise<ApiResponse<CountryListResponse>> {
    var task = new taskPool.Task(requestGenericCountryListTask);
    var response = await taskPool.execute(task) as ApiResponse<CountryListResponse>;
    return response;
  }

  async SendSmsCaptcha(
    cid: number, tel: number, sessionId: string, captchaToken: string,
    geeChallenge: string, geeValidate: string, geeSecCode: string, channel: string, buvid: string,
    localId: string, statistics: string): Promise<ApiResponse<SendSmsCaptchaResponse>> {
    var task = new taskPool.Task(SendSmsCaptchaTask, cid, tel, sessionId, captchaToken,
      geeChallenge, geeValidate, geeSecCode, channel, buvid, localId, statistics);
    var response = await taskPool.execute(task) as ApiResponse<SendSmsCaptchaResponse>;
    return response;
  }

  async loginViaSmsCaptcha(cid: number, tel: number, sessionId: string,
                           _code: number, captchaKey: string): Promise<ApiResponse<SmsLoginResponse>> {
    var task = new taskPool.Task(loginViaSmsTask, cid, tel, sessionId, _code, captchaKey);
    var response = await taskPool.execute(task) as ApiResponse<SmsLoginResponse>;
    return response;
  }

  async requestUserCardInfo(mid: number, photo: boolean = false): Promise<ApiResponse<CardInfoResponse>> {
    var task = new taskPool.Task(requestUserCardInfoTask, mid, photo);
    var response = await taskPool.execute(task) as ApiResponse<CardInfoResponse>;
    return response;
  }

  async requestQrCodeGenerate(): Promise<ApiResponse<QrCodeGenerateResponse>> {
    var task = new taskPool.Task(requestQrCodeGenerateTask);
    var response = await taskPool.execute(task) as ApiResponse<QrCodeGenerateResponse>;
    return response;
  }

  async requestQrPoll(qrcodeKey: string): Promise<ApiResponse<QrPollResponse>> {
    var task = new taskPool.Task(requestQrPollTask, qrcodeKey);
    var response = await taskPool.execute(task) as ApiResponse<QrPollResponse>;
    return response;
  }

  async requestNavInfo(cookie: string): Promise<ApiResponse<NavResponse>> {
    var task = new taskPool.Task(requestNavInfoTask, cookie);
    var response = await taskPool.execute(task) as ApiResponse<NavResponse>;
    return response;
  }

  async requestFingerSpi(): Promise<ApiResponse<FingerSpiResponse>> {
    var task = new taskPool.Task(requestFingerSpiTask);
    var response = await taskPool.execute(task) as ApiResponse<FingerSpiResponse>;
    return response;
  }

  /**
   * ticket 型 crossDomain URL 换取登录 Cookie：
   * B站扫码轮询成功后返回的 url 若仅含 ticket（无 SESSDATA 参数），
   * 需 GET 该 url 并从 302 响应的 Set-Cookie 中提取登录 Cookie。
   */
  async exchangeCrossDomainTicket(url: string, cookie: string): Promise<CrossDomainResult> {
    var task = new taskPool.Task(exchangeCrossDomainTicketTask, url, cookie);
    var response = await taskPool.execute(task) as CrossDomainResult;
    return response;
  }

  async requestDynamicFeed(cookie: string, offset: string): Promise<ApiResponse<DynamicFeedResponse>> {
    var task = new taskPool.Task(requestDynamicFeedTask, cookie, offset);
    var response = await taskPool.execute(task) as ApiResponse<DynamicFeedResponse>;
    return response;
  }

  async requestSpaceAccInfo(cookie: string, mid: number, wRid: string, wts: string):
    Promise<ApiResponse<SpaceAccInfoResponse>> {
    var task = new taskPool.Task(requestSpaceAccInfoTask, cookie, mid, wRid, wts);
    var response = await taskPool.execute(task) as ApiResponse<SpaceAccInfoResponse>;
    return response;
  }

  async requestSpaceArcSearch(cookie: string, mid: number, pn: number, ps: number,
                               order: string, wRid: string, wts: string):
    Promise<ApiResponse<SpaceArcSearchResponse>> {
    var task = new taskPool.Task(requestSpaceArcSearchTask, cookie, mid, pn, ps, order, wRid, wts);
    var response = await taskPool.execute(task) as ApiResponse<SpaceArcSearchResponse>;
    return response;
  }

  async requestSeriesArchives(mid: number, pn: number, ps: number):
    Promise<ApiResponse<SeriesArchivesResponse>> {
    var task = new taskPool.Task(requestSeriesArchivesTask, mid, pn, ps);
    var response = await taskPool.execute(task) as ApiResponse<SeriesArchivesResponse>;
    return response;
  }

  async requestHistory(cookie: string, max: number, viewAt: number,
                       business: string):
    Promise<ApiResponse<HistoryResponse>> {
    var task = new taskPool.Task(requestHistoryTask, cookie, max, viewAt, business);
    var response = await taskPool.execute(task) as ApiResponse<HistoryResponse>;
    return response;
  }

  async deleteHistory(cookie: string, kid: string, csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(deleteHistoryTask, cookie, kid, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async clearHistory(cookie: string, csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(clearHistoryTask, cookie, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestFavFolders(cookie: string, upMid: number, rid: number,
                          type: number): Promise<ApiResponse<FavFolderResponse>> {
    var task = new taskPool.Task(requestFavFoldersTask, cookie, upMid, rid, type);
    var response = await taskPool.execute(task) as ApiResponse<FavFolderResponse>;
    return response;
  }

  async requestFavResources(cookie: string, mediaId: number, pn: number, ps: number,
                            keyword: string, order: string, type: number, tid: number,
                            platform: string): Promise<ApiResponse<FavResourceResponse>> {
    var task = new taskPool.Task(requestFavResourcesTask, cookie, mediaId, pn, ps,
      keyword, order, type, tid, platform);
    var response = await taskPool.execute(task) as ApiResponse<FavResourceResponse>;
    return response;
  }

  async favDeal(cookie: string, rid: number, type: number, addMediaIds: string,
                delMediaIds: string, csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(favDealTask, cookie, rid, type, addMediaIds, delMediaIds, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestWatchLater(cookie: string): Promise<ApiResponse<WatchLaterResponse>> {
    var task = new taskPool.Task(requestWatchLaterTask, cookie);
    var response = await taskPool.execute(task) as ApiResponse<WatchLaterResponse>;
    return response;
  }

  async addWatchLater(cookie: string, aid: number, csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(addWatchLaterTask, cookie, aid, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async removeWatchLater(cookie: string, aid: number, csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(removeWatchLaterTask, cookie, aid, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestPlayUrlWithQn(cookie: string, bvid: string, cid: number,
                             qn: number): Promise<ApiResponse<PlayUrlResponse>> {
    var task = new taskPool.Task(requestPlayUrlWithQnTask, cookie, bvid, cid, qn);
    var response = await taskPool.execute(task) as ApiResponse<PlayUrlResponse>;
    return response;
  }
}

/**
 * 以浏览器上下文 GET crossDomain URL（跟随重定向 + 实例级自动 Cookie）。
 * netstack 的 maxRedirects:0 语义是"遇到 302 抛 2300047"而非返回 302 响应，
 * 故改用默认跟随重定向：302 的 Set-Cookie 由 netstack 按域名规则自动携带，
 * 并累积进 response.cookies（enableAutoCookie，API 26）。
 * cookieParams 不在此填充（并发函数仅允许引用导入变量），
 * 由主线程调用 parseCrossDomainResultCookies() 解析。
 */
async function exchangeCrossDomainTicketTask(url: string, cookie: string): Promise<CrossDomainResult> {
  "use concurrent"
  let result: CrossDomainResult = new CrossDomainResult();
  let httpRequest = http.createHttp();
  try {
    // 开启实例级 Cookie 自动携带：302 的 Set-Cookie 自动带到重定向目标
    httpRequest.enableAutoCookie(true);
    let options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: {
        'User-Agent': ApiConstants.userAgent,
        'Referer': 'https://passport.bilibili.com/',
        'Cookie': cookie
      },
      // 跟随重定向（默认 30 次），Set-Cookie 在链路中被 netstack 捕获
      connectTimeout: 10000,
      readTimeout: 10000
    };
    let response = await httpRequest.request(url, options);
    result.responseCode = response.responseCode;
    result.cookiesField = response.cookies ?? '';
    let header = response.header as Record<string, Object>;
    let loc: Object = header['location'] ?? header['Location'];
    if (typeof loc === 'string') {
      result.location = loc;
    }
    let setCookie: Object = header['set-cookie'] ?? header['Set-Cookie'];
    if (typeof setCookie === 'string') {
      result.setCookieRaw = setCookie;
    } else if (Array.isArray(setCookie)) {
      let arr: Object[] = setCookie as Object[];
      let lines: string[] = [];
      for (let i = 0; i < arr.length; i++) {
        lines.push(arr[i] as string);
      }
      result.setCookieRaw = lines.join('\n');
    }
    if (typeof response.result === 'string') {
      result.bodySnippet = (response.result as string).substring(0, 300);
    }
  } catch (err) {
    result.errorMessage = JSON.stringify(err);
  } finally {
    httpRequest.destroy();
  }
  return result;
}

async function requestRelatedTask(bvid: string): Promise<ApiResponse<RelatedResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: RelatedResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<RelatedResponse> = await dataService.getRelated(bvid);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestRecommendTask(cookie: string, ps: number, freshIdx1h: number, freshIdx4h: number,
                                    freshIdx: number, freshType: number, feedVersion: string,
                                    wRid: string, wts: string): Promise<ApiResponse<RecommendResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: RecommendResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<RecommendResponse> = await dataService.getRecommend(cookie, ps,
      freshIdx1h, freshIdx4h, freshIdx, freshType, feedVersion, wRid, wts);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
    console.error("OhBili err:" + err);
  }
  return new ApiResponse(result, code, message);
}

async function requestPopularTask(cookie: string, ps: number, pn: number): Promise<ApiResponse<PopularResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: PopularResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<PopularResponse> = await dataService.getPopular(cookie, ps, pn);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestPlayUrlTask(bvid: string, cid: number): Promise<ApiResponse<PlayUrlResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: PlayUrlResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<PlayUrlResponse> = await dataService.getPlayUrl(bvid, cid);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestReplyTask(oid: string, ps: number, next: number,
                                type: number, sort: number): Promise<ApiResponse<ReplyResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: ReplyResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<ReplyResponse> = await dataService.getReply(oid, ps, next, type, sort);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestReplyDetailTask(oid: string, root: number, ps: number,
                                      pn: number, type: number): Promise<ApiResponse<ReplyDetailResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: ReplyDetailResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<ReplyDetailResponse> = await dataService.getReplyDetail(oid, root, ps, pn, type);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}


async function requestDmListTask(oid: number, type: number, index: number): Promise<ApiResponse<Uint8Array>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: Uint8Array
  try {
    let res = await axios({
      method: "get",
      url: 'https://api.bilibili.com/x/v2/dm/list/seg.so',
      headers: { 'Content-Type': 'application/octet-stream' },
      params: {
        oid: oid,
        type: type,
        segment_index: index
      }
    });
    result = new Uint8Array(res.data);
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestRankingTask(): Promise<ApiResponse<RankingResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: RankingResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.appBase)
      .build(DataService);
    let resp: Response<RankingResponse> = await dataService.getRanking();
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestSearchTask(cookies: string, type: string,
                                 keyword: string, pn: number,
                                 wRid: string, wts: string): Promise<ApiResponse<SearchResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: SearchResponse
  try {
    console.log("OhBiliSearch task enter, keyword=" + keyword + ", pn=" + pn);
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<SearchResponse> = await dataService.getSearch(cookies, type, keyword, pn, wRid, wts);
    console.log("OhBiliSearch task resp, status=" + resp.code() + ", msg=" + resp.message());
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    console.log("OhBiliSearch task err: " + err);
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestPageListTask(bvid: string): Promise<ApiResponse<VideoPartsResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: VideoPartsResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<VideoPartsResponse> = await dataService.getPageList(bvid);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestSearchDefaultTask(): Promise<ApiResponse<SearchDefaultResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: SearchDefaultResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<SearchDefaultResponse> = await dataService.getSearchDefault();
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestArchiveStatTask(bvid: string): Promise<ApiResponse<ArchiveStatResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: ArchiveStatResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    // 旧端点 x/web-interface/archive/stat 已下线（412/404），
    // 改经 x/web-interface/view 取详情，映射 data.stat 为原 ArchiveStatResponse 结构（含 aid/reply）
    let resp: Response<ViewResponse> = await dataService.getVideoView(bvid);
    code = resp.code();
    message = resp.message();
    let body: ViewResponse = resp.result;
    if (body != null && body.data != null && body.data.stat != null) {
      let wrapped: ArchiveStatResponse = {
        code: body.code,
        message: body.message,
        ttl: body.ttl,
        data: body.data.stat
      };
      result = wrapped;
    }
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestArchiveDescTask(bvid: string): Promise<ApiResponse<StringResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: StringResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<StringResponse> = await dataService.getArchiveDesc(bvid);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestGenericCountryListTask(): Promise<ApiResponse<CountryListResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: CountryListResponse;
  let message: string = "0";
  try{
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.loginBase)
      .build(DataService);
    let resp: Response<CountryListResponse> = await dataService.getGenericCountryList();
    code = resp.code();
    result = resp.result;
  }catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function SendSmsCaptchaTask(
  cid: number, tel: number, sessionId: string, captchaToken: string,
  geeChallenge: string, geeValidate: string, geeSecCode: string, channel: string, buvid: string,
  localId: string, statistics: string
): Promise<ApiResponse<SendSmsCaptchaResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: SendSmsCaptchaResponse;
  let message: string = "";
  try{
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.loginBase)
      .build(DataService);
    let resp: Response<SendSmsCaptchaResponse> = await dataService.sendSmsCaptcha(
      cid, tel, sessionId, captchaToken, geeChallenge, geeValidate, geeSecCode, channel, buvid,
      localId, statistics);
    code = resp.code();
    result = resp.result;
  }catch(err){
    code = -1;
    message = err+"";
  }
  return new ApiResponse(result, code, message);
}

async function loginViaSmsTask(
  cid: number, tel: number, sessionId: string,
  _code: number, captchaKey: string
): Promise<ApiResponse<SmsLoginResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: SmsLoginResponse;
  let message: string = "";
  try{
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.loginBase)
      .build(DataService);
    let resp: Response<SmsLoginResponse> = await dataService.loginViaSmsCaptcha(
      cid, tel, sessionId, _code, captchaKey
    );
    code = resp.code();
    result = resp.result;
  }catch (err) {
    code = -1;
    message = err+"";
  }
  return new ApiResponse(result, code, message);
}

async function requestUserCardInfoTask(mid: number, photo: boolean = false): Promise<ApiResponse<CardInfoResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: CardInfoResponse;
  let message: string = "";
  try{
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<CardInfoResponse> = await dataService.getUserCardInfo(mid, photo);
    code = resp.code();
    result = resp.result;
  }catch (err) {
    code = -1;
    message = err+"";
  }
  return new ApiResponse(result, code, message);
}

async function requestQrCodeGenerateTask(): Promise<ApiResponse<QrCodeGenerateResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: QrCodeGenerateResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.loginBase)
      .build(DataService);
    let resp: Response<QrCodeGenerateResponse> = await dataService.generateQrCode();
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestQrPollTask(qrcodeKey: string): Promise<ApiResponse<QrPollResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: QrPollResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.loginBase)
      .build(DataService);
    let resp: Response<QrPollResponse> = await dataService.pollQrCode(qrcodeKey);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestNavInfoTask(cookie: string): Promise<ApiResponse<NavResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: NavResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<NavResponse> = await dataService.getNavInfo(cookie);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestFingerSpiTask(): Promise<ApiResponse<FingerSpiResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: FingerSpiResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<FingerSpiResponse> = await dataService.getFingerSpi();
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestDynamicFeedTask(cookie: string, offset: string):
  Promise<ApiResponse<DynamicFeedResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: DynamicFeedResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<DynamicFeedResponse> = await dataService.getDynamicFeed(cookie, -480, offset, 'itemOpusStyle');
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestSpaceAccInfoTask(cookie: string, mid: number, wRid: string, wts: string):
  Promise<ApiResponse<SpaceAccInfoResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: SpaceAccInfoResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<SpaceAccInfoResponse> = await dataService.getSpaceAccInfo(cookie, mid, wRid, wts);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestSpaceArcSearchTask(cookie: string, mid: number, pn: number, ps: number,
                                          order: string, wRid: string, wts: string):
  Promise<ApiResponse<SpaceArcSearchResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: SpaceArcSearchResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<SpaceArcSearchResponse> =
      await dataService.getSpaceArcSearch(cookie, mid, pn, ps, order, wRid, wts);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestSeriesArchivesTask(mid: number, pn: number, ps: number):
  Promise<ApiResponse<SeriesArchivesResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: SeriesArchivesResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<SeriesArchivesResponse> = await dataService.getSeriesArchives(mid, '', ps, pn);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestHistoryTask(cookie: string, max: number, viewAt: number,
                                  business: string):
  Promise<ApiResponse<HistoryResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: HistoryResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<HistoryResponse> = await dataService.getHistory(cookie, max, viewAt,
      business);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function deleteHistoryTask(cookie: string, kid: string, csrf: string):
  Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.deleteHistory(cookie, kid, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function clearHistoryTask(cookie: string, csrf: string):
  Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.clearHistory(cookie, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestFavFoldersTask(cookie: string, upMid: number, rid: number,
                                     type: number): Promise<ApiResponse<FavFolderResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: FavFolderResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<FavFolderResponse> = await dataService.getFavFolders(cookie, upMid,
      rid, type);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestFavResourcesTask(cookie: string, mediaId: number, pn: number, ps: number,
                                       keyword: string, order: string, type: number, tid: number,
                                       platform: string): Promise<ApiResponse<FavResourceResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: FavResourceResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<FavResourceResponse> = await dataService.getFavResources(cookie, mediaId,
      pn, ps, keyword, order, type, tid, platform);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function favDealTask(cookie: string, rid: number, type: number, addMediaIds: string,
                           delMediaIds: string, csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.favDeal(cookie, rid, type,
      addMediaIds, delMediaIds, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestWatchLaterTask(cookie: string): Promise<ApiResponse<WatchLaterResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: WatchLaterResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<WatchLaterResponse> = await dataService.getWatchLater(cookie);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function addWatchLaterTask(cookie: string, aid: number, csrf: string):
  Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.addWatchLater(cookie, aid, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function removeWatchLaterTask(cookie: string, aid: number, csrf: string):
  Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.removeWatchLater(cookie, aid, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestPlayUrlWithQnTask(cookie: string, bvid: string, cid: number,
                                        qn: number): Promise<ApiResponse<PlayUrlResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: PlayUrlResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    // platform=html5&high_quality=1&fnval=0：返回 mp4 durl（含 size）+ accept_quality 档位表
    let resp: Response<PlayUrlResponse> = await dataService.getPlayUrlWithQn(cookie, bvid, cid,
      qn, 'html5', 1, 0);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}