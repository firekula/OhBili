/**
 * Copyright (c) 2023 Wathinst <wxz@kzhineng.com>
 * OhBili is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 * http://license.coscl.org.cn/MulanPSL2
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 * See the Mulan PSL v2 for more details.
 */

import { BiliDash, BiliDashStream, BiliDashAudioStream, BiliSegmentBase } from '../model/response/PlayUrlResponse';
import { BLog } from '../utils/BLog';

export interface DashMpdOptions {
    /** 如 "http://127.0.0.1:34567" */
    proxyBase: string
    /** 'avc1' | 'hev1' | 'av01' */
    codecPreference: string
    /** -1=自动全量；>0=仅保留 id==pinQn 的视频 Representation */
    pinQn: number
}

export class DashMpdBuilder {
    static build(dash: BiliDash, opts: DashMpdOptions): string {
        if (dash.video == null) {
            return '';
        }
        let videos: BiliDashStream[] = DashMpdBuilder.selectVideos(dash.video, opts);
        if (videos.length == 0) {
            return '';
        }
        let videoReps: string[] = [];
        for (let i = 0; i < videos.length; i++) {
            let rep: string = DashMpdBuilder.buildVideoRep(videos[i], opts);
            if (rep.length > 0) {
                videoReps.push(rep);
            }
        }
        let audioRep: string = '';
        let audio: BiliDashAudioStream | null = DashMpdBuilder.selectAudio(dash);
        if (audio != null) {
            audioRep = DashMpdBuilder.buildAudioRep(audio, opts);
        }
        if (videoReps.length == 0 && audioRep.length == 0) {
            return '';
        }
        let durationMs: number = dash.duration ?? 0;
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
        for (let i = 0; i < videoReps.length; i++) {
            xml += videoReps[i];
        }
        xml += '    </AdaptationSet>\n';
        xml += '    <AdaptationSet id="1" contentType="audio" mimeType="audio/mp4"'
            + ' segmentAlignment="true" startWithSAP="1">\n';
        xml += audioRep;
        xml += '    </AdaptationSet>\n';
        xml += '  </Period>\n';
        xml += '</MPD>\n';
        return xml;
    }

    private static selectVideos(videoList: BiliDashStream[], opts: DashMpdOptions): BiliDashStream[] {
        let chain: string[] = [opts.codecPreference, 'av01', 'hev1', 'avc1'];
        let candidates: string[] = [];
        for (let i = 0; i < chain.length; i++) {
            if (candidates.indexOf(chain[i]) < 0) {
                candidates.push(chain[i]);
            }
        }
        for (let i = 0; i < candidates.length; i++) {
            let matched: BiliDashStream[] = DashMpdBuilder.filterByCodec(videoList, candidates[i]);
            if (matched.length > 0) {
                return DashMpdBuilder.applyPinQn(matched, opts);
            }
        }
        return [];
    }

    private static filterByCodec(videoList: BiliDashStream[], codec: string): BiliDashStream[] {
        let matched: BiliDashStream[] = [];
        for (let i = 0; i < videoList.length; i++) {
            let codecs: string = videoList[i].codecs ?? '';
            if (DashMpdBuilder.matchCodec(codecs, codec)) {
                matched.push(videoList[i]);
            }
        }
        return matched;
    }

    private static matchCodec(codecs: string, codec: string): boolean {
        if (codec == 'hev1') {
            return codecs.startsWith('hev1') || codecs.startsWith('hvc1');
        }
        return codecs.startsWith(codec);
    }

    private static applyPinQn(videos: BiliDashStream[], opts: DashMpdOptions): BiliDashStream[] {
        if (opts.pinQn <= 0) {
            return videos;
        }
        let pinned: BiliDashStream[] = [];
        for (let i = 0; i < videos.length; i++) {
            if (videos[i].id == opts.pinQn) {
                pinned.push(videos[i]);
            }
        }
        if (pinned.length == 0) {
            BLog.i('DashMpdBuilder: pinQn=' + opts.pinQn + ' not in video set, keep all filtered streams');
            return videos;
        }
        return pinned;
    }

    private static selectAudio(dash: BiliDash): BiliDashAudioStream | null {
        if (dash.audio == null) {
            return null;
        }
        let best: BiliDashAudioStream | null = null;
        for (let i = 0; i < dash.audio.length; i++) {
            let a: BiliDashAudioStream = dash.audio[i];
            if (!DashMpdBuilder.hasUsableSegmentBase(a.SegmentBase)) {
                continue;
            }
            if (best == null) {
                best = a;
            } else if (a.bandwidth > best.bandwidth) {
                best = a;
            }
        }
        return best;
    }

    private static hasUsableSegmentBase(sb: BiliSegmentBase | undefined): boolean {
        if (sb == null) {
            return false;
        }
        let indexRange: string | undefined = sb.indexRange;
        let initialization: string | undefined = sb.Initialization;
        return indexRange != null && initialization != null;
    }

    private static buildVideoRep(s: BiliDashStream, opts: DashMpdOptions): string {
        let sb: BiliSegmentBase | undefined = s.SegmentBase;
        if (sb == null) {
            return '';
        }
        let indexRange: string | undefined = sb.indexRange;
        let initialization: string | undefined = sb.Initialization;
        if (indexRange == null || initialization == null) {
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
        rep += '        <BaseURL>' + DashMpdBuilder.escapeXml(DashMpdBuilder.toProxyUrl(s.baseUrl, opts)) + '</BaseURL>\n';
        rep += '        <SegmentBase indexRange="' + indexRange + '" timescale="1000">\n';
        rep += '          <Initialization range="' + initialization + '"/>\n';
        rep += '        </SegmentBase>\n';
        rep += '      </Representation>\n';
        return rep;
    }

    private static buildAudioRep(s: BiliDashAudioStream, opts: DashMpdOptions): string {
        let sb: BiliSegmentBase | undefined = s.SegmentBase;
        if (sb == null) {
            return '';
        }
        let indexRange: string | undefined = sb.indexRange;
        let initialization: string | undefined = sb.Initialization;
        if (indexRange == null || initialization == null) {
            return '';
        }
        let rep: string = '';
        rep += '      <Representation id="' + s.id + '"'
            + ' codecs="' + (s.codecs ?? 'mp4a.40.2') + '"'
            + ' bandwidth="' + (s.bandwidth ?? 0) + '">\n';
        rep += '        <BaseURL>' + DashMpdBuilder.escapeXml(DashMpdBuilder.toProxyUrl(s.baseUrl, opts)) + '</BaseURL>\n';
        rep += '        <SegmentBase indexRange="' + indexRange + '" timescale="1000">\n';
        rep += '          <Initialization range="' + initialization + '"/>\n';
        rep += '        </SegmentBase>\n';
        rep += '      </Representation>\n';
        return rep;
    }

    private static toProxyUrl(url: string, opts: DashMpdOptions): string {
        return opts.proxyBase + '/seg?url=' + encodeURIComponent(DashMpdBuilder.fixUrl(url));
    }

    private static fixUrl(url: string): string {
        return url.replace(/\\u0026/g, '&');
    }

    private static escapeXml(s: string): string {
        return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&apos;');
    }
}
