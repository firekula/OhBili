# Implementation Plan: DASH 取流与高清播放（Dash Playback）

**Input**: Feature specification from `spec/dash-playback/spec.md`

## Summary

在 OhBili phone 模块实现 DASH 音视频分离播放：wbi playurl（fnval=4048）取 dash 流 → `DashMpdBuilder` 拼 SegmentBase MPD（编码偏好过滤 + 自动/锁定档位）→ `LocalDashServer`（本地 HTTP 服务：MPD 分发 + CDN 段代理注入 UA/Referer、透传 Range）→ AvPlayer `setMediaSource(url, PlaybackStrategy)` DASH 播放。清晰度菜单新增「自动」档（默认，DASH ABR 网络自适应），手动档重建 MPD 锁定；DASH 任一环节失败自动回退现有 durl 链路（一次防循环）；番剧链路不动；spike 代码全部移除。架构已由 spike 在模拟器与真机双端验证（分支 `test/dash-spike`，`DashSpike.ets` 为可运行参考实现，正式实现以其为蓝本抽取）。

## Technical Context

**Language/Version**: ArkTS（API 26 / HarmonyOS 26.0.0，compatibleSdkVersion "26.0.0"，兼容模式 linter）
**Primary Dependencies**: @ohos/retrofit（本地 har）、taskPool、`@kit.NetWorkKit`（socket.TCPSocketServer + http kit，段代理）、`@kit.MediaKit`（AVPlayer/AVMimeTypes/PlaybackStrategy，系统已有）
**State Management**: V1（@State/AppStorage），增量不引入 V2
**Storage**: `ohBiliPlayQn`（已有，语义扩展：-1=自动档）、新增 `ohBiliCodecPreference`（AppStorage，内存级即可；播放时读取）
**Testing**: 无自动化测试框架；`devecocli check arkts` + `devecocli build --modules phone/tablet` + 人工真机验证（nova 14 Ultra）
**Target Platform**: phone 模块（tablet 仅回归编译，不接 DASH）
**Constraints**: 每编辑 .ets 后 `devecocli check arkts <files>`；build 必须带 `--modules`；禁用 PowerShell 管道改写源码（UTF-8 乱码风险，一律用 Write/Edit 工具）
**Scale/Scope**: 新增 2 个文件（DashMpdBuilder/LocalDashServer），修改约 8 个（Player/AvPlayer/ApiManager/TaskManager/PlayUrlResponse/Index.ets/Splash/main_pages.json），删除 1 个（DashSpike.ets）

## Project Structure

### Documentation (this feature)

```text
spec/dash-playback/
├── spec.md              # 需求规格（已批准）
├── plan.md              # 本文件
└── tasks.md             # 任务拆解
```

### Source Code (repository root)

```text
common/src/main/ets/
├── model/response/
│   └── PlayUrlResponse.ts   # [修改] BiliDash 系列模型转正（video[]/audio[]/SegmentBase/dolby/flac 字段补全）
├── network/
│   ├── TaskManager.ts       # [修改] DASH playurl task 转正（fnval=4048、fourk=1、qn 参数）
│   └── ApiManager.ets       # [修改] requestPlayUrlWbiDash 转正（错误兜底返回 null）
├── player/
│   ├── AvPlayer.ets         # [修改] setDataSource/applySource 增加可选 PlaybackStrategy 参数
│   ├── DashMpdBuilder.ets   # [新增] MPD 构建（纯函数：编码过滤降级链、自动/锁定档位、代理 URL 重写）
│   └── LocalDashServer.ets  # [新增] 本地 HTTP 服务（TCPSocketServer：MPD 分发 + 段代理 + 端口重试 + 生命周期）
├── components/video/
│   └── Player.ets           # [修改] getPlayUrl/switchQuality DASH 分支与回退、清晰度菜单「自动」档、设置面板「解码偏好」行
└── Index.ets                # [修改] 导出 DashMpdBuilder/LocalDashServer（去 SPIKE 导出注释）

product/phone/src/main/
├── resources/base/profile/main_pages.json   # [修改] 移除 pages/DashSpike 注册
└── ets/pages/
    ├── DashSpike.ets         # [删除] spike 验证页（蓝本抽取完成后）
    └── Splash.ets            # [修改] 还原直跳 pages/Index
```

**Structure Decision**: 编排逻辑留在 Player.ets（回退/loading/续播/弹幕均依赖其内部状态，抽 Controller 只会镜像一遍状态）；DashMpdBuilder 与 LocalDashServer 为无 UI 依赖的独立类，落在 `player/`（与 AvPlayer 同层）。不拆 Player.ets（2101 行，遵循仓库现状，不做顺手重构）。

## Research & Decisions（spike 双端实证）

### R1: 本地 MPD 必须经 HTTP 服务分发
- **Decision**: `LocalDashServer`（TCPSocketServer 监听 127.0.0.1）以 `GET /dash.mpd` 分发内存中的 MPD 字符串。
- **Rationale**: `createMediaSourceWithUrl` 仅接受 HTTP(S) MPD；本地裸路径/`fd://` 实测不触发 DASH demuxer（state 停留 idle）；`AVMimeTypes` 无 `APPLICATION_MPD`。

### R2: 段代理必须存在
- **Decision**: MPD 中 `BaseURL` 重写为 `http://127.0.0.1:{port}/seg?url={encodeURIComponent(fixedUrl)}`；代理用 http kit 上游请求，注入 `User-Agent`/`Referer`，透传 `Range`/`Content-Range`/`Content-Type`/状态码，`Connection: close`。
- **Rationale**: `setMediaSource` 自定义头不透传跨域段请求（实测 CDN 403；同头 http kit 直连 206）；真机代理链路全程 206 无失败。

### R3: MPD 采用 SegmentBase 单文件字节区间形式
- **Decision**: isoff-on-demand profile；每个 Representation 携带 `SegmentBase.indexRange`（sidx）与 `initialization` range；音频同理。
- **Rationale**: B 站 dash 流为单文件 + SegmentBase 元数据，spike 实测 demuxer 先取 sidx 再按 Range 分块拉取；无需 SegmentList/SegmentTemplate。

### R4: 起播档位用 PlaybackStrategy，自动档交给 ABR
- **Decision**: `setMediaSource(mediaSource, strategy)`；自动档 `preferredWidth=1280/preferredHeight=720` 起播，之后升降档由系统 demuxer ABR 决定；锁定档 MPD 仅含单视频 Representation（ABR 无处可切）。
- **Rationale**: 真机实测 ABR 升档（720P→1080P 高码率 139MB 文件，2MB 块拉取）工作正常；锁定档用 MPD 收敛 Representation 而非 strategy 强约束，行为确定。

### R5: 编码过滤与降级链
- **Decision**: `DashMpdBuilder` 按 `ohBiliCodecPreference`（'avc1'|'hev1'|'av01'，默认 'avc1'）过滤 `dash.video[]`（codecs 前缀匹配：avc1/hev1/hvc1/av01）；过滤后为空则按 [偏好, AV1, HEVC, AVC] 顺序取第一个非空集合。
- **Rationale**: 模拟器实测选中无解码器的流（AV1）prepare 直接失败（5400106）；降级链保证「偏好不可用→能播」优先于「严格遵从偏好→失败」。

### R6: 清晰度切换 = 重取 playurl + 重建 MPD + switchSourceResume；新增自动档
- **Decision**: 手动档：`requestPlayUrlWbiDash(bvid, cid, qn)` → 重建 MPD（仅保留 id==qn 的 Representation）→ `switchSourceResume(curMs)`；自动档（qn=-1，默认）：请求最高档（qn=120, fourk=1）取全流，MPD 含全部 Representation。进度/弹幕分段记忆复用现有机制。
- **Rationale**: 与现状 durl 切换交互一致、实现直接；`selectTrack` 无缝切换列后续优化。B 站 dash `video[].id` 即 qn（16/32/64/80/112/120）。

### R7: 音质默认最高可用，不做切换 UI
- **Decision**: 取 `dash.audio[]` 中 bandwidth 最大者；`dolby`/`flac` 对象本期不接入。
- **Rationale**: 用户决策（2026-11-24）；Hi-Res/杜比音质 UI 列后续功能。

### R8: 端口策略与生命周期
- **Decision**: 起始端口 34567，占用则 +1 重试最多 10 次，耗尽回退 durl；`stop()` 关闭全部连接与 server；Player.ets 在 release/销毁与每次重建数据源前调用。
- **Rationale**: spike 实证端口模型可行；避免与系统其他本地服务冲突；防端口泄漏。

### R9: 回退链防循环
- **Decision**: Player.ets 持有 `mDashActive`（当前 DASH 起播）与 `mDashFallbackUsed`（本次视频已回退过）标记；DASH error 事件仅当 `mDashActive && !mDashFallbackUsed` 时触发 durl 回退，回退前置 `mDashFallbackUsed=true`、`mDashActive=false`。
- **Rationale**: durl 回退后再次 error 走现有错误处理（防 dash↔durl 死循环）；切集/切视频时重置两标记。

### R10: `ohBiliPlayQn` 语义扩展
- **Decision**: `-1`=自动档（新增，未设置/0 时也视为自动）；`>0`=锁定该 qn。清晰度菜单首行「自动」，默认选中打勾。
- **Rationale**: 复用现有记忆键，不新增键；0（历史无记忆值）迁移语义为自动，行为向后兼容（自动档是更优默认）。

## Data Model

### 响应模型转正（PlayUrlResponse.ts，interface 风格与现有一致）

- **BiliDash**: `duration: number`（ms）、`video: BiliDashStream[]`、`audio: BiliDashAudioStream[]`、`dolby?: BiliDashDolby`、`flac?: BiliDashAudioStream | null`
- **BiliDashStream**: `id: number`（=qn）、`baseUrl: string`、`backupUrl: string[]`、`codecs: string`、`bandwidth: number`、`mimeType: string`、`width: number`、`height: number`、`SegmentBase: BiliSegmentBase`
- **BiliDashAudioStream**: `id: number`、`baseUrl: string`、`backupUrl: string[]`、`codecs: string`、`bandwidth: number`、`mimeType: string`、`SegmentBase: BiliSegmentBase`
- **BiliSegmentBase**: `initialization: string`（如 `0-963`）、`indexRange: string`（如 `964-1421`）
- **BiliDashDolby**: `type: number`、`audio: BiliDashAudioStream[]`（本期不消费，仅建模）
- **PlayUrl**: 增补 `dash?: BiliDash | null`（与现有 durl/quality/accept_quality 共存）

### DashMpdOptions（DashMpdBuilder 入参，interface）

- `proxyBase: string`（如 `http://127.0.0.1:34567`）
- `codecPreference: string`（'avc1' | 'hev1' | 'av01'）
- `pinQn: number`（-1=自动全量；>0=仅保留 id==pinQn 的视频 Representation）
（MPD 时长取 `dash.duration`，不入参）

### 持久化/运行时键

| 键 | 类型 | 含义 |
|---|---|---|
| ohBiliPlayQn | number | -1=自动（默认）；>0=锁定 qn（已有键，语义扩展） |
| ohBiliCodecPreference | string | 'avc1'（默认）/'hev1'/'av01'（新增，AppStorage） |

## Contracts & Interfaces

### 网络层（ApiManager）

- `requestPlayUrlWbiDash(bvid: string, cid: number, qn: number): Promise<PlayUrlResponse | null>` — WBI 签名 `x/player/wbi/playurl`，query：`fnval=4048&fourk=1&qn={qn}`，带登录 Cookie（已有 buildCookieHeader 模式）；失败/业务码非 0 返回 null（模式与现有一致，含 BLog）

### DashMpdBuilder（common/player/，新增，纯静态）

- `static build(dash: BiliDash, opts: DashMpdOptions): string` — 返回完整 MPD 字符串；内部：编码过滤降级链（R5）→ pinQn 收敛（R6）→ baseUrl/backupUrl 双重转义还原（`\u0026`→`&`）→ 代理 URL 重写（R2）→ XML 转义（`&`→`&amp;`）→ 音频选最高 bandwidth（R7）；无可Representation 时返回 `''`

### LocalDashServer（common/player/，新增）

- `start(): Promise<number>` — 绑定 127.0.0.1，端口 34567 起 +1 重试 ≤10（R8）；成功 resolve 实际端口，失败 resolve `-1`
- `stop(): void` — 关闭全部活动连接与 server，置空 MPD
- `updateMpd(mpd: string): void` — 更新内存 MPD（切档/切集时调用）
- HTTP 协议（内部实现）：
  - `GET /dash.mpd` → `200`，`Content-Type: application/dash+xml`，`Connection: close`
  - `GET /seg?url={enc}` → 解码后校验域名白名单（后缀：`.bilivideo.com` / `.bilivideo.cn` / `.akamaized.net` / `.hdslb.com`，FR-012）；非白名单 `403`；上游请求注入 `User-Agent`（项目现有 UA 常量）与 `Referer: https://www.bilibili.com`，透传请求 `Range`；上游非 200/206 或异常 → `502`；成功透传上游状态码与 `Content-Range`/`Content-Type`/`Content-Length`（从 `JSON.stringify(resp.header)` 解析提取，spike 模式）

### AvPlayer（修改）

- `setDataSource(url: string, headers?: Map<string, string>, strategy?: PlaybackStrategy): void`（第 3 参数新增，可选）— `applySource` 内 `strategy !== undefined` 时 `avPlayer.setMediaSource(mediaSource, strategy)`，否则维持现有单参调用
- `switchSource(url: string, headers?: Map<string, string>): void` — 维持现状（DASH 切档走 reset→重新 initPlay 链路，与 switchSourceResume 现有机制一致）

### Player.ets 内部（修改）

- 新增成员：`mDashServer: LocalDashServer`、`mDashActive: boolean`、`mDashFallbackUsed: boolean`
- `getPlayUrl(bvid, cid)`：epId>0 走番剧现状不动；否则先尝试 DASH（取 `ohBiliPlayQn` 得请求 qn：-1→120 自动全量，>0→该 qn）→ `requestPlayUrlWbiDash` 有效 dash → `server.start()` ≥0 → `DashMpdBuilder.build` 非空 → `server.updateMpd` → `initPlay(mpdUrl, undefined, strategy)`（自动档 strategy preferred 1280x720）；任一步失败 → 落入现有 durl 链路（原逻辑不动，`mDashActive=false`）
- `switchQuality(qn)`：qn=-1（自动）与 qn>0（手动）在 DASH 激活时走「重取 dash → 重建 MPD → switchSourceResume」；DASH 未激活（durl 回退后）维持现有 durl 切换逻辑
- 播放 error 回调：`mDashActive && !mDashFallbackUsed` → 置标记 → 取当前进度 → 现有 durl 取流 → `switchSourceResume(curMs)`（R9）
- 切集/切视频（onBangumiEpChanged、cid 更新处）：重置 `mDashActive/mDashFallbackUsed`，`server.updateMpd` 由新链路覆盖
- 清晰度菜单（PlayerControlView 设置面板）：首行「自动」（qn=-1），`ohBiliPlayQn<=0` 时打勾；`isVipQn` 不适用于 -1
- 设置面板新增「解码偏好」行：AVC/HEVC/AV1 三选，读写 `ohBiliCodecPreference`，变更后立即以当前档位重建 MPD（复用 switchQuality 链路）

## State Machine（清晰度模式）

```
[自动] --选具体qn--> [锁定 qn] --选「自动」--> [自动]
[自动] ABR 自由升降档（系统 demuxer）
[锁定] MPD 单 Representation，无切换
durl 回退后：清晰度菜单仍可用，切换走 durl 链路（现状）
```

## Review Focus（审查重点）

规格未显式覆盖、最可能伤到使用者的输入类别（各任务验证步骤须覆盖）：

1. **播放器销毁竞态**：用户在 MPD 构建中退出页面 → server.stop() 后到达的回调不得再触碰 UI/重试（AvPlayer isReleased 模式对齐）
2. **代理异常不悬挂**：上游 CDN 超时/断连 → 连接必须以 502 关闭，不得留下半开连接耗尽句柄
3. **URL 双重转义**：`baseUrl` 含 `\u0026` 未还原时代理 URL 编码错乱 → 403/404 全链路不可播
4. **切台串台**：快速连续切换视频，旧视频的段请求打到新 MPD（代理无状态，风险低；但 MPD 更新与旧 Representation 的 sidx 请求并存必须无害）
5. **白名单绕过**：`/seg?url=` 指向非 B 站域名被用作开放代理（安全红线，FR-012）

## Complexity Tracking

> 无 Constitution Check 违规；ArkTS 严格模式约束（无 any/未类型化对象字面量/动态属性访问）随任务自查。
