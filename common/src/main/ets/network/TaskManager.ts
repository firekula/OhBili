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
import { RelationStatResponse } from '../model/response/RelationStatResponse';
import { HasLikeResponse } from '../model/response/HasLikeResponse';
import { CoinCountResponse } from '../model/response/CoinCountResponse';
import { BangumiTimelineResponse } from '../model/response/BangumiTimelineResponse';
import { BangumiSeasonResponse } from '../model/response/BangumiSeasonResponse';
import { MyFollowBangumiResponse } from '../model/response/MyFollowBangumiResponse';
import { MsgFeedReplyResponse } from '../model/response/MsgFeedReplyResponse';
import { MsgFeedAtResponse } from '../model/response/MsgFeedAtResponse';
import { MsgFeedLikeResponse } from '../model/response/MsgFeedLikeResponse';
import { MsgFeedUnreadResponse } from '../model/response/MsgFeedUnreadResponse';
import { SysNoticeResponse } from '../model/response/SysNoticeResponse';

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

  async requestReply(cookie: string, oid: string, ps: number, next: number,
                                   type: number, sort: number): Promise<ApiResponse<ReplyResponse>> {
    var task = new taskPool.Task(requestReplyTask, cookie, oid, ps, next, type, sort);
    var response = await taskPool.execute(task) as ApiResponse<ReplyResponse>;
    return response;
  }

  async requestReplyDetail(cookie: string, oid: string, root: number, ps: number,
                                         pn: number, type: number): Promise<ApiResponse<ReplyDetailResponse>> {
    var task = new taskPool.Task(requestReplyDetailTask, cookie, oid, root, ps, pn, type);
    var response = await taskPool.execute(task) as ApiResponse<ReplyDetailResponse>;
    return response;
  }

  async requestReplyAction(cookie: string, oid: number, type: number, rpid: number,
                           action: number, csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(requestReplyActionTask, cookie, oid, type, rpid, action, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestReplyAdd(cookie: string, oid: number, type: number, root: number,
                        parent: number, message: string, csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(requestReplyAddTask, cookie, oid, type, root, parent, message, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestReplyDel(cookie: string, oid: number, type: number, rpid: number,
                        csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(requestReplyDelTask, cookie, oid, type, rpid, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
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

  async requestRelationStat(vmid: number): Promise<ApiResponse<RelationStatResponse>> {
    var task = new taskPool.Task(requestRelationStatTask, vmid);
    var response = await taskPool.execute(task) as ApiResponse<RelationStatResponse>;
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

  async likeVideo(cookie: string, aid: number, like: number,
                  csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(likeVideoTask, cookie, aid, like, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestHasLike(cookie: string, aid: number): Promise<ApiResponse<HasLikeResponse>> {
    var task = new taskPool.Task(requestHasLikeTask, cookie, aid);
    var response = await taskPool.execute(task) as ApiResponse<HasLikeResponse>;
    return response;
  }

  async coinVideo(cookie: string, aid: number, multiply: number, selectLike: number,
                  csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(coinVideoTask, cookie, aid, multiply, selectLike, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestCoinCount(cookie: string, aid: number): Promise<ApiResponse<CoinCountResponse>> {
    var task = new taskPool.Task(requestCoinCountTask, cookie, aid);
    var response = await taskPool.execute(task) as ApiResponse<CoinCountResponse>;
    return response;
  }

  async postDanmaku(cookie: string, oid: number, aid: number, msg: string,
                    progress: number, mode: number,
                    csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(postDanmakuTask, cookie, oid, aid, msg, progress, mode, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestBangumiTimeline(cookie: string, types: number): Promise<ApiResponse<BangumiTimelineResponse>> {
    var task = new taskPool.Task(requestBangumiTimelineTask, cookie, types);
    var response = await taskPool.execute(task) as ApiResponse<BangumiTimelineResponse>;
    return response;
  }

  async requestBangumiSeasonBySeasonId(cookie: string,
                                       seasonId: number): Promise<ApiResponse<BangumiSeasonResponse>> {
    var task = new taskPool.Task(requestBangumiSeasonBySeasonIdTask, cookie, seasonId);
    var response = await taskPool.execute(task) as ApiResponse<BangumiSeasonResponse>;
    return response;
  }

  async requestBangumiSeasonByEpId(cookie: string,
                                   epId: number): Promise<ApiResponse<BangumiSeasonResponse>> {
    var task = new taskPool.Task(requestBangumiSeasonByEpIdTask, cookie, epId);
    var response = await taskPool.execute(task) as ApiResponse<BangumiSeasonResponse>;
    return response;
  }

  async requestBangumiPlayUrl(cookie: string, epId: number, cid: number,
                              qn: number): Promise<ApiResponse<PlayUrlResponse>> {
    var task = new taskPool.Task(requestBangumiPlayUrlTask, cookie, epId, cid, qn);
    var response = await taskPool.execute(task) as ApiResponse<PlayUrlResponse>;
    return response;
  }

  async followBangumi(cookie: string, seasonId: number,
                      csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(followBangumiTask, cookie, seasonId, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async unfollowBangumi(cookie: string, seasonId: number,
                        csrf: string): Promise<ApiResponse<EmptyResponse>> {
    var task = new taskPool.Task(unfollowBangumiTask, cookie, seasonId, csrf);
    var response = await taskPool.execute(task) as ApiResponse<EmptyResponse>;
    return response;
  }

  async requestMyFollowBangumi(cookie: string, vmid: number, type: number, pn: number,
                               ps: number): Promise<ApiResponse<MyFollowBangumiResponse>> {
    var task = new taskPool.Task(requestMyFollowBangumiTask, cookie, vmid, type, pn, ps);
    var response = await taskPool.execute(task) as ApiResponse<MyFollowBangumiResponse>;
    return response;
  }

  async requestMsgFeedReply(cookie: string, id: number,
                            replyTime: string): Promise<ApiResponse<MsgFeedReplyResponse>> {
    var task = new taskPool.Task(requestMsgFeedReplyTask, cookie, id, replyTime);
    var response = await taskPool.execute(task) as ApiResponse<MsgFeedReplyResponse>;
    return response;
  }

  async requestMsgFeedAt(cookie: string, id: number,
                         atTime: string): Promise<ApiResponse<MsgFeedAtResponse>> {
    var task = new taskPool.Task(requestMsgFeedAtTask, cookie, id, atTime);
    var response = await taskPool.execute(task) as ApiResponse<MsgFeedAtResponse>;
    return response;
  }

  async requestMsgFeedLike(cookie: string, id: number,
                           likeTime: string): Promise<ApiResponse<MsgFeedLikeResponse>> {
    var task = new taskPool.Task(requestMsgFeedLikeTask, cookie, id, likeTime);
    var response = await taskPool.execute(task) as ApiResponse<MsgFeedLikeResponse>;
    return response;
  }

  async requestMsgFeedUnread(cookie: string): Promise<ApiResponse<MsgFeedUnreadResponse>> {
    var task = new taskPool.Task(requestMsgFeedUnreadTask, cookie);
    var response = await taskPool.execute(task) as ApiResponse<MsgFeedUnreadResponse>;
    return response;
  }

  async requestSysNotices(cookie: string, pageSize: number,
                          cursor: string): Promise<ApiResponse<SysNoticeResponse>> {
    var task = new taskPool.Task(requestSysNoticesTask, cookie, pageSize, cursor);
    var response = await taskPool.execute(task) as ApiResponse<SysNoticeResponse>;
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

async function requestReplyTask(cookie: string, oid: string, ps: number, next: number,
                                 type: number, sort: number): Promise<ApiResponse<ReplyResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: ReplyResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<ReplyResponse> = await dataService.getReply(cookie, oid, ps, next, type, sort);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestReplyDetailTask(cookie: string, oid: string, root: number, ps: number,
                                       pn: number, type: number): Promise<ApiResponse<ReplyDetailResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: ReplyDetailResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<ReplyDetailResponse> = await dataService.getReplyDetail(cookie, oid, root, ps, pn, type);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestReplyActionTask(cookie: string, oid: number, type: number, rpid: number,
                                      action: number, csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: EmptyResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    // 请求层 action 约定：0=取消赞 1=赞 2=踩 3=取消踩
    // 点赞/取消赞走 x/v2/reply/action（1/0）；点踩/取消踩走 x/v2/reply/hate（1/0）。
    // action 端点不接受 2，实测返回 12011「不合法的赞或踩」，host×UA 变体均无法绕过
    let resp: Response<EmptyResponse>;
    if (action === 2 || action === 3) {
      resp = await dataService.replyHate(cookie, oid, type, rpid, action === 2 ? 1 : 0, csrf);
    } else {
      resp = await dataService.replyAction(cookie, oid, type, rpid, action, csrf);
    }
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestReplyAddTask(cookie: string, oid: number, type: number, root: number,
                                   parent: number, message: string, csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0
  let errMsg: string = ""
  let result: EmptyResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    // retrofit buildURL 不做 URL 编码：中文/特殊字符内容需预编码后传参
    let resp: Response<EmptyResponse> = await dataService.replyAdd(cookie, oid, type, root,
      parent, encodeURIComponent(message), 1, csrf);
    code = resp.code();
    errMsg = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    errMsg = err + "";
  }
  return new ApiResponse(result, code, errMsg);
}

async function requestReplyDelTask(cookie: string, oid: number, type: number, rpid: number,
                                   csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0
  let message: string = ""
  let result: EmptyResponse
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.replyDel(cookie, oid, type, rpid, csrf);
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

async function requestRelationStatTask(vmid: number):
  Promise<ApiResponse<RelationStatResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: RelationStatResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<RelationStatResponse> = await dataService.getRelationStat(vmid);
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

async function likeVideoTask(cookie: string, aid: number, like: number,
                             csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.likeVideo(cookie, aid, like, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestHasLikeTask(cookie: string, aid: number):
  Promise<ApiResponse<HasLikeResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: HasLikeResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<HasLikeResponse> = await dataService.hasLike(cookie, aid);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function coinVideoTask(cookie: string, aid: number, multiply: number, selectLike: number,
                             csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.coinVideo(cookie, aid, multiply,
      selectLike, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestCoinCountTask(cookie: string, aid: number):
  Promise<ApiResponse<CoinCountResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: CoinCountResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<CoinCountResponse> = await dataService.getCoinCount(cookie, aid);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function postDanmakuTask(cookie: string, oid: number, aid: number, msg: string,
                               progress: number, mode: number,
                               csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    // retrofit buildURL 不做 URL 编码：弹幕内容需预编码后传参
    // 固定参数：白色(16777215)/字号 25/pool 0/plat 1
    let resp: Response<EmptyResponse> = await dataService.postDanmaku(cookie, oid, aid, 1,
      encodeURIComponent(msg), Math.floor(progress), 16777215, 25, mode, 0, 1, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestBangumiTimelineTask(cookie: string, types: number):
  Promise<ApiResponse<BangumiTimelineResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: BangumiTimelineResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<BangumiTimelineResponse> = await dataService.getBangumiTimeline(cookie,
      types, 3, 7);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestBangumiSeasonBySeasonIdTask(cookie: string, seasonId: number):
  Promise<ApiResponse<BangumiSeasonResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: BangumiSeasonResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<BangumiSeasonResponse> = await dataService.getBangumiSeasonBySeasonId(cookie,
      seasonId);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestBangumiSeasonByEpIdTask(cookie: string, epId: number):
  Promise<ApiResponse<BangumiSeasonResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: BangumiSeasonResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<BangumiSeasonResponse> = await dataService.getBangumiSeasonByEpId(cookie,
      epId);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestBangumiPlayUrlTask(cookie: string, epId: number, cid: number,
                                         qn: number): Promise<ApiResponse<PlayUrlResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: PlayUrlResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    // legacy html5/durl 链路：platform=html5&high_quality=1&fnval=0&fourk=1&try_look=1
    let resp: Response<PlayUrlResponse> = await dataService.getBangumiPlayUrl(cookie, epId,
      cid, qn, 'html5', 1, 0, 1, 1);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function followBangumiTask(cookie: string, seasonId: number,
                                 csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.followBangumi(cookie, seasonId, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function unfollowBangumiTask(cookie: string, seasonId: number,
                                   csrf: string): Promise<ApiResponse<EmptyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: EmptyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<EmptyResponse> = await dataService.unfollowBangumi(cookie, seasonId, csrf);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestMyFollowBangumiTask(cookie: string, vmid: number, type: number, pn: number,
                                          ps: number): Promise<ApiResponse<MyFollowBangumiResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: MyFollowBangumiResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<MyFollowBangumiResponse> = await dataService.getMyFollowBangumi(cookie,
      vmid, type, pn, ps);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestMsgFeedReplyTask(cookie: string, id: number,
                                       replyTime: string): Promise<ApiResponse<MsgFeedReplyResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: MsgFeedReplyResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<MsgFeedReplyResponse> = await dataService.getMsgFeedReply(cookie,
      0, 'web', 'web', id, replyTime);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestMsgFeedAtTask(cookie: string, id: number,
                                    atTime: string): Promise<ApiResponse<MsgFeedAtResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: MsgFeedAtResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<MsgFeedAtResponse> = await dataService.getMsgFeedAt(cookie,
      0, 'web', 'web', id, atTime);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestMsgFeedLikeTask(cookie: string, id: number,
                                      likeTime: string): Promise<ApiResponse<MsgFeedLikeResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: MsgFeedLikeResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<MsgFeedLikeResponse> = await dataService.getMsgFeedLike(cookie,
      0, 'web', 'web', id, likeTime);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestMsgFeedUnreadTask(cookie: string): Promise<ApiResponse<MsgFeedUnreadResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: MsgFeedUnreadResponse;
  let message: string = "";
  try {
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.apiBase)
      .build(DataService);
    let resp: Response<MsgFeedUnreadResponse> = await dataService.getMsgFeedUnread(cookie, 0, 'web');
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}

async function requestSysNoticesTask(cookie: string, pageSize: number,
                                     cursor: string): Promise<ApiResponse<SysNoticeResponse>> {
  "use concurrent"
  let code: number = 0;
  let result: SysNoticeResponse;
  let message: string = "";
  try {
    // 系统通知分域：message.bilibili.com
    let dataService = new ServiceBuilder()
      .setEndpoint(ApiConstants.messageBase)
      .build(DataService);
    let resp: Response<SysNoticeResponse> = await dataService.getSysNoticeList(cookie,
      pageSize, cursor);
    code = resp.code();
    message = resp.message();
    result = resp.result;
  } catch (err) {
    code = -1;
    message = err + "";
  }
  return new ApiResponse(result, code, message);
}