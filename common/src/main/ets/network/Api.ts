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

import {
  BaseService,
  ServiceBuilder,
  GET,
  POST,
  DELETE,
  PUT,
  UrlPath,
  Body,
  BasePath,
  Response,
  Header,
  Headers,
  Query
} from '@ohos/retrofit';
import { ViewResponse } from '../model/response/ViewResponse';
import { CountryListResponse } from '../model/response/GenericCountryListResponse';
import { PlayUrlResponse } from '../model/response/PlayUrlResponse';
import { PopularResponse } from '../model/response/PopularResponse';
import { RankingResponse } from '../model/response/RankingResponse';
import { RecommendResponse } from '../model/response/RecommendResponse';
import { RegionResponse } from '../model/response/RegionResponse';
import { RelatedResponse } from '../model/response/RelatedResponse';
import { ReplyDetailResponse } from '../model/response/ReplyDetailResponse';
import { ReplyResponse } from '../model/response/ReplyResponse';
import { EmptyResponse, StringResponse } from '../model/response/Response';
import { ApiConstants } from './ApiConstants';
import { NavResponse } from '../model/response/NavResponse';
import { QrCodeGenerateResponse } from '../model/response/QrCodeGenerateResponse';
import { QrPollResponse } from '../model/response/QrPollResponse';
import { SearchDefaultResponse } from '../model/response/SearchDefaultResponse';
import { SearchResponse } from '../model/response/SearchResponse';
import { SendSmsCaptchaResponse } from '../model/response/SendSmsCaptchaResponse';
import { SmsLoginResponse } from '../model/response/SmsLoginResponse';
import { CardInfoResponse } from '../model/response/UserCardInfoResponse';
import { FingerSpiResponse } from '../model/response/FingerSpiResponse';
import { VideoPartsResponse } from '../model/response/VideoPartsResponse';
import { DynamicFeedResponse } from '../model/response/DynamicFeedResponse';
import { SpaceAccInfoResponse } from '../model/response/SpaceAccInfoResponse';
import { SpaceArcSearchResponse } from '../model/response/SpaceArcSearchResponse';
import { SeriesArchivesResponse } from '../model/response/SeriesArchivesResponse';
import { HistoryResponse } from '../model/response/HistoryResponse';
import { RelationStatResponse } from '../model/response/RelationStatResponse';
import { FavFolderResponse } from '../model/response/FavFolderResponse';
import { FavResourceResponse } from '../model/response/FavResourceResponse';
import { WatchLaterResponse } from '../model/response/WatchLaterResponse';

@BasePath("/")
export class DataService extends BaseService {

  /**
   * 获取推荐视频
   * @param @Query('bvid') bvid 视频id
   */
  @GET("x/web-interface/archive/related")
  async getRelated(@Query('bvid') bvid: string):
    Promise<Response<RelatedResponse>> {
    return <Response<RelatedResponse>> {}
  };

  /**
   * 首页推荐视频（对齐 B 站网页版首页 feed 参数集，WBI 签名）
   * @param @Header('Cookie') cookie Cookie 请求头（设备 buvid + 登录 Cookie）
   * @param @Query('ps') ps 请求数量
   * @param @Query('fresh_idx_1h') fresh_idx_1h 1小时刷新索引
   * @param @Query('fresh_idx_4h') fresh_idx_4h 4小时刷新索引
   * @param @Query('fresh_idx') fresh_idx 刷新索引
   * @param @Query('fresh_type') fresh_type 刷新类型（网页版固定 4）
   * @param @Query('feed_version') feed_version 网页版现行 V2
   * @param @Query('w_rid') wRid WBI 签名
   * @param @Query('wts') wts 签名时间戳
   */
  @GET("x/web-interface/index/top/feed/rcmd")
  // 必须带浏览器 UA/Referer：gaia 风控按请求头指纹放行，缺失时连刷几次即被拦截（推荐刷不出）
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getRecommend(@Header('Cookie') cookie: string,
                     @Query('ps') ps: number,
                     @Query('fresh_idx_1h') fresh_idx_1h: number,
                     @Query('fresh_idx_4h') fresh_idx_4h: number,
                     @Query('fresh_idx') fresh_idx: number,
                     @Query('fresh_type') fresh_type: number,
                     @Query('feed_version') feed_version: string,
                     @Query('w_rid') wRid: string,
                     @Query('wts') wts: string):
    Promise<Response<RecommendResponse>> {
    return <Response<RecommendResponse>> {}
  };

  /**
   * 获取热门视频（对齐网页版：携带 Cookie，ps 由调用方传入网页版分页大小）
   * 风控检测：不带浏览器 User-Agent 时 B 站返回 200 + code=-352（39 字节桩响应，无 data），需按风控处理
   * @param @Header('Cookie') cookie Cookie 请求头
   * @param @Query('ps') ps 请求数量
   * @param @Query('pn') pn 请求页码
   */
  @GET("x/web-interface/popular")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getPopular(@Header('Cookie') cookie: string,
                   @Query('ps') ps: number,
                   @Query('pn') pn: number):
    Promise<Response<PopularResponse>> {
    return <Response<PopularResponse>> {}
  };

  /**
   * 获取视频播放链接
   * @param @Query('bvid') bvid 视频id
   * @param @Query('cid') cid
   */
  @GET("x/player/playurl")
  async getPlayUrl(@Query('bvid') bvid: string,
                   @Query('cid') cid: number):
    Promise<Response<PlayUrlResponse>> {
    return <Response<PlayUrlResponse>> {}
  };

  /**
   * 获取视频评论
   * 风控规避：匿名请求易触发 -412/-352（连刷后全站评论失效），对齐网页版请求头并携带 Cookie
   * @param @Header('Cookie') cookie Cookie 请求头
   * @param @Query('oid') oid bvid视频id
   * * @param @Query('ps') ps 每页项数
   * @param @Query('pn') pn 页码
   * @param @Query('type') type 评论类型
   * @param @Query('sort') sort 排序
   */
  @GET("x/v2/reply/main")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getReply(@Header('Cookie') cookie: string,
                 @Query('oid') oid: string,
                 @Query('ps') ps: number,
                 @Query('next') next: number,
                 @Query('type') type: number,
                 @Query('sort') sort: number):
    Promise<Response<ReplyResponse>> {
    return <Response<ReplyResponse>> {}
  };

  /**
   * 获取评论的子回复列表
   * 风控规避：同 getReply，对齐网页版请求头并携带 Cookie
   */
  @GET("x/v2/reply/reply")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getReplyDetail(@Header('Cookie') cookie: string,
                       @Query('oid') oid: string,
                       @Query('root') root: number,
                       @Query('ps') ps: number,
                       @Query('pn') pn: number,
                       @Query('type') type: number):
    Promise<Response<ReplyDetailResponse>> {
    return <Response<ReplyDetailResponse>> {}
  };

  /**
   * 评论点赞/取消点赞（POST，csrf 鉴权）
   * 注：本端点仅接受 action 1=点赞 0=取消点赞，点踩传 2 会返回 12011「不合法的赞或踩」，
   * 点踩必须走 replyHate 端点
   * @param oid 视频 aid
   * @param rpid 评论 rpid
   */
  @POST("x/v2/reply/action")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async replyAction(@Header('Cookie') cookie: string,
                    @Query('oid') oid: number,
                    @Query('type') type: number,
                    @Query('rpid') rpid: number,
                    @Query('action') action: number,
                    @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>> {}
  };

  /**
   * 评论点踩/取消点踩（POST，csrf 鉴权）——独立于点赞的端点
   * @param oid 视频 aid
   * @param rpid 评论 rpid
   * @param action 1=点踩 0=取消点踩
   */
  @POST("x/v2/reply/hate")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async replyHate(@Header('Cookie') cookie: string,
                  @Query('oid') oid: number,
                  @Query('type') type: number,
                  @Query('rpid') rpid: number,
                  @Query('action') action: number,
                  @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>> {}
  };

  /**
   * 发表评论/回复（POST，csrf 鉴权）
   * @param oid 视频 aid
   * @param root 根评论 rpid（0=顶级评论）
   * @param parent 父评论 rpid（0=顶级评论；回复楼中楼时=root 或被回复者 rpid）
   * @param message 评论内容
   */
  @POST("x/v2/reply/add")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async replyAdd(@Header('Cookie') cookie: string,
                 @Query('oid') oid: number,
                 @Query('type') type: number,
                 @Query('root') root: number,
                 @Query('parent') parent: number,
                 @Query('message') message: string,
                 @Query('plat') plat: number,
                 @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>> {}
  };

  /**
   * 删除自己的评论（POST，csrf 鉴权，仅限本人评论）
   * @param oid 视频 aid
   * @param rpid 评论 rpid
   */
  @POST("x/v2/reply/del")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async replyDel(@Header('Cookie') cookie: string,
                 @Query('oid') oid: number,
                 @Query('type') type: number,
                 @Query('rpid') rpid: number,
                 @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>> {}
  };

  /**
   * 获取视频弹幕
   * @param @Query('oid') oid cid值
   * @param @Query('type') type 弹幕类型：1 视频弹幕
   * @param @Query('segment_index') segmentIndex 弹幕包索引
   */
  @GET("x/v2/dm/list/seg.so")
  @Headers({ 'Content-Type': 'application/octet-stream' })
  async getDmList(@Query('oid') oid: number,
                  @Query('type') type: number,
                  @Query('segment_index') segmentIndex: number):
    Promise<Response<ArrayBuffer>> {
    return <Response<ArrayBuffer>> {}
  };

  /**
   * 获取热搜榜
   */
  @GET("x/v2/search/trending/ranking")
  async getRanking():
    Promise<Response<RankingResponse>> {
    return <Response<RankingResponse>> {}
  };

  /**
   * 搜索请求（对齐 B 站网页版：WBI 签名端点 + 真实 Cookie + 浏览器 UA/Referer）
   * 风控检测：不带浏览器 User-Agent 时 B 站返回 200 + data.v_voucher（无 result），需按风控处理
   * @param @Header('Cookie') cookie Cookie 请求头（设备 buvid + 登录 Cookie）
   * @param @Query('search_type') search_type 搜索类型（video 等）
   * @param @Query('keyword') keyword 搜索关键字（已 URL 编码）
   * @param @Query('page') page 页码
   * @param @Query('w_rid') wRid WBI 签名
   * @param @Query('wts') wts 签名时间戳
   */
  @GET("x/web-interface/wbi/search/type")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getSearch(@Header('Cookie') cookie: string,
                  @Query('search_type') search_type: string,
                  @Query('keyword') keyword: string,
                  @Query('page') page: number,
                  @Query('w_rid') wRid: string,
                  @Query('wts') wts: string):
    Promise<Response<SearchResponse>> {
    return <Response<SearchResponse>> {}
  };

  /**
   * 获取视频分P列表
   * 风控规避：不带浏览器 User-Agent 时 B 站返回 HTTP 412（2026-11 实测），需与网页版请求头对齐
   * @param @Query('bvid') bvid 视频id
   * @returns
   */
  @GET("x/player/pagelist")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getPageList(@Query('bvid') bvid: string):
    Promise<Response<VideoPartsResponse>> {
    return <Response<VideoPartsResponse>> {}
  };

  /**
   * 获取默认搜索
   * @returns
   */
  @GET("x/web-interface/search/default")
  async getSearchDefault():
    Promise<Response<SearchDefaultResponse>> {
    return <Response<SearchDefaultResponse>> {}
  };

  /**
   * 获取视频详情（aid/cid/stat，网页版视频页主接口，替代已下线的 archive/stat）
   * 端点勘误：旧 x/web-interface/archive/stat 已于 2026-11 前后下线
   * （不带 UA 返回 412，带浏览器 UA 亦 404）；现行网页版取视频状态走
   * x/web-interface/view（来源：bilibili.com 视频页 bundle 实证 + 接口实测）。
   * 匿名可访问（无需 WBI/登录 Cookie），但不带浏览器 User-Agent 时 HTTP 412。
   * @param @Query('bvid') bvid 视频id
   * @returns
   */
  @GET("x/web-interface/view")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getVideoView(@Query('bvid') bvid: string):
    Promise<Response<ViewResponse>> {
    return <Response<ViewResponse>> {}
  };

  /**
   * 获取视频简介
   * 风控规避：不带浏览器 User-Agent 时 B 站返回 HTTP 412（2026-11 实测），需与网页版请求头对齐
   * @returns
   */
  @GET("x/web-interface/archive/desc")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getArchiveDesc(@Query('bvid') bvid: string):
    Promise<Response<StringResponse>> {
    return <Response<StringResponse>> {}
  };

  /**
   * 获取支持的电话号码国际冠字码
   * @returns
   */
  @GET("web/generic/country/list")
  async getGenericCountryList():
    Promise<Response<CountryListResponse>>{
    return <Response<CountryListResponse>>{};
  }

  /**
   * 请求发送手机验证码
   * @param cid 国际冠字码
   * @param tel 手机号码
   * @param sessionId 登录标识
   * @param captchaToken 登录API token，来自于captcha
   * @param geeChallenge 极验 challenge， 来自于captcha
   * @param geeValidate 极验 result， 来自于captcha
   * @param geeSecCode 极验result+"|jordan"， 来自于captcha
   * @param channel 登录通道，如无特殊，则应为"bili"
   * @param buvid await StringUtil.generateBuvid()
   * @param localId await StringUtil.generateBuvid()
   * @param statistics {"appId":1,"platform":3,"version":"7.27.0","abtest":""}
   * @returns
   */
  @POST("x/passport-login/sms/send")
  async sendSmsCaptcha(
    @Query('cid') cid: number,
    @Query('tel') tel: number,
    @Query('login_session_id') sessionId: string,
    @Query('recaptcha_token') captchaToken: string,
    @Query('gee_challenge') geeChallenge: string,
    @Query('gee_validate') geeValidate: string,
    @Query('gee_seccode') geeSecCode: string,
    @Query('channel') channel: string,
    @Query('buvid') buvid: string,
    @Query('local_id') localId: string,
    @Query('statistics') statistics: string
  ): Promise<Response<SendSmsCaptchaResponse>>
  {
    return <Response<SendSmsCaptchaResponse>>{};
  }

  /**
   * 使用短信验证码登录
   * @param cid 国际冠字码
   * @param tel 电话号码
   * @param sessionId 登录标识，与sendSmsCaptcha一致
   * @param code 短信验证码
   * @param captchaKey 短信登录token，来源于SendSmsCaptchaResponse
   * @returns
   */
  @POST("x/passport-login/login/sms")
  async loginViaSmsCaptcha(
    @Query('cid') cid: number,
    @Query('tel') tel: number,
    @Query('login_session_id') sessionId: string,
    @Query('code') code: number,
    @Query('captcha_key') captchaKey: string
  ): Promise<Response<SmsLoginResponse>> {
    return <Response<SmsLoginResponse>>{};
  }

  /**
   * 获取用户卡片信息，包含用户粉丝数量及用户投稿数量
   * 风控规避：不带浏览器 User-Agent 时 B 站返回 code=-352（风控校验失败），需与网页版请求头对齐
   * @param mid 用户mid
   * @param photo 是否需要获取用户主页头图，默认false
   * @returns
   */
  @GET("x/web-interface/card")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getUserCardInfo(@Query("mid") mid: number, @Query("photo") photo: boolean = false): Promise<Response<CardInfoResponse>> {
    return <Response<CardInfoResponse>>{};
  }

  /**
   * 生成B站Web端扫码登录二维码
   * @returns data: {url 二维码内容, qrcode_key 轮询键}
   */
  @GET("x/passport-login/web/qrcode/generate")
  async generateQrCode(): Promise<Response<QrCodeGenerateResponse>> {
    return <Response<QrCodeGenerateResponse>>{};
  }

  /**
   * 轮询扫码登录状态
   * @param qrcodeKey 生成二维码时返回的 qrcode_key
   * 顶层业务码：86101 未扫码 / 86090 已扫码待确认 / 86038 已过期 / 0 成功
   */
  @GET("x/passport-login/web/qrcode/poll")
  async pollQrCode(@Query('qrcode_key') qrcodeKey: string): Promise<Response<QrPollResponse>> {
    return <Response<QrPollResponse>>{};
  }

  /**
   * 获取用户导航信息（校验登录态并获取昵称头像，含 WBI 签名密钥 wbi_img）
   * @param cookie Cookie 请求头：SESSDATA=...; bili_jct=...; DedeUserID=...
   */
  @GET("x/web-interface/nav")
  async getNavInfo(@Header('Cookie') cookie: string): Promise<Response<NavResponse>> {
    return <Response<NavResponse>>{};
  }

  /**
   * 获取 Web 端设备指纹 Cookie（buvid3/buvid4）
   * 响应 data: { b_3: buvid3, b_4: buvid4 }
   */
  @GET("x/frontend/finger/spi")
  async getFingerSpi(): Promise<Response<FingerSpiResponse>> {
    return <Response<FingerSpiResponse>>{};
  }

  /**
   * 获取关注 UP 主动态流（对齐网页版动态页，offset 游标分页）
   * 业务码 -101 表示登录失效
   * @param @Header('Cookie') cookie Cookie 请求头（设备 buvid + 登录 Cookie）
   * @param timezone_offset 时区偏移（网页版固定 -480）
   * @param offset 分页游标（首页空串）
   * @param features 特性开关（itemOpusStyle：新版图文格式）
   */
  @GET("x/polymer/web-dynamic/v1/feed/all")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': 'https://t.bilibili.com' })
  async getDynamicFeed(@Header('Cookie') cookie: string,
                       @Query('timezone_offset') timezoneOffset: number,
                       @Query('offset') offset: string,
                       @Query('features') features: string):
    Promise<Response<DynamicFeedResponse>> {
    return <Response<DynamicFeedResponse>>{};
  }

  /**
   * 获取用户空间资料（WBI 签名，风控敏感，失败时调用方降级）
   * @param @Header('Cookie') cookie Cookie 请求头
   * @param mid 用户 mid
   * @param w_rid WBI 签名
   * @param wts 签名时间戳
   */
  @GET("x/space/wbi/acc/info")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': 'https://space.bilibili.com' })
  async getSpaceAccInfo(@Header('Cookie') cookie: string,
                        @Query('mid') mid: number,
                        @Query('w_rid') wRid: string,
                        @Query('wts') wts: string):
    Promise<Response<SpaceAccInfoResponse>> {
    return <Response<SpaceAccInfoResponse>>{};
  }

  /**
   * 获取用户投稿视频列表（WBI 签名，风控敏感，失败时降级 series 接口）
   * 业务码 -352 表示风控
   * @param @Header('Cookie') cookie Cookie 请求头
   * @param mid 用户 mid
   * @param pn 页码
   * @param ps 每页项数
   * @param order 排序（pubdate 按发布时间）
   * @param w_rid WBI 签名
   * @param wts 签名时间戳
   */
  @GET("x/space/wbi/arc/search")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': 'https://space.bilibili.com' })
  async getSpaceArcSearch(@Header('Cookie') cookie: string,
                          @Query('mid') mid: number,
                          @Query('pn') pn: number,
                          @Query('ps') ps: number,
                          @Query('order') order: string,
                          @Query('w_rid') wRid: string,
                          @Query('wts') wts: string):
    Promise<Response<SpaceArcSearchResponse>> {
    return <Response<SpaceArcSearchResponse>>{};
  }

  /**
   * 获取用户关注/粉丝数（公开接口，无需 WBI 签名与登录）
   * @param vmid 用户 mid
   */
  @GET("x/relation/stat")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': 'https://space.bilibili.com' })
  async getRelationStat(@Query('vmid') vmid: number):
    Promise<Response<RelationStatResponse>> {
    return <Response<RelationStatResponse>>{};
  }

  /**
   * 获取用户投稿视频列表（降级接口，无需 WBI 签名）
   * 风控规避：不带浏览器 User-Agent 时 B 站可能返回 HTTP 412，需与网页版请求头对齐
   * @param mid 用户mid
   * @param keywords 过滤关键字（空串 = 全部投稿）
   * @param ps 每页项数
   * @param pn 页码
   */
  @GET("x/series/recArchivesByKeywords")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': 'https://space.bilibili.com' })
  async getSeriesArchives(@Query('mid') mid: number,
                          @Query('keywords') keywords: string,
                          @Query('ps') ps: number,
                          @Query('pn') pn: number):
    Promise<Response<SeriesArchivesResponse>> {
    return <Response<SeriesArchivesResponse>>{};
  }

  /**
   * 获取云端历史记录（Cookie 鉴权，max/view_at/business 游标分页）
   * 2026 现行 web 版接口（网页历史页 app bundle 实证）；
   * 旧端点 x/v2/history 已对 web 会话封闭（-108 应用不存在或者被封禁）。
   * 风控规避：与网页版浏览器请求对齐（该接口网页版不带 WBI 签名）。
   * @param @Header('Cookie') cookie Cookie 请求头（登录 Cookie）
   * @param max 分页游标：上一页末条 view_at（首页 0）
   * @param viewAt 分页游标：同 max（首页 0）
   * @param business 上一页末条的 history.business（首页空串）
   */
  @GET("x/web-interface/history/cursor")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getHistory(@Header('Cookie') cookie: string,
                   @Query('max') max: number,
                   @Query('view_at') viewAt: number,
                   @Query('business') business: string):
    Promise<Response<HistoryResponse>> {
    return <Response<HistoryResponse>>{};
  }

  /**
   * 删除单条历史记录（POST，csrf 鉴权）
   * 端点勘误：旧端点 x/v2/history/del 已对 web 会话封闭（-108 应用不存在或被封禁），
   * 2026 现行 web 版为 x/v2/history/delete（来源：bilibili.com/account/history 主 bundle 实证）
   * @param kid 条目标识：{business}_{kid}（如 archive_170001，business 取条目 history.business）
   */
  @POST("x/v2/history/delete")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async deleteHistory(@Header('Cookie') cookie: string,
                      @Query('kid') kid: string,
                      @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>>{};
  }

  /**
   * 清空全部历史记录（POST，csrf 鉴权，不可恢复）
   */
  @POST("x/v2/history/clear")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async clearHistory(@Header('Cookie') cookie: string,
                     @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>>{};
  }

  /**
   * 获取收藏夹列表（含默认夹，Cookie 鉴权）
   * 携带 rid+type 时每夹返回 fav_state 标记该视频是否已收藏于该夹
   * @param upMid 用户 mid
   * @param rid 视频 aid（视频页收藏入口传入以取 fav_state，其余场景 0）
   * @param type 资源类型（2=视频）
   */
  @GET("x/v3/fav/folder/created/list-all")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getFavFolders(@Header('Cookie') cookie: string,
                      @Query('up_mid') upMid: number,
                      @Query('rid') rid: number,
                      @Query('type') type: number):
    Promise<Response<FavFolderResponse>> {
    return <Response<FavFolderResponse>>{};
  }

  /**
   * 获取收藏夹内容列表（pn/ps 分页，Cookie 鉴权）
   * @param mediaId 收藏夹 media_id
   * @param pn 页码
   * @param ps 每页项数
   * @param keyword 关键字过滤（空串 = 全部）
   * @param order 排序（mtime 按收藏时间）
   * @param type 资源类型（0=全部）
   * @param tid 分区 tid（0=全部）
   * @param platform 平台（web）
   */
  @GET("x/v3/fav/resource/list")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getFavResources(@Header('Cookie') cookie: string,
                        @Query('media_id') mediaId: number,
                        @Query('pn') pn: number,
                        @Query('ps') ps: number,
                        @Query('keyword') keyword: string,
                        @Query('order') order: string,
                        @Query('type') type: number,
                        @Query('tid') tid: number,
                        @Query('platform') platform: string):
    Promise<Response<FavResourceResponse>> {
    return <Response<FavResourceResponse>>{};
  }

  /**
   * 收藏/取消收藏（POST，csrf 鉴权）：将视频加入/移出多个收藏夹
   * @param rid 视频 aid
   * @param addMediaIds 加入的收藏夹 media_id 逗号分隔（空串 = 无）
   * @param delMediaIds 移出的收藏夹 media_id 逗号分隔（空串 = 无）
   */
  @POST("x/v3/fav/resource/deal")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async favDeal(@Header('Cookie') cookie: string,
                @Query('rid') rid: number,
                @Query('type') type: number,
                @Query('add_media_ids') addMediaIds: string,
                @Query('del_media_ids') delMediaIds: string,
                @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>>{};
  }

  /**
   * 获取稍后再看列表（Cookie 鉴权，全量单页返回，上限约 300 条）
   */
  @GET("x/v2/history/toview/web")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getWatchLater(@Header('Cookie') cookie: string):
    Promise<Response<WatchLaterResponse>> {
    return <Response<WatchLaterResponse>>{};
  }

  /**
   * 添加视频到稍后再看（POST，csrf 鉴权）
   * @param aid 视频 aid
   */
  @POST("x/v2/history/toview/add")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async addWatchLater(@Header('Cookie') cookie: string,
                      @Query('aid') aid: number,
                      @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>>{};
  }

  /**
   * 从稍后再看移除视频（POST，csrf 鉴权）
   * @param aid 视频 aid
   */
  @POST("x/v2/history/toview/del")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async removeWatchLater(@Header('Cookie') cookie: string,
                         @Query('aid') aid: number,
                         @Query('csrf') csrf: string):
    Promise<Response<EmptyResponse>> {
    return <Response<EmptyResponse>>{};
  }

  /**
   * 获取指定清晰度的播放地址（离线缓存选档用，扩展自 getPlayUrl）
   * platform=html5&high_quality=1&fnval=0 返回 mp4 durl（含 size）与 accept_quality 档位表；
   * 携带登录 Cookie 可解锁更高清晰度档位
   * @param qn 清晰度档位值（16/32/64/80 等）
   * @param platform 平台（html5）
   * @param highQuality 高清标记（1）
   * @param fnval 格式标记（0=durl）
   */
  @GET("x/player/playurl")
  @Headers({ 'User-Agent': ApiConstants.userAgent, 'Referer': ApiConstants.biliBase })
  async getPlayUrlWithQn(@Header('Cookie') cookie: string,
                         @Query('bvid') bvid: string,
                         @Query('cid') cid: number,
                         @Query('qn') qn: number,
                         @Query('platform') platform: string,
                         @Query('high_quality') highQuality: number,
                         @Query('fnval') fnval: number):
    Promise<Response<PlayUrlResponse>> {
    return <Response<PlayUrlResponse>>{};
  }
}
