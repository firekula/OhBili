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
 * crossDomain ticket 兑换结果（原始调试信息 + 解析后的 Cookie 参数）。
 * taskPool 并发任务仅填充原始字段（响应码/头/体），cookieParams 由主线程
 * 调用 parseCookies() 解析填充（并发函数仅允许引用导入变量，无法调用本文件级函数）。
 */
export class CrossDomainResult {
  /** HTTP 状态码（如 302） */
  responseCode: number = 0;
  /** 302 跳转地址 */
  location: string = '';
  /** Set-Cookie 原始头（多条以换行拼接） */
  setCookieRaw: string = '';
  /** response.cookies 原始字段（服务端下发的 cookie 串） */
  cookiesField: string = '';
  /** 响应体片段（调试用） */
  bodySnippet: string = '';
  /** 请求异常信息 */
  errorMessage: string = '';
  /** 解析出的 Cookie name→value（值保持原样，不解码） */
  cookieParams: Record<string, string> = {};
}

/**
 * 解析 "a=1; b=2" 形态的 Cookie 串到 params（值保持原样，不解码）。
 */
function parseCookiePairInto(raw: string, params: Record<string, string>): void {
  let pairs: string[] = raw.split(';');
  for (let i = 0; i < pairs.length; i++) {
    let pair: string = pairs[i].trim();
    let eqIndex: number = pair.indexOf('=');
    if (eqIndex <= 0) {
      continue;
    }
    let name: string = pair.substring(0, eqIndex);
    let value: string = pair.substring(eqIndex + 1);
    if (name !== '' && value !== '') {
      params[name] = value;
    }
  }
}

/**
 * 主线程侧解析：从 setCookieRaw / cookiesField 填充 result.cookieParams。
 * 静态方法以实例为入参，规避 taskPool 结构化克隆可能丢失类原型的问题。
 */
export function parseCrossDomainResultCookies(result: CrossDomainResult): void {
  // 先解析 response.cookies（"a=1; b=2" 形态）
  if (result.cookiesField !== '') {
    parseCookiePairInto(result.cookiesField, result.cookieParams);
  }
  // 再以 Set-Cookie 头覆盖（每条 "NAME=VALUE; Domain=...; Path=..."，取首段）
  if (result.setCookieRaw !== '') {
    let scLines: string[] = result.setCookieRaw.split('\n');
    for (let i = 0; i < scLines.length; i++) {
      let line: string = scLines[i];
      let segIndex: number = line.indexOf(';');
      let firstSeg: string = segIndex >= 0 ? line.substring(0, segIndex) : line;
      parseCookiePairInto(firstSeg, result.cookieParams);
    }
  }
}
