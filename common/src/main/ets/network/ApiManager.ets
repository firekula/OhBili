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

import protobuf from '@ohos/protobufjs'
import { PlayUrlResponse } from '../model/response/PlayUrlResponse';
import { ProtoSource } from '../model/proto/ProtoSource'
import { RankingResponse } from '../model/response/RankingResponse';
import { VideoPartsResponse } from '../model/response/VideoPartsResponse';
import { DataSourceManager } from '../model/DataSourceManager';
import { TaskManager } from './TaskManager';
import { CrossDomainResult, parseCrossDomainResultCookies } from '../model/response/CrossDomainResult';
import { BLog } from '../utils/BLog';
import { ReplyCursor } from '../model/response/ReplyResponse';
import { ReplyPage } from '../model/response/ReplyDetailResponse';
import { ArchiveStatResponse } from '../model/response/ArchiveStatResponse';
import { ApiConstants } from './ApiConstants';
import { CountryList, CountryListResponse } from '../model/response/GenericCountryListResponse';
import { SmsLoginResponse } from '../model/response/SmsLoginResponse';
import { SendSmsCaptchaResponse } from '../model/response/SendSmsCaptchaResponse';
import { CardInfoResponse } from '../model/response/UserCardInfoResponse';
import { QrCodeData, QrCodeGenerateResponse } from '../model/response/QrCodeGenerateResponse';
import { ApiResponse } from '../model/response/Response';
import { SearchResponse } from '../model/response/SearchResponse';
import { QrPollResponse } from '../model/response/QrPollResponse';
import { NavData, NavResponse } from '../model/response/NavResponse';
import { FingerSpiResponse } from '../model/response/FingerSpiResponse';
import { LoginHelper } from '../utils/LoginHelper';
import { WbiSigner } from '../utils/WbiSigner';
import { StringUtil } from '../utils/StringUtil';
import { DynamicFeedResult, DynamicItem } from '../model/response/DynamicFeedResponse';
import { SpaceUserProfile } from '../model/response/SpaceAccInfoResponse';
import { SpaceArcItem, SpaceArcResult } from '../model/response/SpaceArcSearchResponse';
import { SeriesArchiveItem } from '../model/response/SeriesArchivesResponse';
import { HistoryItem, HistoryResult } from '../model/response/HistoryResponse';
import { FavFolderData } from '../model/response/FavFolderResponse';
import { FavMedia, FavResourceResult } from '../model/response/FavResourceResponse';
import { WatchLaterResult } from '../model/response/WatchLaterResponse';
import { RelationStatData } from '../model/response/RelationStatResponse';
import { CoinCount } from '../model/response/CoinCountResponse';

export class ApiManager {
  /** 最近一次搜索请求是否被风控（-412 等），供搜索结果页区分"无结果"与"请求过于频繁" */
  public lastSearchBlocked: boolean = false;
  /** 推荐流会话级请求计数（AppStorage 会话级，不持久化），用于 fresh_idx_1h/fresh_idx_4h */
  private static readonly KEY_RECOMMEND_SESSION_COUNT: string = 'ohBiliRecommendSessionCount';
  /** 空间投稿每页项数 */
  private static readonly SPACE_ARC_PAGE_SIZE: number = 30;
  /** 空间投稿已加载页码（mid → pn，按用户隔离） */
  private spaceArcPnMap: Map<string, number> = new Map<string, number>();

  private constructor() {
    DataSourceManager.initData();
  }

  public static getInstance(): ApiManager {
    if (globalThis.instance == null) {
      globalThis.instance = new ApiManager();
    }
    return globalThis.instance;
  }

  async requestRelated(bvid: string): Promise<boolean> {
    BLog.d(`requestRelated bvid: ${bvid}`);
    var response = await TaskManager.getInstance().requestRelated(bvid);
    if (response.code == -1 ) {
      BLog.e("requestRelated err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestRelated result: " + JSON.stringify(response.result));
      DataSourceManager.getRelatedSource(bvid).addAllData(response.result.data);
    }
    return response.code != -1;
  }

  async requestRecommend(freshIdx: number, isFresh: boolean): Promise<boolean> {
    BLog.d(`requestRecommend freshIdx: ${freshIdx}, isFresh: ${isFresh}`);
    // 会话级请求计数（网页版 fresh_idx_1h/fresh_idx_4h 语义：随会话内刷新递增）
    let sessionCount: number = AppStorage.get<number>(ApiManager.KEY_RECOMMEND_SESSION_COUNT) ?? 0;
    sessionCount++;
    AppStorage.setOrCreate(ApiManager.KEY_RECOMMEND_SESSION_COUNT, sessionCount);
    let cookie: string = LoginHelper.buildCookieHeader();
    let ps: number = ApiConstants.itemNum;
    let signed: Record<string, string> = await WbiSigner.signParams({
      'ps': ps.toString(),
      'fresh_idx_1h': sessionCount.toString(),
      'fresh_idx_4h': sessionCount.toString(),
      'fresh_idx': freshIdx.toString(),
      'fresh_type': '4',
      'feed_version': 'V2'
    });
    let wRid: string = signed['w_rid'] ?? '';
    let wts: string = signed['wts'] ?? '';
    var response = await TaskManager.getInstance().requestRecommend(cookie, ps,
      sessionCount, sessionCount, freshIdx, 4, 'V2', wRid, wts);
    if (response.code == -1 ) {
      BLog.e("requestRecommend err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestRecommend result: " + JSON.stringify(response.result));
      if (isFresh) {
        DataSourceManager.getRecommendSource().setData(response.result.data.item);
      } else {
        DataSourceManager.getRecommendSource().addAllData(response.result.data.item);
      }
    }
    return response.code != -1;
  }

  async requestPopular(pn: number): Promise<boolean> {
    BLog.d(`requestPopular pn: ${pn}`);
    let cookie: string = LoginHelper.buildCookieHeader();
    var response = await TaskManager.getInstance().requestPopular(cookie, ApiConstants.popularPageSize, pn);
    if (response.code != 0) {
      BLog.e("requestPopular err, code=" + response.code + ", msg=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestPopular result: " + JSON.stringify(response.result));
      if (pn == 1) {
        DataSourceManager.getPopularSource().setData(response.result.data.list);
      } else {
        DataSourceManager.getPopularSource().addAllData(response.result.data.list);
      }
    }
    return response.code != -1;
  }

  /**
   * 获取播放地址：qn 缺省/为 0 时走原有匿名 playurl（保持既有播放链路不变）；
   * 指定 qn 时走 platform=html5 扩展端点（携带登录 Cookie 解锁更高清晰度），
   * 返回含 accept_quality/accept_description 档位表与 durl.size（离线缓存选档用）。
   */
  async requestPlayUrl(bvid: string, cid: number, qn?: number): Promise<PlayUrlResponse> {
    if (qn != null && qn > 0) {
      BLog.d(`requestPlayUrl bvid: ${bvid}, cid: ${cid}, qn: ${qn}`);
      let cookie: string = LoginHelper.buildCookieHeader();
      var qnResponse = await TaskManager.getInstance().requestPlayUrlWithQn(cookie, bvid, cid, qn);
      if (qnResponse.code == -1) {
        BLog.e("requestPlayUrl qn err=" + qnResponse.message);
      }
      if (qnResponse.result != null) {
        BLog.d("requestPlayUrl qn result: " + JSON.stringify(qnResponse.result));
      }
      return qnResponse.result;
    }
    BLog.d(`requestPlayUrl bvid: ${bvid}, cid: ${cid}`);
    var response = await TaskManager.getInstance().requestPlayUrl(bvid, cid);
    if (response.code == -1 ) {
      BLog.e("requestPlayUrl err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestPlayUrl result: " + JSON.stringify(response.result));
    }
    return response.result
  }

  async requestReply(oid: string, next: number,
                      type: number, sort: number): Promise<ReplyCursor> {
    BLog.d(`requestReply oid: ${oid}, next: ${next}, type: ${type}, sort: ${sort}`);
    // 评论接口风控规避：对齐网页版请求头并携带完整 Cookie（匿名连刷会触发 -412/-352 全站失效）
    let cookie: string = LoginHelper.buildCookieHeader();
    var response = await TaskManager.getInstance().requestReply(cookie, oid, ApiConstants.itemNum, next, type, sort);
    if (response.code == -1 ) {
      BLog.e("requestReply err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestReply result: " + JSON.stringify(response.result));
      if (next == 0) {
        DataSourceManager.getReplySource(oid).setData(response.result.data.replies);
      } else {
        DataSourceManager.getReplySource(oid).addAllData(response.result.data.replies);
      }
      return response.result.data.cursor;
    }
    return null;
  }

  async requestReplyDetail(oid: string, root: number, pn: number,
                      type: number): Promise<ReplyPage> {
    BLog.d(`requestReplyDetail oid: ${oid}, root: ${root}, pn: ${pn}, type: ${type}`);
    let cookie: string = LoginHelper.buildCookieHeader();
    var response = await TaskManager.getInstance().requestReplyDetail(cookie, oid, root, ApiConstants.itemNum, pn, type);
    if (response.code == -1 ) {
      BLog.e("requestReplyDetail err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestReplyDetail result: " + JSON.stringify(response.result));
      DataSourceManager.getReplyDetailSource().addAllData(response.result.data.replies);
      return response.result.data.page;
    }
    return null;
  }

  /**
   * 评论点赞/点踩（csrf 鉴权）：请求动作 0=取消赞 1=赞 2=踩 3=取消踩
   * （任务层路由：1/0 走 x/v2/reply/action，2/3 走 x/v2/reply/hate）
   * @param oid 视频 aid
   */
  async requestReplyAction(oid: number, rpid: number, action: number): Promise<boolean> {
    BLog.d("requestReplyAction oid=" + oid + ", rpid=" + rpid + ", action=" + action);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().requestReplyAction(cookie, oid, 1, rpid, action, csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("requestReplyAction failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  /**
   * 删除自己的评论（csrf 鉴权，仅限本人评论）
   * @param oid 视频 aid
   */
  async requestReplyDel(oid: number, rpid: number): Promise<boolean> {
    BLog.d("requestReplyDel oid=" + oid + ", rpid=" + rpid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().requestReplyDel(cookie, oid, 1, rpid, csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("requestReplyDel failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  /**
   * 发表评论/回复（csrf 鉴权）：root=0 为顶级评论，否则为楼中楼回复
   * @param oid 视频 aid
   */
  async requestReplyAdd(oid: number, root: number, parent: number, message: string): Promise<boolean> {
    BLog.d("requestReplyAdd oid=" + oid + ", root=" + root + ", parent=" + parent
      + ", msgLen=" + message.length);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().requestReplyAdd(cookie, oid, 1, root, parent, message, csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("requestReplyAdd failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  async requestDmList(oid: number, type: number, index: number): Promise<ProtoSource> {
    BLog.d(`requestDmList oid: ${oid}, type: ${type}, index: ${index}`);
    var response = await TaskManager.getInstance().requestDmList(oid, type, index);
    if (response.code == -1 ) {
      BLog.e("requestDmList err=" + response.message);
    }
    BLog.i('requestDmList Result byteLength:' + response.result.byteLength);
    var builder = await protobuf.loadProtoFile('danmaku.proto', null, null, globalThis.resourceMana);
    // @ts-ignore
    var DmSegMobileReply = builder.build("bilibili.community.service.dm.v1.DmSegMobileReply");
    var reply = DmSegMobileReply.decode(response.result);
    BLog.i('requestDmList Result elems length:' + reply.elems.length);
    return new ProtoSource(reply);
  }

  async requestRanking(): Promise<RankingResponse> {
    BLog.d(`requestRanking`);
    var response = await TaskManager.getInstance().requestRanking();
    if (response.code == -1 ) {
      BLog.e("requestRanking err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestRanking result: " + JSON.stringify(response.result));
    }
    return response.result;
  }

  async requestSearch(keyword: string, pn: number): Promise<boolean> {
    BLog.d(`requestSearch keyword: ${keyword}, pn: ${pn}`);
    // 搜索为 gaia 风控敏感接口：仅携带登录 Cookie（新铸 buvid 无浏览历史，携带反而触发 v_voucher 风控）
    let cookie: string = LoginHelper.buildLoginCookieHeader();
    let signed: Record<string, string> = await WbiSigner.signParams({
      'search_type': 'video',
      'keyword': keyword,
      'page': pn.toString()
    });
    let wRid: string = signed['w_rid'] ?? '';
    let wts: string = signed['wts'] ?? '';
    BLog.i("requestSearch signed, wRid=" + wRid + ", wts=" + wts
      + ", cookieLen=" + cookie.length + ", keyword=" + keyword);
    // retrofit 库 buildURL 不做 URL 编码：keyword 需预编码后传参（签名已按 encodeURIComponent 后的值计算）
    let encodedKeyword: string = encodeURIComponent(keyword);
    let searchPromise: Promise<ApiResponse<SearchResponse>> =
      TaskManager.getInstance().requestSearch(cookie, "video", encodedKeyword, pn, wRid, wts);
    // 兜底超时：防止底层 Promise 永不 settle 导致页面永久停留在"数据加载中"
    let timeoutPromise: Promise<never> = new Promise<never>((resolve, reject) => {
      setTimeout(() => {
        reject(new Error('requestSearch timeout 20s'));
      }, 20000);
    });
    let response: ApiResponse<SearchResponse>;
    try {
      response = await Promise.race([searchPromise, timeoutPromise]);
      BLog.i("requestSearch resp, code=" + response.code + ", msg=" + response.message);
    } catch (err) {
      BLog.e("requestSearch failed, err=" + err);
      this.lastSearchBlocked = false;
      return false;
    }
    let blocked: boolean = false;
    if (response.code == -1 ) {
      BLog.e("requestSearch err=" + response.message);
      // 风控（HTTP 412）时请求层抛错进入 catch，message 携带状态码
      blocked = response.message != null && response.message.indexOf('412') >= 0;
    }
    if (response.result != null) {
      BLog.d("requestSearch result: " + JSON.stringify(response.result));
      let bizCode: number = response.result.code;
      if (bizCode == -412 || bizCode == -799) {
        BLog.e("requestSearch risk control, bizCode=" + bizCode);
        blocked = true;
      }
      if (response.result.data != null) {
        // 风控（gaia/vgate）：200 + data 仅含 v_voucher，无 result 数据
        if (response.result.data.v_voucher != null) {
          BLog.e("requestSearch risk control, v_voucher=" + response.result.data.v_voucher);
          blocked = true;
        }
        if (response.result.data.result != null) {
          if (pn == 1) {
            DataSourceManager.getSearchSource().setData(response.result.data.result);
          } else {
            DataSourceManager.getSearchSource().addAllData(response.result.data.result);
          }
        }
      }
    }
    this.lastSearchBlocked = blocked;
    BLog.i("requestSearch done, blocked=" + blocked);
    return response.code != -1;
  }

  async requestPageList(bvid: string): Promise<VideoPartsResponse> {
    BLog.d(`requestPageList bvid: ${bvid}`);
    var response = await TaskManager.getInstance().requestPageList(bvid);
    if (response.code == -1 ) {
      BLog.e("requestPageList err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestPageList result: " + JSON.stringify(response.result));
    }
    return response.result;
  }

  async requestSearchDefault(): Promise<string> {
    BLog.d("requestSearchDefault");
    var response = await TaskManager.getInstance().requestSearchDefault();
    if (response.code == -1 ) {
      BLog.e("requestSearchDefault err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestSearchDefault result: " + JSON.stringify(response.result));
      return response.result.data.name;
    }
    return "OpenHarmony";
  }

  async requestArchiveStat(bvid: string): Promise<ArchiveStatResponse> {
    BLog.d(`requestArchiveStat bvid: ${bvid}`);
    var response = await TaskManager.getInstance().requestArchiveStat(bvid);
    if (response.code == -1 ) {
      BLog.e("requestArchiveStat err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestArchiveStat result: " + JSON.stringify(response.result));
    }
    return response.result;
  }

  async requestArchiveDesc(bvid: string): Promise<string> {
    BLog.d(`requestArchiveDesc bvid: ${bvid}`);
    var response = await TaskManager.getInstance().requestArchiveDesc(bvid);
    if (response.code == -1 ) {
      BLog.e("requestArchiveDesc err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestArchiveDesc result: " + JSON.stringify(response.result));
      return response.result.data;
    }
    return "";
  }

  async requestGenericCountryList(): Promise<CountryList> {
    BLog.d("requestGenericCountryList");
    var response = await TaskManager.getInstance().requestGenericCountryList();
    if(response.code == -1){
      BLog.e("requestGenericCountryList err=" + response.message);
    }
    if(response.result != null) {
      BLog.d("requestGenericCountryList result:" + JSON.stringify(response.result));
      return response.result.data;
    }
    return {
      common: [],
      others: []
    };
  }

  async sendSmsCaptcha(
    cid: number, tel: number, sessionId: string, captchaToken: string,
    geeChallenge: string, geeValidate: string, geeSecCode: string, channel: string, buvid: string,
    localId: string, statistics: string
  ): Promise<SendSmsCaptchaResponse> {
    BLog.d("sendSmsCaptcha");
    var response = await TaskManager.getInstance().SendSmsCaptcha(
      cid,tel,sessionId,captchaToken,geeChallenge,geeValidate,geeSecCode,channel,buvid,localId,statistics
    );
    if(response.code == -1) {
      BLog.e("sendSmsCaptcha err=" + response.message);
    }
    if(response.result != null) {
      BLog.d("sendSmsCaptcha result:" + JSON.stringify(response.result));
    }
    return response.result;
  }

  async loginViaSmsCaptcha(cid: number, tel: number, sessionId: string,
                           _code: number, captchaKey: string): Promise<SmsLoginResponse> {
    BLog.d("loginViaSmsCaptcha");
    var response = await TaskManager.getInstance().loginViaSmsCaptcha(cid, tel, sessionId,
    _code, captchaKey);
    if(response.code == -1){
      BLog.e("loginViaSmsCaptcha err=" + response.message);
    }
    if(response.result !== null) {
      BLog.d("loginViaSmsCaptcha result:" + JSON.stringify(response.result));
    }
    return response.result;
  }

  async requestUserCardInfo(mid: number, photo: boolean = false): Promise<CardInfoResponse> {
    BLog.d("requestUserCardInfo");
    var response = await TaskManager.getInstance().requestUserCardInfo(mid, photo);
    if(response.code == -1) {
      BLog.e("requestUserCardInfo err=" + response.message);
    }
    if(response.result !== null) {
      BLog.d("requestUserCardInfo result:" + JSON.stringify(response.result));
    }
    return response.result;
  }

  async requestQrCode(): Promise<QrCodeData> {
    BLog.d("requestQrCode");
    var response = await TaskManager.getInstance().requestQrCodeGenerate();
    if (response.code == -1) {
      BLog.e("requestQrCode err=" + response.message);
    }
    var result: QrCodeGenerateResponse = response.result;
    if (result != null && result.data != null) {
      BLog.d("requestQrCode result: " + JSON.stringify(result.data));
      return result.data;
    }
    return null;
  }

  async pollQrStatus(qrcodeKey: string): Promise<QrPollResponse> {
    BLog.d("pollQrStatus qrcodeKey: " + qrcodeKey);
    var response = await TaskManager.getInstance().requestQrPoll(qrcodeKey);
    if (response.code == -1) {
      BLog.e("pollQrStatus err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("pollQrStatus result: " + JSON.stringify(response.result));
    }
    return response.result;
  }

  async requestNavInfo(cookie: string): Promise<NavData> {
    BLog.d("requestNavInfo");
    var response = await TaskManager.getInstance().requestNavInfo(cookie);
    if (response.code == -1) {
      BLog.e("requestNavInfo err=" + response.message);
    }
    var result: NavResponse = response.result;
    if (result != null && result.data != null) {
      BLog.d("requestNavInfo result: " + JSON.stringify(result.data));
      return result.data;
    }
    return null;
  }

  /**
   * 获取 Web 端设备指纹 Cookie（buvid3/buvid4）；失败返回 null。
   */
  async requestFingerSpi(): Promise<FingerSpiResponse | null> {
    BLog.d("requestFingerSpi");
    const response: ApiResponse<FingerSpiResponse> = await TaskManager.getInstance().requestFingerSpi();
    if (response.code == -1) {
      BLog.e("requestFingerSpi err=" + response.message);
    }
    if (response.result != null) {
      BLog.d("requestFingerSpi result: " + JSON.stringify(response.result));
      return response.result;
    }
    return null;
  }

  /**
   * GET crossDomain URL 以 ticket 兑换登录 Cookie（关闭重定向，读 302 的 Set-Cookie）。
   * 失败时返回的 CrossDomainResult 内含 errorMessage/原始响应，便于诊断。
   */
  async exchangeCrossDomainTicket(url: string, cookie: string): Promise<CrossDomainResult> {
    BLog.d("exchangeCrossDomainTicket url: " + url);
    let result: CrossDomainResult = new CrossDomainResult();
    try {
      result = await TaskManager.getInstance().exchangeCrossDomainTicket(url, cookie);
    } catch (err) {
      BLog.e("exchangeCrossDomainTicket err=" + err);
      result.errorMessage = err + '';
      return result;
    }
    BLog.d("exchangeCrossDomainTicket code=" + result.responseCode
      + " location=" + result.location
      + " setCookie=[" + result.setCookieRaw + "]"
      + " cookiesField=[" + result.cookiesField + "]"
      + " body=[" + result.bodySnippet + "]"
      + " err=" + result.errorMessage);
    // 主线程侧解析 Set-Cookie / cookies 字段填充 cookieParams
    parseCrossDomainResultCookies(result);
    BLog.d("exchangeCrossDomainTicket cookieParams: " + JSON.stringify(result.cookieParams));
    return result;
  }

  /**
   * 拉取关注 UP 主动态流（offset 游标分页）：
   * 成功写入 DynamicDataSource（刷新清空重填 / 追加按 id_str 去重）；
   * videoOnly=true 时仅保留视频投稿动态并写入独立的视频动态数据源；
   * 登录失效（业务码 -101）返回 loginExpired 标志，由页面引导重新登录。
   */
  async requestDynamicFeed(offset: string, isRefresh: boolean, videoOnly: boolean = false): Promise<DynamicFeedResult> {
    BLog.d("requestDynamicFeed offset=" + offset + ", isRefresh=" + isRefresh + ", videoOnly=" + videoOnly);
    let cookie: string = LoginHelper.buildCookieHeader();
    let response = await TaskManager.getInstance().requestDynamicFeed(cookie, offset);
    if (response.code == -1) {
      BLog.e("requestDynamicFeed err=" + response.message);
      return new DynamicFeedResult(false, false, false, '');
    }
    if (response.result == null) {
      return new DynamicFeedResult(false, false, false, '');
    }
    let bizCode: number = response.result.code;
    if (bizCode == -101) {
      BLog.w("requestDynamicFeed login expired");
      return new DynamicFeedResult(false, true, false, '');
    }
    if (bizCode != 0 || response.result.data == null) {
      BLog.e("requestDynamicFeed biz err, code=" + bizCode);
      return new DynamicFeedResult(false, false, false, '');
    }
    let data = response.result.data;
    let items: DynamicItem[] = data.items ?? [];
    if (videoOnly) {
      // "视频"标签：仅保留视频投稿动态（优先 type 字段，缺失时按 major.archive 内容判定）
      let videos: DynamicItem[] = [];
      items.forEach((item: DynamicItem) => {
        if (this.isVideoDynamic(item)) {
          videos.push(item);
        }
      });
      BLog.d("requestDynamicFeed videoOnly filter: " + items.length + " -> " + videos.length);
      items = videos;
    }
    // 调试：统计本页转发类动态数量（orig 非空）
    let origCount: number = 0;
    items.forEach((item: DynamicItem) => {
      if (item.modules != null && item.modules.module_dynamic != null
        && item.modules.module_dynamic.orig != null) {
        origCount++;
      }
    });
    BLog.d("requestDynamicFeed page items=" + items.length + ", origCount=" + origCount);
    let source = videoOnly
      ? DataSourceManager.getDynamicVideoSource()
      : DataSourceManager.getDynamicSource();
    if (isRefresh) {
      source.setData(items);
    } else {
      // 追加时按 id_str 去重，避免游标重叠导致重复条目
      let existingIds: Set<string> = new Set<string>();
      source.getAllData().forEach((item: DynamicItem) => {
        existingIds.add(item.id_str);
      });
      let newItems: DynamicItem[] = [];
      items.forEach((item: DynamicItem) => {
        if (!existingIds.has(item.id_str)) {
          newItems.push(item);
        }
      });
      source.addAllData(newItems);
    }
    return new DynamicFeedResult(true, false, data.has_more ?? false, data.offset ?? '');
  }

  /**
   * 是否为视频投稿动态：type 为 DYNAMIC_TYPE_AV，或（type 缺失时）
   * 主体带 major.archive（转发/图文/直播/专栏等均不含顶层 archive，天然被排除）
   */
  private isVideoDynamic(item: DynamicItem): boolean {
    if (item.type != null) {
      return item.type == 'DYNAMIC_TYPE_AV';
    }
    return item.modules != null
      && item.modules.module_dynamic != null
      && item.modules.module_dynamic.major != null
      && item.modules.module_dynamic.major.archive != null;
  }

  /**
   * 拉取用户空间资料并组装 SpaceUserProfile：
   * acc/info（WBI 对 {mid} 签名）提供资料；card 接口提供关注/粉丝/获赞/投稿数；
   * acc/info 失败时以 card 字段兜底（profileLoaded=false，签名/等级占位）；
   * 双双失败返回 null（页面展示错误态）。
   */
  async requestSpaceInfo(mid: number): Promise<SpaceUserProfile | null> {
    BLog.d("requestSpaceInfo mid=" + mid);
    let profile: SpaceUserProfile = new SpaceUserProfile(mid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let signed: Record<string, string> = await WbiSigner.signParams({
      'mid': mid.toString()
    });
    let accResp = await TaskManager.getInstance().requestSpaceAccInfo(cookie, mid,
      signed['w_rid'] ?? '', signed['wts'] ?? '');
    if (accResp.code != -1 && accResp.result != null && accResp.result.code == 0
      && accResp.result.data != null) {
      let acc = accResp.result.data;
      profile.name = acc.name ?? '';
      profile.face = acc.face ?? '';
      profile.sign = acc.sign ?? '';
      profile.level = acc.level ?? 0;
      profile.profileLoaded = true;
    } else {
      BLog.w("requestSpaceInfo acc/info failed, code="
        + (accResp.result == null ? accResp.code : accResp.result.code));
    }
    let cardResp: CardInfoResponse = await this.requestUserCardInfo(mid);
    let cardLoaded: boolean = false;
    if (cardResp != null && cardResp.code == 0 && cardResp.data != null) {
      let card = cardResp.data;
      profile.follower = card.follower ?? 0;
      profile.likeNum = card.likeNum ?? 0;
      profile.archiveCount = card.archive_count ?? 0;
      if (card.card != null) {
        profile.following = card.card.friend ?? 0;
        if (!profile.profileLoaded) {
          // acc/info 失败：以 card 兜底资料（签名/等级缺失由页面占位）
          if (profile.name === '') {
            profile.name = card.card.name ?? '';
          }
          if (profile.face === '') {
            profile.face = card.card.face ?? '';
          }
          profile.sign = card.card.sign ?? '';
          if (card.card.level_info != null) {
            profile.level = card.card.level_info.current_level ?? 0;
          }
        }
      }
      cardLoaded = true;
    } else {
      BLog.w("requestSpaceInfo card failed");
    }
    if (!profile.profileLoaded && !cardLoaded) {
      return null;
    }
    return profile;
  }

  /**
   * 拉取用户投稿视频列表并写入 SpaceArcDataSource（按 mid 隔离）：
   * 主接口 arc/search（WBI 全参数签名），风控/异常时降级 series/recArchivesByKeywords；
   * 刷新清空重填；返回是否还有更多。
   */
  async requestSpaceArchives(mid: number, isRefresh: boolean): Promise<SpaceArcResult> {
    BLog.d("requestSpaceArchives mid=" + mid + ", isRefresh=" + isRefresh);
    let midKey: string = mid.toString();
    let pn: number = isRefresh ? 1 : (this.spaceArcPnMap.get(midKey) ?? 0) + 1;
    let cookie: string = LoginHelper.buildCookieHeader();
    let signed: Record<string, string> = await WbiSigner.signParams({
      'mid': midKey,
      'pn': pn.toString(),
      'ps': ApiManager.SPACE_ARC_PAGE_SIZE.toString(),
      'order': 'pubdate'
    });
    let resp = await TaskManager.getInstance().requestSpaceArcSearch(cookie, mid, pn,
      ApiManager.SPACE_ARC_PAGE_SIZE, 'pubdate', signed['w_rid'] ?? '', signed['wts'] ?? '');
    let bizCode: number = (resp.result == null) ? -1 : resp.result.code;
    if (resp.code != -1 && bizCode == 0 && resp.result.data != null
      && resp.result.data.list != null) {
      let vlist: SpaceArcItem[] = resp.result.data.list.vlist ?? [];
      let source = DataSourceManager.getSpaceArcSource(midKey);
      if (isRefresh) {
        source.setData(vlist);
      } else {
        source.addAllData(vlist);
      }
      this.spaceArcPnMap.set(midKey, pn);
      let count: number = resp.result.data.page == null ? 0 : (resp.result.data.page.count ?? 0);
      let hasMore: boolean = pn * ApiManager.SPACE_ARC_PAGE_SIZE < count;
      return new SpaceArcResult(true, hasMore);
    }
    // 降级：series/recArchivesByKeywords（-352 风控 / 请求异常 / 数据缺失）
    BLog.w("requestSpaceArchives arc/search failed, code=" + bizCode + ", fallback to series");
    let seriesResp = await TaskManager.getInstance().requestSeriesArchives(mid, pn,
      ApiManager.SPACE_ARC_PAGE_SIZE);
    if (seriesResp.code != -1 && seriesResp.result != null && seriesResp.result.code == 0
      && seriesResp.result.data != null && seriesResp.result.data.archives != null) {
      let archives: SeriesArchiveItem[] = seriesResp.result.data.archives;
      let items: SpaceArcItem[] = [];
      archives.forEach((item: SeriesArchiveItem) => {
        items.push(ApiManager.seriesItemToSpaceArcItem(item));
      });
      let source = DataSourceManager.getSpaceArcSource(midKey);
      if (isRefresh) {
        source.setData(items);
      } else {
        source.addAllData(items);
      }
      this.spaceArcPnMap.set(midKey, pn);
      let hasMore: boolean = items.length >= ApiManager.SPACE_ARC_PAGE_SIZE;
      return new SpaceArcResult(true, hasMore);
    }
    BLog.e("requestSpaceArchives series fallback failed too");
    return new SpaceArcResult(false, false);
  }

  /**
   * SeriesArchiveItem → SpaceArcItem 归一化（duration 秒 → "mm:ss" 文本）
   */
  private static seriesItemToSpaceArcItem(item: SeriesArchiveItem): SpaceArcItem {
    let arcItem: SpaceArcItem = {
      bvid: item.bvid,
      title: item.title ?? '',
      pic: item.pic ?? '',
      created: item.pubdate ?? 0,
      length: StringUtil.parseSecondToVideoDuration(item.duration ?? 0),
      play: item.sta == null ? 0 : (item.sta.view ?? 0),
      author: item.owner == null ? '' : (item.owner.name ?? ''),
      description: ''
    };
    return arcItem;
  }

  /** 写操作 csrf（登录票据 bili_jct） */
  private static getCsrf(): string {
    return AppStorage.get<string>('ohBiliBiliJct') ?? '';
  }

  /**
   * 拉取云端历史记录并写入 HistoryDataSource（max/view_at/business 游标分页）：
   * pn==1 刷新清空重填（游标归零）；pn>1 以 DataSource 末条 view_at+business
   * 作游标续拉（与响应 cursor 字段等值，服务端语义即末条游标）；
   * 登录失效（业务码 -101）返回 loginExpired 标志，由页面引导重新登录。
   */
  async requestHistory(pn: number, ps: number): Promise<HistoryResult> {
    BLog.d("requestHistory pn=" + pn + ", ps=" + ps);
    // 历史为 gaia 风控敏感接口：仅携带登录 Cookie（新铸 buvid 无浏览历史，携带反而触发 -352 风控，同 requestSearch 先例）
    let cookie: string = LoginHelper.buildLoginCookieHeader();
    let max: number = 0;
    let viewAt: number = 0;
    let business: string = '';
    if (pn > 1) {
      let loaded: HistoryItem[] = DataSourceManager.getHistorySource().getAllData();
      if (loaded.length > 0) {
        let last: HistoryItem = loaded[loaded.length - 1];
        viewAt = last.view_at ?? 0;
        max = viewAt;
        if (last.history != null) {
          business = last.history.business ?? '';
        }
      }
    }
    // 2026 现行 web 版历史接口为 x/web-interface/history/cursor（网页版不带 WBI 签名）；
    // 旧端点 x/v2/history 已对 web 会话封闭（-108 应用不存在或者被封禁）
    BLog.i("requestHistory cursor, max=" + max + ", view_at=" + viewAt
      + ", business=" + business + ", cookieLen=" + cookie.length);
    let response = await TaskManager.getInstance().requestHistory(cookie, max, viewAt,
      business);
    BLog.i("requestHistory resp, code=" + response.code + ", bizCode="
      + (response.result == null ? "null" : response.result.code) + ", bizMsg="
      + (response.result == null ? "" : response.result.message));
    if (response.code == -1) {
      BLog.e("requestHistory err=" + response.message);
      return new HistoryResult(false, false, false);
    }
    if (response.result == null) {
      return new HistoryResult(false, false, false);
    }
    let bizCode: number = response.result.code;
    if (bizCode == -101) {
      BLog.w("requestHistory login expired");
      return new HistoryResult(false, true, false);
    }
    if (bizCode != 0 || response.result.data == null) {
      BLog.e("requestHistory biz err, code=" + bizCode);
      return new HistoryResult(false, false, false);
    }
    let items: HistoryItem[] = response.result.data.list ?? [];
    let source = DataSourceManager.getHistorySource();
    if (pn == 1) {
      source.setData(items);
    } else {
      source.addAllData(items);
    }
    // 游标分页无固定页长：本页非空即可能还有下一页（空页=到底，同网页版语义）
    let hasMore: boolean = items.length > 0;
    return new HistoryResult(true, false, hasMore);
  }

  /**
   * 删除单条历史记录（kid 形如 av{aid}，csrf 鉴权）
   */
  async deleteHistory(kid: string): Promise<boolean> {
    BLog.d("deleteHistory kid=" + kid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().deleteHistory(cookie, kid, csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("deleteHistory failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  /**
   * 清空全部历史记录（csrf 鉴权，不可恢复，调用方需二次确认）
   */
  async clearHistory(): Promise<boolean> {
    BLog.d("clearHistory");
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().clearHistory(cookie, csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("clearHistory failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  /**
   * 拉取收藏夹列表（含默认夹）：
   * rid>0 时（视频页收藏入口）每夹带 fav_state 标记该视频是否已收藏于该夹。
   */
  async requestFavFolders(mid: number, rid: number = 0): Promise<FavFolderData | null> {
    BLog.d("requestFavFolders mid=" + mid + ", rid=" + rid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let response = await TaskManager.getInstance().requestFavFolders(cookie, mid, rid, 2);
    if (response.code == -1 || response.result == null) {
      BLog.e("requestFavFolders err, code=" + response.code + ", msg=" + response.message);
      return null;
    }
    if (response.result.code != 0) {
      BLog.e("requestFavFolders biz err, code=" + response.result.code);
      return null;
    }
    BLog.d("requestFavFolders result: " + JSON.stringify(response.result.data));
    return response.result.data;
  }

  /**
   * 拉取收藏夹内容并写入 FavMediaDataSource（按 mediaId 隔离，pn/ps 分页）：
   * 登录失效（业务码 -101）返回 loginExpired 标志。
   */
  async requestFavResources(mediaId: number, pn: number, ps: number): Promise<FavResourceResult> {
    BLog.d("requestFavResources mediaId=" + mediaId + ", pn=" + pn + ", ps=" + ps);
    let cookie: string = LoginHelper.buildCookieHeader();
    let response = await TaskManager.getInstance().requestFavResources(cookie, mediaId, pn, ps,
      '', 'mtime', 0, 0, 'web');
    if (response.code == -1) {
      BLog.e("requestFavResources err=" + response.message);
      return new FavResourceResult(false, false, false);
    }
    if (response.result == null) {
      return new FavResourceResult(false, false, false);
    }
    let bizCode: number = response.result.code;
    if (bizCode == -101) {
      BLog.w("requestFavResources login expired");
      return new FavResourceResult(false, true, false);
    }
    if (bizCode != 0 || response.result.data == null) {
      BLog.e("requestFavResources biz err, code=" + bizCode);
      return new FavResourceResult(false, false, false);
    }
    let medias: FavMedia[] = response.result.data.medias ?? [];
    let source = DataSourceManager.getFavMediaSource(mediaId.toString());
    if (pn == 1) {
      source.setData(medias);
    } else {
      source.addAllData(medias);
    }
    let hasMore: boolean = response.result.data.has_more ?? false;
    return new FavResourceResult(true, false, hasMore);
  }

  /**
   * 收藏/取消收藏：将视频加入/移出多个收藏夹（csrf 鉴权）。
   * @param aid 视频 aid
   * @param addIds 加入的收藏夹 media_id 列表
   * @param delIds 移出的收藏夹 media_id 列表
   */
  async favDeal(aid: number, addIds: number[], delIds: number[]): Promise<boolean> {
    BLog.d("favDeal aid=" + aid + ", add=" + addIds.length + ", del=" + delIds.length);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().favDeal(cookie, aid, 2,
      addIds.join(','), delIds.join(','), csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("favDeal failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  /**
   * 拉取稍后再看列表并全量写入 WatchLaterDataSource（单页接口）：
   * 登录失效（业务码 -101）返回 loginExpired 标志。
   */
  async requestWatchLater(): Promise<WatchLaterResult> {
    BLog.d("requestWatchLater");
    let cookie: string = LoginHelper.buildCookieHeader();
    let response = await TaskManager.getInstance().requestWatchLater(cookie);
    if (response.code == -1) {
      BLog.e("requestWatchLater err=" + response.message);
      return new WatchLaterResult(false, false);
    }
    if (response.result == null) {
      return new WatchLaterResult(false, false);
    }
    let bizCode: number = response.result.code;
    if (bizCode == -101) {
      BLog.w("requestWatchLater login expired");
      return new WatchLaterResult(false, true);
    }
    if (bizCode != 0 || response.result.data == null) {
      BLog.e("requestWatchLater biz err, code=" + bizCode);
      return new WatchLaterResult(false, false);
    }
    let source = DataSourceManager.getWatchLaterSource();
    source.setData(response.result.data.list ?? []);
    return new WatchLaterResult(true, false);
  }

  /**
   * 添加视频到稍后再看（csrf 鉴权）
   */
  async addWatchLater(aid: number): Promise<boolean> {
    BLog.d("addWatchLater aid=" + aid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().addWatchLater(cookie, aid, csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("addWatchLater failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  /**
   * 从稍后再看移除视频（csrf 鉴权，调用方需二次确认）
   */
  async removeWatchLater(aid: number): Promise<boolean> {
    BLog.d("removeWatchLater aid=" + aid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().removeWatchLater(cookie, aid, csrf);
    if (response.code == -1 || response.result == null || response.result.code != 0) {
      BLog.e("removeWatchLater failed, code=" + response.code
        + ", bizCode=" + (response.result == null ? -1 : response.result.code)
        + ", msg=" + response.message);
      return false;
    }
    return true;
  }

  /**
   * 获取用户关注/粉丝数（x/relation/stat 公开接口）；
   * 供"我的"页统计栏展示，失败返回 null 由调用方保持占位
   */
  async requestRelationStat(vmid: number): Promise<RelationStatData | null> {
    BLog.d("requestRelationStat vmid=" + vmid);
    let response = await TaskManager.getInstance().requestRelationStat(vmid);
    if (response.code == -1) {
      BLog.e("requestRelationStat err=" + response.message);
      return null;
    }
    if (response.result == null || response.result.code != 0
      || response.result.data == null) {
      BLog.e("requestRelationStat biz err, code="
        + (response.result == null ? -1 : response.result.code));
      return null;
    }
    return response.result.data;
  }

  /**
   * 视频点赞/取消点赞（csrf 鉴权，无需 WBI）
   * @param like 1=点赞 2=取消点赞
   * @return 0=成功 -101=登录失效 其余=业务失败码（65006=已点赞）
   */
  async likeVideo(aid: number, like: number): Promise<number> {
    BLog.d("likeVideo aid=" + aid + ", like=" + like);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().likeVideo(cookie, aid, like, csrf);
    if (response.code == -1) {
      BLog.e("likeVideo err=" + response.message);
      return -1;
    }
    if (response.result == null) {
      return -1;
    }
    if (response.result.code == 0) {
      return 0;
    }
    BLog.e("likeVideo biz err, code=" + response.result.code + ", msg=" + response.result.message);
    return response.result.code;
  }

  /**
   * 查询当前用户是否已点赞视频（data: 0|1）；未登录/失败返回 -1
   */
  async requestHasLike(aid: number): Promise<number> {
    BLog.d("requestHasLike aid=" + aid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let response = await TaskManager.getInstance().requestHasLike(cookie, aid);
    if (response.code == -1 || response.result == null) {
      BLog.e("requestHasLike err, code=" + response.code + ", msg=" + response.message);
      return -1;
    }
    if (response.result.code != 0 || response.result.data == null) {
      BLog.e("requestHasLike biz err, code=" + response.result.code);
      return -1;
    }
    return response.result.data;
  }

  /**
   * 视频投币（csrf 鉴权）
   * @return 0=成功 -101=登录失效 其余=业务失败码（34004 太频繁/34005 已投满/-104 硬币不足）
   */
  async coinVideo(aid: number, multiply: number, selectLike: boolean): Promise<number> {
    BLog.d("coinVideo aid=" + aid + ", multiply=" + multiply + ", selectLike=" + selectLike);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().coinVideo(cookie, aid, multiply,
      selectLike ? 1 : 0, csrf);
    if (response.code == -1) {
      BLog.e("coinVideo err=" + response.message);
      return -1;
    }
    if (response.result == null) {
      return -1;
    }
    if (response.result.code == 0) {
      return 0;
    }
    BLog.e("coinVideo biz err, code=" + response.result.code + ", msg=" + response.result.message);
    return response.result.code;
  }

  /**
   * 查询当前用户对视频的已投硬币数；未登录/失败返回 -1
   */
  async requestCoinCount(aid: number): Promise<number> {
    BLog.d("requestCoinCount aid=" + aid);
    let cookie: string = LoginHelper.buildCookieHeader();
    let response = await TaskManager.getInstance().requestCoinCount(cookie, aid);
    if (response.code == -1 || response.result == null || response.result.data == null) {
      BLog.e("requestCoinCount err, code=" + response.code + ", msg=" + response.message);
      return -1;
    }
    if (response.result.code != 0) {
      BLog.e("requestCoinCount biz err, code=" + response.result.code);
      return -1;
    }
    return response.result.data.multiply ?? 0;
  }

  /**
   * 发送弹幕（csrf 鉴权，默认白色 25 字号滚动弹幕）
   * @return 0=成功 -101=登录失效 其余=业务失败码
   */
  async sendDanmaku(cid: number, aid: number, msg: string, progressMs: number,
                    mode: number = 1): Promise<number> {
    BLog.d("sendDanmaku cid=" + cid + ", aid=" + aid + ", msgLen=" + msg.length
      + ", progress=" + progressMs + ", mode=" + mode);
    let cookie: string = LoginHelper.buildCookieHeader();
    let csrf: string = ApiManager.getCsrf();
    let response = await TaskManager.getInstance().postDanmaku(cookie, cid, aid, msg,
      progressMs, mode, csrf);
    if (response.code == -1) {
      BLog.e("sendDanmaku err=" + response.message);
      return -1;
    }
    if (response.result == null) {
      return -1;
    }
    if (response.result.code == 0) {
      return 0;
    }
    BLog.e("sendDanmaku biz err, code=" + response.result.code + ", msg=" + response.result.message);
    return response.result.code;
  }
}