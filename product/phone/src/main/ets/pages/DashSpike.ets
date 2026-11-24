/**
 * [SPIKE 一次性验证代码] DASH 播放链路验证页，验证后整页删除。
 *
 * 验证目标（方案 A 的两个生死点）：
 *  1. fnval=4048 的 wbi playurl 能否返回 dash 音视频分离流；
 *  2. 本地拼装 MPD（SegmentBase 字节区间形式）经本地 HTTP 服务分发，
 *     能否被系统 AvPlayer 的 DASH demuxer 解析播放；
 *  3. MediaSource 自定义请求头（UA/Referer）不透传到 CDN 段请求（实测 403），
 *     由本地段代理注入头解决（重写 BaseURL -> 127.0.0.1 代理）。
 *
 * 页面自动执行全链路并滚动输出日志（同步写 hilog，tag 前缀 DashSpike）。
 */

import media from '@ohos.multimedia.media';
import fs from '@ohos.file.fs';
import socket from '@ohos.net.socket';
import util from '@ohos.util';
import http from '@ohos.net.http';
import router from '@ohos.router';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { ApiManager, ApiConstants, BLog } from '@ohos/common';
import { PlayUrl, PlayUrlResponse, BiliDash, BiliDashStream, BiliDashAudioStream, BiliSegmentBase } from '@ohos/common';

/** 稳定的公共视频（Rick Astley - Never Gonna Give You Up） */
let SPIKE_BVID: string = 'BV1GJ411x7h7';

/** 本地 HTTP 服务固定端口 */
let SPIKE_PORT: number = 34567;

@Entry
@Component
struct DashSpike {
  @State logText: string = '';
  @State running: boolean = false;
  private xcController: XComponentController = new XComponentController();
  private player: media.AVPlayer | null = null;
  private httpServer: socket.TCPSocketServer | null = null;
  private mpdContent: string = '';
  private surfaceId: string = '';
  private progressTimer: number = -1;

  private log(msg: string): void {
    let now: Date = new Date();
    let ts: string = now.getHours() + ':' + now.getMinutes() + ':' + now.getSeconds();
    this.logText += '[' + ts + '] ' + msg + '\n';
    BLog.i('DashSpike: ' + msg);
  }

  aboutToDisappear(): void {
    this.stopPlayer();
  }

  private stopPlayer(): void {
    if (this.progressTimer >= 0) {
      clearInterval(this.progressTimer);
      this.progressTimer = -1;
    }
    let p: media.AVPlayer | null = this.player;
    this.player = null;
    let srv: socket.TCPSocketServer | null = this.httpServer;
    this.httpServer = null;
    if (p != null) {
      try {
        p.release();
      } catch (err) {
        BLog.w('DashSpike release err: ' + JSON.stringify(err));
      }
    }
    if (srv != null) {
      try {
        srv.close();
      } catch (err) {
        BLog.w('DashSpike close http server err');
      }
    }
  }

  private rerun(): void {
    this.stopPlayer();
    this.logText = '';
    this.running = false;
    this.autoRun();
  }

  private async autoRun(): Promise<void> {
    if (this.running) {
      return;
    }
    this.running = true;
    try {
      // step1: 解析 cid
      this.log('step1: requestPageList bvid=' + SPIKE_BVID);
      let parts = await ApiManager.getInstance().requestPageList(SPIKE_BVID);
      if (parts == null || parts.data == null || parts.data.length === 0) {
        this.log('FAIL: requestPageList empty');
        return;
      }
      let cid: number = parts.data[0].cid;
      this.log('cid=' + cid + ', page=' + parts.data[0].page);

      // step2: DASH playurl
      this.log('step2: wbi playurl fnval=4048 qn=80');
      let resp = await ApiManager.getInstance().requestPlayUrlWbiDash(SPIKE_BVID, cid, 80);
      // 新签名直接返回响应体（请求失败/业务码非 0 时为 null，详见 ApiManager 日志）
      let body: PlayUrlResponse | null = resp;
      if (body == null || body.code != 0 || body.data == null) {
        this.log('FAIL: playurl biz code=' + (body != null ? body.code : 'null')
          + ', msg=' + (body != null ? body.message : ''));
        return;
      }
      let playData: PlayUrl = body.data;
      let dash: BiliDash | null | undefined = playData.dash;
      if (dash == null || dash.video == null || dash.video.length === 0) {
        this.log('FAIL: no dash field, format=' + playData.format
          + ', durl=' + (playData.durl != null ? playData.durl.length : 0));
        return;
      }
      this.log('dash ok: video=' + dash.video.length
        + ', audio=' + (dash.audio != null ? dash.audio.length : 0)
        + ', timelength=' + (playData.timelength ?? 0));
      let i: number = 0;
      for (i = 0; i < dash.video.length; i++) {
        let s: BiliDashStream = dash.video[i];
        this.log('  v id=' + s.id + ' ' + (s.width ?? 0) + 'x' + (s.height ?? 0)
          + ' codecs=' + s.codecs
          + ' segBase=' + (s.SegmentBase != null ? 'yes' : 'NO'));
      }

      // step3: 拼 MPD 并写沙箱
      this.log('step3: build mpd');
      let mpd: string = this.buildMpd(dash, playData);
      this.log('mpd length=' + mpd.length);
      let ctx = getContext(this);
      let mpdPath: string = ctx.filesDir + '/dash_spike.mpd';
      let file: fs.File = fs.openSync(mpdPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, mpd);
      fs.closeSync(file);
      this.log('mpd written: ' + mpdPath);

      // step3.5: 探针——直接用 http kit 带 UA/Referer 请求首个视频段，验证 URL + 头组合是否 200
      this.log('step3.5: probe segment url with UA/Referer headers');
      let probeUrl: string = this.fixUrl(dash.video[0].baseUrl);
      let probeClient: http.HttpRequest = http.createHttp();
      try {
        let probeResp: http.HttpResponse = await probeClient.request(probeUrl, {
          method: http.RequestMethod.GET,
          header: {
            'User-Agent': ApiConstants.userAgent,
            'Referer': ApiConstants.biliBase,
            'Range': 'bytes=0-99'
          },
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          readTimeout: 15000,
          connectTimeout: 10000
        });
        this.log('probe status=' + probeResp.responseCode
          + ', bytes=' + (probeResp.result instanceof ArrayBuffer ? (probeResp.result as ArrayBuffer).byteLength : 0));
      } catch (err) {
        this.log('probe EXCEPTION: ' + JSON.stringify(err));
      }
      probeClient.destroy();

      // step4: 极简本地 HTTP 服务：提供 MPD + 代理 CDN 段请求（附加 UA/Referer，透传 Range）
      this.log('step4: start local http server (mpd + segment proxy)');
      let port: number = SPIKE_PORT;
      this.mpdContent = mpd;
      let server: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
      this.httpServer = server;
      let listenAddr: socket.NetAddress = { address: '127.0.0.1', port: port, family: 1 };
      await server.listen(listenAddr);
      this.log('http server listening on 127.0.0.1:' + port);
      server.on('connect', (client: socket.TCPSocketConnection) => {
        this.log('http: client connected');
        client.on('message', (info: socket.SocketMessageInfo) => {
          this.handleHttpData(client, info.message);
        });
      });

      // step5: 播放
      this.log('step5: createAVPlayer + setMediaSource(http mpd, headers)');
      let player: media.AVPlayer = await media.createAVPlayer();
      this.player = player;
      player.on('error', (err: BusinessError) => {
        this.log('ERROR event: code=' + err.code + ', msg=' + err.message);
      });
      player.on('stateChange', (state: media.AVPlayerState, reason: media.StateChangeReason) => {
        this.onPlayerState(state);
      });
      let headers: Record<string, string> = {
        'User-Agent': ApiConstants.userAgent,
        'Referer': ApiConstants.biliBase
      };
      let mpdUrl: string = 'http://127.0.0.1:' + port + '/dash_spike.mpd';
      let source: media.MediaSource = media.createMediaSourceWithUrl(mpdUrl, headers);
      let strategy: media.PlaybackStrategy = { preferredWidth: 1280, preferredHeight: 720 };
      await player.setMediaSource(source, strategy);
      this.log('setMediaSource resolved, state=' + player.state);
      // stateChange 事件未触发时兜底：直接在 initialized 状态调 prepare
      if (player.state === 'initialized') {
        this.log('stateChange event missed, fallback: prepare directly');
        player.surfaceId = this.surfaceId;
        player.prepare().then(() => {
          this.log('prepare resolved');
        }, (err: BusinessError) => {
          this.log('prepare rejected: ' + err.code + ', ' + err.message);
        });
      }
    } catch (err) {
      this.log('EXCEPTION: ' + JSON.stringify(err));
    }
  }

  /** 解析一次 HTTP 请求：/dash_spike.mpd 返回 MPD；/seg?url= 代理 CDN 段请求（附加 UA/Referer，透传 Range） */
  private handleHttpData(client: socket.TCPSocketConnection, msg: ArrayBuffer): void {
    let dec: util.TextDecoder = util.TextDecoder.create('utf-8');
    let reqStr: string = dec.decodeToString(new Uint8Array(msg));
    let headEnd: number = reqStr.indexOf('\r\n\r\n');
    let head: string = headEnd >= 0 ? reqStr.substring(0, headEnd) : reqStr;
    let lines: string[] = head.split('\r\n');
    let reqLine: string = lines.length > 0 ? lines[0] : '';
    let rangeHeader: string = '';
    for (let i = 1; i < lines.length; i++) {
      if (lines[i].toLowerCase().startsWith('range:')) {
        rangeHeader = lines[i].substring('range:'.length).trim();
      }
    }
    let parts: string[] = reqLine.split(' ');
    let path: string = parts.length > 1 ? parts[1] : '';
    if (path.startsWith('/seg?url=')) {
      let target: string = decodeURIComponent(path.substring('/seg?url='.length));
      this.proxySegment(client, target, rangeHeader);
    } else {
      this.log('http: GET ' + path);
      this.serveMpd(client);
    }
  }

  /** 代理 CDN 段请求：附加 UA/Referer，透传 Range，回传状态/长度/Content-Range */
  private async proxySegment(client: socket.TCPSocketConnection, target: string, range: string): Promise<void> {
    this.log('proxy: ' + (range.length > 0 ? range + ' ' : '') + target.substring(0, 60) + '...');
    let req: http.HttpRequest = http.createHttp();
    try {
      let header: Record<string, string> = {
        'User-Agent': ApiConstants.userAgent,
        'Referer': ApiConstants.biliBase
      };
      if (range.length > 0) {
        header['Range'] = range;
      }
      let resp: http.HttpResponse = await req.request(target, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 30000,
        connectTimeout: 10000
      });
      let body: ArrayBuffer = resp.result instanceof ArrayBuffer ? resp.result : new ArrayBuffer(0);
      // 从响应头 JSON 中提取 content-type / content-range（避免对 Object 动态取属性）
      let hs: string = JSON.stringify(resp.header);
      let contentType: string = this.extractHeaderValue(hs, 'content-type');
      let contentRange: string = this.extractHeaderValue(hs, 'content-range');
      let statusText: string = resp.responseCode === 206 ? 'Partial Content' : 'OK';
      let headStr: string = 'HTTP/1.1 ' + resp.responseCode + ' ' + statusText + '\r\n'
        + 'Content-Type: ' + (contentType.length > 0 ? contentType : 'application/octet-stream') + '\r\n'
        + 'Content-Length: ' + body.byteLength + '\r\n';
      if (contentRange.length > 0) {
        headStr += 'Content-Range: ' + contentRange + '\r\n';
      }
      headStr += 'Connection: close\r\n\r\n';
      this.sendHttpBody(client, headStr, body);
      this.log('proxy: resp ' + resp.responseCode + ', ' + body.byteLength + ' bytes'
        + (contentRange.length > 0 ? ', cr=' + contentRange : ''));
    } catch (err) {
      this.log('proxy EXCEPTION: ' + JSON.stringify(err));
      let headStr: string = 'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n';
      this.sendHttpBody(client, headStr, new ArrayBuffer(0));
    }
    req.destroy();
  }

  /** 从 JSON.stringify(header) 结果中提取指定头的值（键名大小写不敏感） */
  private extractHeaderValue(headerJson: string, name: string): string {
    let lower: string = headerJson.toLowerCase();
    let key: string = '"' + name + '":';
    let idx: number = lower.indexOf(key);
    if (idx < 0) {
      return '';
    }
    let valStart: number = headerJson.indexOf('"', idx + key.length);
    if (valStart < 0) {
      return '';
    }
    let valEnd: number = headerJson.indexOf('"', valStart + 1);
    if (valEnd < 0) {
      return '';
    }
    return headerJson.substring(valStart + 1, valEnd);
  }

  /** 发送 HTTP 响应（head 字符串 + body 字节） */
  private sendHttpBody(client: socket.TCPSocketConnection, headStr: string, body: ArrayBuffer): void {
    let encoder: util.TextEncoder = new util.TextEncoder();
    let head: Uint8Array = encoder.encodeInto(headStr);
    let total: number = head.byteLength + body.byteLength;
    let ab: ArrayBuffer = new ArrayBuffer(total);
    let all: Uint8Array = new Uint8Array(ab);
    all.set(head, 0);
    all.set(new Uint8Array(body), head.byteLength);
    let sendOpts: socket.TCPSendOptions = { data: ab };
    client.send(sendOpts).then(() => {
      client.close();
    }, (err: BusinessError) => {
      this.log('http: send fail ' + err.code);
      client.close();
    });
  }

  /** 应答一次 HTTP GET：返回内存中的 MPD 文本 */
  private serveMpd(client: socket.TCPSocketConnection): void {
    let encoder: util.TextEncoder = new util.TextEncoder();
    let body: Uint8Array = encoder.encodeInto(this.mpdContent);
    let headStr: string = 'HTTP/1.1 200 OK\r\n'
      + 'Content-Type: application/dash+xml\r\n'
      + 'Content-Length: ' + body.byteLength + '\r\n'
      + 'Connection: close\r\n\r\n';
    this.sendHttpBody(client, headStr, this.copyToArrayBuffer(body));
    this.log('http: mpd served (' + body.byteLength + ' bytes)');
  }

  private copyToArrayBuffer(u8: Uint8Array): ArrayBuffer {
    let ab: ArrayBuffer = new ArrayBuffer(u8.byteLength);
    new Uint8Array(ab).set(u8);
    return ab;
  }

  private onPlayerState(state: media.AVPlayerState): void {
    this.log('state: ' + state);
    let p: media.AVPlayer | null = this.player;
    if (p == null) {
      return;
    }
    if (state === 'initialized') {
      p.surfaceId = this.surfaceId;
      p.prepare().then(() => {
        this.log('prepare resolved');
      }, (err: BusinessError) => {
        this.log('prepare rejected: ' + err.code + ', ' + err.message);
      });
    } else if (state === 'prepared') {
      this.log('prepared: ' + p.width + 'x' + p.height + ', duration=' + p.duration);
      p.play();
    } else if (state === 'playing') {
      this.log('*** PLAYING — DASH pipeline OK ***');
      this.startProgressLog();
    }
  }

  private startProgressLog(): void {
    if (this.progressTimer >= 0) {
      return;
    }
    this.progressTimer = setInterval(() => {
      let p: media.AVPlayer | null = this.player;
      if (p != null) {
        this.log('t=' + Math.floor(p.currentTime / 1000) + 's / '
          + Math.floor(p.duration / 1000) + 's');
      }
    }, 5000);
  }

  /** 拼装本地 MPD：视频/音频各一个 AdaptationSet，SegmentBase 单文件字节区间形式 */
  private buildMpd(dash: BiliDash, playData: PlayUrl): string {
    let durationMs: number = playData.timelength ?? (dash.duration ?? 0);
    let minBuf: number = dash.min_buffer_time ?? 1.5;
    let xml: string = '<?xml version="1.0" encoding="UTF-8"?>\n';
    xml += '<MPD xmlns="urn:mpeg:dash:schema:mpd:2011"'
      + ' profiles="urn:mpeg:dash:profile:isoff-on-demand:2011"'
      + ' type="static"'
      + ' mediaPresentationDuration="PT' + (durationMs / 1000.0).toFixed(3) + 'S"'
      + ' minBufferTime="PT' + minBuf.toFixed(3) + 'S">\n';
    xml += '  <Period>\n';
    xml += '    <AdaptationSet id="0" contentType="video" mimeType="video/mp4"'
      + ' segmentAlignment="true" startWithSAP="1">\n';
    if (dash.video != null) {
      for (let i = 0; i < dash.video.length; i++) {
        // 部分设备无 AV1/HEVC 硬解，spike 仅保留 AVC 流验证管线
        let codecs: string = dash.video[i].codecs ?? '';
        if (!codecs.startsWith('avc1')) {
          continue;
        }
        xml += this.buildVideoRep(dash.video[i]);
      }
    }
    xml += '    </AdaptationSet>\n';
    xml += '    <AdaptationSet id="1" contentType="audio" mimeType="audio/mp4"'
      + ' segmentAlignment="true" startWithSAP="1">\n';
    if (dash.audio != null) {
      for (let i = 0; i < dash.audio.length; i++) {
        xml += this.buildAudioRep(dash.audio[i]);
      }
    }
    xml += '    </AdaptationSet>\n';
    xml += '  </Period>\n';
    xml += '</MPD>\n';
    return xml;
  }

  private buildVideoRep(s: BiliDashStream): string {
    let sb: BiliSegmentBase | undefined = s.SegmentBase;
    if (sb == null) {
      this.log('skip video rep id=' + s.id + ' (no SegmentBase)');
      return '';
    }
    let rep: string = '';
    rep += '      <Representation id="' + s.id + '"'
      + ' codecs="' + (s.codecs ?? 'avc1.640028') + '"'
      + ' width="' + (s.width ?? 0) + '"'
      + ' height="' + (s.height ?? 0) + '"'
      + ' frameRate="' + (s.frameRate ?? '25') + '"'
      + ' bandwidth="' + (s.bandwidth ?? 0) + '"'
      + ' sar="' + (s.sar ?? '1:1') + '">\n';
    rep += '        <BaseURL>' + this.escapeXml(this.toProxyUrl(s.baseUrl)) + '</BaseURL>\n';
    rep += '        <SegmentBase indexRange="' + sb.indexRange + '" timescale="1000">\n';
    rep += '          <Initialization range="' + sb.Initialization + '"/>\n';
    rep += '        </SegmentBase>\n';
    rep += '      </Representation>\n';
    return rep;
  }

  private buildAudioRep(s: BiliDashAudioStream): string {
    let sb: BiliSegmentBase | undefined = s.SegmentBase;
    if (sb == null) {
      this.log('skip audio rep id=' + s.id + ' (no SegmentBase)');
      return '';
    }
    let rep: string = '';
    rep += '      <Representation id="' + s.id + '"'
      + ' codecs="' + (s.codecs ?? 'mp4a.40.2') + '"'
      + ' bandwidth="' + (s.bandwidth ?? 0) + '">\n';
    rep += '        <BaseURL>' + this.escapeXml(this.toProxyUrl(s.baseUrl)) + '</BaseURL>\n';
    rep += '        <SegmentBase indexRange="' + sb.indexRange + '" timescale="1000">\n';
    rep += '          <Initialization range="' + sb.Initialization + '"/>\n';
    rep += '        </SegmentBase>\n';
    rep += '      </Representation>\n';
    return rep;
  }

  /** 段 URL 重写为本地代理 URL（代理附加 UA/Referer 并透传 Range） */
  private toProxyUrl(url: string): string {
    return 'http://127.0.0.1:' + SPIKE_PORT + '/seg?url=' + encodeURIComponent(this.fixUrl(url));
  }

  /** B站接口下发的 URL 偶含字面 \u0026 转义（& 的双重转义），统一还原 */
  private fixUrl(url: string): string {
    return url.replace(/\\u0026/g, '&');
  }

  private escapeXml(s: string): string {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&apos;');
  }

  build() {
    Column() {
      Text('DASH Spike 验证页（一次性）')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .padding(12)

      XComponent({
        id: 'dash_spike_xc',
        type: 'surface',
        controller: this.xcController
      })
        .onLoad(() => {
          this.surfaceId = this.xcController.getXComponentSurfaceId();
          this.log('XComponent loaded, surfaceId=' + this.surfaceId);
          this.autoRun();
        })
        .width('100%')
        .height(220)
        .backgroundColor('#000000')

      Row({ space: 12 }) {
        Button('重新运行')
          .fontSize(14)
          .onClick(() => {
            this.rerun();
          })
        Button('停止')
          .fontSize(14)
          .onClick(() => {
            this.stopPlayer();
            this.log('player stopped');
          })
        Button('复制日志')
          .fontSize(14)
          .onClick(() => {
            let data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.logText);
            pasteboard.getSystemPasteboard().setData(data);
            this.log('--- log copied to clipboard ---');
          })
        Button('返回首页')
          .fontSize(14)
          .onClick(() => {
            router.replaceUrl({ url: 'pages/Index' });
          })
      }
      .padding(12)

      Scroll() {
        Text(this.logText)
          .fontSize(11)
          .fontColor('#555555')
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 12 })
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
