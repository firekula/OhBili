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

import { http, socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import util from '@ohos.util';
import { ApiConstants } from '../network/ApiConstants';
import { BLog } from '../utils/BLog';

export class LocalDashServer {
    private static readonly BASE_PORT: number = 34567;
    private static readonly PORT_RETRY_COUNT: number = 10;
    private static readonly MPD_PATH: string = '/dash.mpd';
    private static readonly SEG_PREFIX: string = '/seg?url=';
    private static readonly ALLOWED_HOST_SUFFIXES: string[] =
        ['.bilivideo.com', '.bilivideo.cn', '.akamaized.net', '.hdslb.com'];

    private server: socket.TCPSocketServer | null = null;
    private boundPort: number = -1;
    private mpdContent: string = '';
    private stopped: boolean = false;
    private connections: Set<socket.TCPSocketConnection> = new Set<socket.TCPSocketConnection>();

    async start(): Promise<number> {
        if (this.server != null && this.boundPort > 0) {
            return this.boundPort;
        }
        for (let attempt: number = 0; attempt < LocalDashServer.PORT_RETRY_COUNT; attempt++) {
            let port: number = LocalDashServer.BASE_PORT + attempt;
            let candidate: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
            let listenAddr: socket.NetAddress = { address: '127.0.0.1', port: port, family: 1 };
            try {
                await candidate.listen(listenAddr);
            } catch (err) {
                BLog.w('LocalDashServer: listen on port ' + port + ' failed, retrying next port');
                LocalDashServer.closeServerQuietly(candidate);
                continue;
            }
            this.server = candidate;
            this.boundPort = port;
            this.stopped = false;
            this.registerConnectHandler(candidate);
            BLog.i('LocalDashServer: listening on 127.0.0.1:' + port);
            return port;
        }
        BLog.w('LocalDashServer: no available port after '
            + LocalDashServer.PORT_RETRY_COUNT + ' attempts');
        return -1;
    }

    stop(): void {
        this.stopped = true;
        this.mpdContent = '';
        let clients: socket.TCPSocketConnection[] = [];
        this.connections.forEach((client: socket.TCPSocketConnection) => {
            clients.push(client);
        });
        this.connections.clear();
        for (let i: number = 0; i < clients.length; i++) {
            LocalDashServer.closeQuietly(clients[i]);
        }
        let srv: socket.TCPSocketServer | null = this.server;
        this.server = null;
        this.boundPort = -1;
        if (srv != null) {
            LocalDashServer.closeServerQuietly(srv);
        }
        BLog.i('LocalDashServer: stopped');
    }

    updateMpd(mpd: string): void {
        this.mpdContent = mpd;
    }

    private registerConnectHandler(server: socket.TCPSocketServer): void {
        server.on('connect', (client: socket.TCPSocketConnection) => {
            if (this.stopped || this.server !== server) {
                LocalDashServer.closeQuietly(client);
                return;
            }
            this.connections.add(client);
            client.on('message', (info: socket.SocketMessageInfo) => {
                if (this.stopped || this.server !== server) {
                    LocalDashServer.closeQuietly(client);
                    return;
                }
                this.handleHttpData(client, info.message);
            });
            client.on('close', () => {
                this.connections.delete(client);
            });
            client.on('error', (err: BusinessError) => {
                BLog.w('LocalDashServer: connection error ' + err.code);
                this.connections.delete(client);
                LocalDashServer.closeQuietly(client);
            });
        });
    }

    private handleHttpData(client: socket.TCPSocketConnection, msg: ArrayBuffer): void {
        try {
            let dec: util.TextDecoder = util.TextDecoder.create('utf-8');
            let reqStr: string = dec.decodeToString(new Uint8Array(msg));
            let headEnd: number = reqStr.indexOf('\r\n\r\n');
            let head: string = headEnd >= 0 ? reqStr.substring(0, headEnd) : reqStr;
            let lines: string[] = head.split('\r\n');
            let reqLine: string = lines.length > 0 ? lines[0] : '';
            let rangeHeader: string = '';
            for (let i: number = 1; i < lines.length; i++) {
                if (lines[i].toLowerCase().startsWith('range:')) {
                    rangeHeader = lines[i].substring('range:'.length).trim();
                }
            }
            let parts: string[] = reqLine.split(' ');
            if (parts.length < 2 || parts[0].length === 0 || parts[1].length === 0) {
                this.sendSimpleResponse(client, 400, 'Bad Request');
                return;
            }
            let method: string = parts[0];
            let path: string = parts[1];
            if (method !== 'GET') {
                this.sendSimpleResponse(client, 405, 'Method Not Allowed');
                return;
            }
            if (path === LocalDashServer.MPD_PATH) {
                this.serveMpd(client);
            } else if (path.startsWith(LocalDashServer.SEG_PREFIX)) {
                this.handleSegmentRequest(client, path, rangeHeader);
            } else {
                this.sendSimpleResponse(client, 404, 'Not Found');
            }
        } catch (err) {
            BLog.w('LocalDashServer: request parse failed: ' + JSON.stringify(err));
            this.sendSimpleResponse(client, 400, 'Bad Request');
        }
    }

    private handleSegmentRequest(client: socket.TCPSocketConnection, path: string, rangeHeader: string): void {
        let target: string = '';
        try {
            target = decodeURIComponent(path.substring(LocalDashServer.SEG_PREFIX.length));
        } catch (err) {
            this.sendSimpleResponse(client, 400, 'Bad Request');
            return;
        }
        let host: string = LocalDashServer.extractHost(target);
        if (!LocalDashServer.isHostAllowed(host)) {
            BLog.w('LocalDashServer: blocked non-whitelisted host=' + host);
            this.sendSimpleResponse(client, 403, 'Forbidden');
            return;
        }
        this.proxySegment(client, target, rangeHeader);
    }

    private async proxySegment(client: socket.TCPSocketConnection, target: string, range: string): Promise<void> {
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
            if (resp.responseCode !== 200 && resp.responseCode !== 206) {
                BLog.w('LocalDashServer: upstream status ' + resp.responseCode + ', url=' + target.substring(0, 80));
                this.sendSimpleResponse(client, 502, 'Bad Gateway');
                return;
            }
            let headerJson: string = JSON.stringify(resp.header);
            let contentType: string = LocalDashServer.extractHeaderValue(headerJson, 'content-type');
            let contentRange: string = LocalDashServer.extractHeaderValue(headerJson, 'content-range');
            let contentLength: string = LocalDashServer.extractHeaderValue(headerJson, 'content-length');
            if (contentLength.length === 0 || parseInt(contentLength) !== body.byteLength) {
                contentLength = '' + body.byteLength;
            }
            let statusText: string = resp.responseCode === 206 ? 'Partial Content' : 'OK';
            let headStr: string = 'HTTP/1.1 ' + resp.responseCode + ' ' + statusText + '\r\n'
                + 'Content-Type: ' + (contentType.length > 0 ? contentType : 'application/octet-stream') + '\r\n'
                + 'Content-Length: ' + contentLength + '\r\n';
            if (contentRange.length > 0) {
                headStr += 'Content-Range: ' + contentRange + '\r\n';
            }
            headStr += 'Connection: close\r\n\r\n';
            this.sendHttpBody(client, headStr, body);
        } catch (err) {
            BLog.w('LocalDashServer: proxy exception: ' + JSON.stringify(err));
            this.sendSimpleResponse(client, 502, 'Bad Gateway');
        } finally {
            req.destroy();
        }
    }

    private serveMpd(client: socket.TCPSocketConnection): void {
        let encoder: util.TextEncoder = new util.TextEncoder();
        let body: Uint8Array = encoder.encodeInto(this.mpdContent);
        let headStr: string = 'HTTP/1.1 200 OK\r\n'
            + 'Content-Type: application/dash+xml\r\n'
            + 'Content-Length: ' + body.byteLength + '\r\n'
            + 'Connection: close\r\n\r\n';
        this.sendHttpBody(client, headStr, LocalDashServer.copyToArrayBuffer(body));
    }

    private sendSimpleResponse(client: socket.TCPSocketConnection, status: number, reason: string): void {
        let headStr: string = 'HTTP/1.1 ' + status + ' ' + reason + '\r\n'
            + 'Content-Length: 0\r\n'
            + 'Connection: close\r\n\r\n';
        this.sendHttpBody(client, headStr, new ArrayBuffer(0));
    }

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
            LocalDashServer.closeQuietly(client);
        }, (err: BusinessError) => {
            BLog.w('LocalDashServer: send failed ' + err.code);
            LocalDashServer.closeQuietly(client);
        });
    }

    private static extractHost(url: string): string {
        let schemeIdx: number = url.indexOf('://');
        if (schemeIdx < 0) {
            return '';
        }
        let rest: string = url.substring(schemeIdx + 3);
        let endIdx: number = rest.length;
        let cutChars: string[] = ['/', '?', '#'];
        for (let i: number = 0; i < cutChars.length; i++) {
            let idx: number = rest.indexOf(cutChars[i]);
            if (idx >= 0 && idx < endIdx) {
                endIdx = idx;
            }
        }
        let hostPart: string = rest.substring(0, endIdx);
        let atIdx: number = hostPart.lastIndexOf('@');
        if (atIdx >= 0) {
            hostPart = hostPart.substring(atIdx + 1);
        }
        let colonIdx: number = hostPart.indexOf(':');
        if (colonIdx >= 0) {
            hostPart = hostPart.substring(0, colonIdx);
        }
        return hostPart.toLowerCase();
    }

    private static isHostAllowed(host: string): boolean {
        if (host.length === 0) {
            return false;
        }
        if (!/^[a-z0-9.-]+$/.test(host)) {
            return false;
        }
        let suffixes: string[] = LocalDashServer.ALLOWED_HOST_SUFFIXES;
        for (let i: number = 0; i < suffixes.length; i++) {
            let suffix: string = suffixes[i];
            if (host === suffix.substring(1) || host.endsWith(suffix)) {
                return true;
            }
        }
        return false;
    }

    private static extractHeaderValue(headerJson: string, name: string): string {
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

    private static copyToArrayBuffer(u8: Uint8Array): ArrayBuffer {
        let ab: ArrayBuffer = new ArrayBuffer(u8.byteLength);
        new Uint8Array(ab).set(u8);
        return ab;
    }

    private static closeQuietly(client: socket.TCPSocketConnection): void {
        try {
            client.close().catch((err: BusinessError) => {
                BLog.w('LocalDashServer: close connection failed ' + err.code);
            });
        } catch (err) {
            BLog.w('LocalDashServer: close connection threw');
        }
    }

    private static closeServerQuietly(srv: socket.TCPSocketServer): void {
        try {
            srv.close().catch((err: BusinessError) => {
                BLog.w('LocalDashServer: close server failed ' + err.code);
            });
        } catch (err) {
            BLog.w('LocalDashServer: close server threw');
        }
    }
}
