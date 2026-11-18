# Implementation Plan: B站扫码登录（QR Login）

**Input**: Feature specification from `spec/qr-login/spec.md`

## Summary

在 OhBili phone 模块实现 B 站 Web 端扫码登录：登录页请求二维码并展示（本地生成 QR 图片），轮询扫码状态，扫码确认成功后解析并持久化登录凭证（Cookie），动态页展示用户昵称与头像；登录态通过 PersistentStorage 持久化，重启后经用户导航接口校验恢复。移除现有不可用的短信登录 UI（网络层短信代码保留）。

## Technical Context

**Language/Version**: ArkTS（API 26 / HarmonyOS 26.0.0，compatibleSdkVersion "26.0.0"，兼容模式 linter）
**Primary Dependencies**: @ohos/retrofit（本地 har，已补丁）、@ohos/zxing ^2.1.6（新增，ohpm，二维码生成，Apache-2.0）、taskPool（并发请求）、PersistentStorage（登录态持久化）
**State Management**: 沿用项目现有 State Management V1（@State/@StorageLink/AppStorage/PersistentStorage），增量改动不引入 V2
**Storage**: PersistentStorage.PersistProp 持久化 AppStorage 键（项目现有模式，Splash.ets 的 storageInit()）
**Testing**: 无自动化测试框架；人工真机验证（nova 14 Ultra）+ 构建验证
**Target Platform**: HarmonyOS 手机（phone 模块；tablet 不在本次范围）
**Project Type**: HarmonyOS 应用（1 个 common HAR + phone/tablet entry 模块）
**Performance Goals**: 二维码生成到可见 ≤3s（正常网络）；扫码确认后 ≤5s 出现成功反馈；轮询间隔 3s
**Constraints**: 不引入 MVVM 重构；不改动 tablet 模块；遵循现有 retrofit + taskPool 网络分层模式
**Scale/Scope**: 新增/改写约 8 个源文件，涉及 1 个 HAR（common）+ 1 个 entry（phone）

## Project Structure

### Documentation (this feature)

```text
spec/qr-login/
├── spec.md              # 需求规格
├── plan.md              # 本文件
└── tasks.md             # 任务拆解（Phase 3 生成）
```

### Source Code (repository root)

```text
common/src/main/ets/
├── model/response/
│   ├── QrCodeGenerateResponse.ts   # [新增] 二维码生成响应模型
│   ├── QrPollResponse.ts           # [新增] 二维码轮询响应模型
│   └── NavResponse.ts              # [新增] 用户导航信息响应模型
├── network/
│   ├── Api.ts                      # [修改] 新增 3 个接口定义（generate/poll/nav）
│   ├── TaskManager.ts              # [修改] 新增 3 个 taskPool 任务与封装方法
│   └── ApiManager.ets              # [修改] 新增 3 个 async 包装方法
└── utils/（或 model/）
    └── LoginHelper.ets             # [新增] 凭证解析/存取/登录态恢复辅助（纯函数+Preferences语义封装）

product/phone/
├── oh-package.json5                # [修改] dependencies 增加 "@ohos/zxing": "^2.1.6"
└── src/main/ets/pages/
    ├── Login.ets                   # [重写] 短信登录 UI → 扫码登录页
    ├── Moments.ets                 # [修改] 已登录时展示头像+昵称
    └── Splash.ets                  # [修改] storageInit 增加 5 个 PersistProp；initTask 增加登录态校验恢复
```

**Structure Decision**: 遵循现有项目架构（分层：common HAR 承载 model/network/utils，phone 承载 pages），不做 MVVM 迁移。Login 页重写为单页 + 状态轮询逻辑，复杂度可控，不拆 viewmodel。新增文件 5 个、修改文件 6 个，均为现有分层职责的自然延伸。

## Complexity Tracking

> 无 Constitution Check 违规，无需条目。

## Research & Decisions

### R1: 二维码生成方案
- **Decision**: 引入 ohpm 包 `@ohos/zxing` ^2.1.6（OpenHarmony TPC 官方组件，Apache-2.0，最近 18 天仍在发版），用其二维码生成能力将登录 URL 渲染为 PixelMap 显示。
- **Rationale**: 本地生成、无网络依赖、官方维护活跃、许可证宽松；项目现有 lib/har 与 ohpm 混用习惯兼容（@ohos/protobufjs 已走 ohpm）。
- **Alternatives considered**: ① `@ohos/qrcode_generator` / `qrcodegen` / `zxing` 等名称经 ohpm registry 探测均 404 不存在；② `@yunkss/eftool`（工具全家桶，6 个子依赖，未明确提及二维码能力，过重）；③ 纯手写 QR 编码器（Reed-Solomon + 掩码实现易错，不可取）。

### R2: B 站扫码登录接口契约（Web 端）
- **Decision**: 使用 passport 域 Web 扫码接口（与项目现有 `ApiConstants.loginBase = "https://passport.bilibili.com"` 一致）：
  - 生成：`GET /x/passport-login/web/qrcode/generate` → `data: { url, qrcode_key }`，url 为二维码内容
  - 轮询：`GET /x/passport-login/web/qrcode/poll?qrcode_key={key}`，业务码：86101 未扫码 / 86090 已扫码待确认 / 86038 已过期 / 0 成功
  - 成功时 `data.url` 为 crossDomain 跳转地址，其 query 参数携带 `DedeUserID`、`SESSDATA`、`bili_jct` 等 Cookie 值，`data.refresh_token` 为刷新令牌
- **Rationale**: 与项目已接入的 B 站 passport 接口同域、同响应包装（code/message/data），retrofit 分层可直接复用。
- **Alternatives considered**: App 端短信接口（需极验，已确认不可行）；TV 端接口（文档少、非主流）。

### R3: 登录凭证提取方式
- **Decision**: 从轮询成功响应的 `data.url`（crossDomain 地址）解析 query 参数得到 Cookie 值；不依赖 Set-Cookie 响应头。
- **Rationale**: retrofit 的 Response 包装虽含 `header` 字段，但多值 Set-Cookie 在 ohos http 头结构中形态不稳（数组/合并字符串不定），解析 data.url 的 query 参数确定性强。
- **Alternatives considered**: 读取响应头 Set-Cookie（多值头处理脆弱，弃用）。

### R4: 登录态与凭证持久化
- **Decision**: 沿用项目现有 `PersistentStorage.PersistProp` 模式（Splash.ets storageInit()）：新增持久化键 `isOhBiliLoggedIn`(bool)、`ohBiliSessdata`/`ohBiliBiliJct`/`ohBiliDedeUserId`/`ohBiliRefreshToken`(string)、`ohBiliUname`/`ohBiliFace`(string)。启动时由 initTask 调用户导航接口校验：isLogin 为真则恢复登录态并刷新昵称头像，为假则清除登录态。
- **Rationale**: 项目已有的唯一持久化机制（AppStorage+PersistentStorage），不引入 Preferences 新机制，改动面最小。
- **Alternatives considered**: @ohos/preferences 独立存储（新增机制，与现有模式并存造成两套持久化，弃用）。

### R5: 用户信息获取
- **Decision**: 使用 `GET {apiBase}/x/web-interface/nav`，请求头带 `Cookie: SESSDATA=...; bili_jct=...; DedeUserID=...`（Api.ts 已有 `@Header('Cookie')` 先例），响应 `data.isLogin/uname/face/mid`。
- **Rationale**: B 站 Web 端标准用户导航接口，一次请求同时校验登录态并取昵称头像。
- **Alternatives considered**: 卡片接口（需 mid 且不校验登录态）。

### R6: 状态管理与 UI 状态机
- **Decision**: Login 页内部状态机：`loading`（取二维码）→ `waiting`（未扫码）→ `scanned`（已扫码待确认）→ `expired`（过期，可点击刷新）→ `success`（成功，toast 后返回）；轮询用 setInterval(3000ms)，aboutToAppear 启动、aboutToDisappear 清除；网络错误 toast 提示并继续下一轮轮询（连续失败 ≥3 次则暂停并提示重试）。
- **Rationale**: 与 B 站 Web 端轮询节奏一致；V1 状态管理 + 页面级生命周期清理，防泄漏（FR-007/FR-008）。
- **Alternatives considered**: 单次长轮询循环（错误恢复语义复杂，弃用）。

## Data Model

### 响应模型（common/model/response/，interface 风格与现有一致，继承 BaseResponse<T>）

- **QrCodeGenerateResponse** = BaseResponse<QrCodeData>；**QrCodeData**: `url: string`（二维码内容）、`qrcode_key: string`（轮询键）
- **QrPollResponse** = BaseResponse<QrPollData>；**QrPollData**: `url: string`（成功时为 crossDomain 地址）、`refresh_token: string`、`timestamp: number`、`code: number`、`message: string`
  - 注意：轮询的四种业务状态由**顶层** code 区分（86101/86090/86038/0），BaseResponse 已含 code/message
- **NavResponse** = BaseResponse<NavData>；**NavData**: `isLogin: boolean`、`mid: number`、`uname: string`、`face: string`（头像 URL）

### 登录凭证（持久化键，AppStorage + PersistentStorage）

| 键 | 类型 | 含义 |
|---|---|---|
| isOhBiliLoggedIn | boolean | 登录态标志（Moments 页已引用） |
| ohBiliSessdata | string | B 站会话 Cookie SESSDATA |
| ohBiliBiliJct | string | CSRF Cookie bili_jct |
| ohBiliDedeUserId | string | 用户 ID Cookie DedeUserID |
| ohBiliRefreshToken | string | 刷新令牌 |
| ohBiliUname | string | 昵称（展示用缓存） |
| ohBiliFace | string | 头像 URL（展示用缓存） |

### 状态机（Login 页）

`loading → waiting → scanned → success`；`waiting/scanned → expired`（86038）；任意态可经刷新回到 `loading`；网络错误保持当前态并计数。

## Contracts & Interfaces

### B 站 HTTP 接口（retrofit DataService 新增方法，GET + @Query）

1. `generateQrCode(): Promise<Response<QrCodeGenerateResponse>>` — `GET {loginBase}/x/passport-login/web/qrcode/generate`
2. `pollQrCode(@Query('qrcode_key') qrcodeKey: string): Promise<Response<QrPollResponse>>` — `GET {loginBase}/x/passport-login/web/qrcode/poll`
3. `getNavInfo(@Header('Cookie') cookie: string): Promise<Response<NavResponse>>` — `GET {apiBase}/x/web-interface/nav`

### common 网络层新增公开方法（ApiManager，均含 BLog 日志，错误时 code=-1 返回空/默认值，模式与现有一致）

- `requestQrCode(): Promise<QrCodeData>` — 生成二维码；失败返回 null
- `pollQrStatus(qrcodeKey: string): Promise<QrPollResponse>` — 轮询；失败返回 null（与业务态区分）
- `requestNavInfo(cookie: string): Promise<NavData>` — 用户导航信息；失败返回 null

### LoginHelper（common，新增）

- `parseCrossDomainCookies(url: string): Record<string, string>` — 从 crossDomain URL 解析 query 参数（SESSDATA/bili_jct/DedeUserID 等）；非法输入返回空 Record
- `buildCookieHeader(): string` — 由持久化键拼装 Cookie 请求头字符串；未登录返回空串
- `saveLoginCredentials(params: Record<string, string>, refreshToken: string): void` — 写入 5 个凭证持久化键并置 isOhBiliLoggedIn=true
- `clearLoginCredentials(): void` — 清空全部登录相关键
- `validateAndRestoreLoginState(): Promise<boolean>` — 用存储凭证调导航接口：isLogin 真则刷新 uname/face 键并返回 true，假则清凭证返回 false

### UI 契约

- **Login.ets（重写）**：顶部 OhNavBar("扫码登录")；中央白底卡片展示 QR PixelMap（约 240vp）；文案随状态机切换（"请使用B站App扫码登录"/"已扫码，请在手机上确认"/"二维码已过期，点击刷新"）；成功后 toast"登录成功"并 router.back()
- **Moments.ets（phone）**：未登录态保持现状；已登录态展示头像 Image（ohBiliFace，网络图）+ 昵称（ohBiliUname）
- **Splash.ets**：storageInit() 新增 7 个 PersistProp（见数据模型）；initTask() 追加 validateAndRestoreLoginState()（不阻塞 1s 跳转，异步执行）
