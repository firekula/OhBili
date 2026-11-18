# Implementation Plan: 对齐 B 站网页版数据源（Web API Alignment）

**Input**: Feature specification from `spec/web-api-align/spec.md`

## Summary

为 OhBili 实现 B 站 Web 端 WBI 接口签名机制与真实设备 Cookie（指纹接口获取 buvid3/buvid4，替换硬编码假 Cookie），将搜索（切至 wbi 签名端点）、首页推荐（feed V2 + 签名 + Cookie 个性化）、热门（对齐网页分页参数）对齐网页版逻辑；修复输入法回车搜索无结果的交互缺陷（改用 onSubmit 事件的提交文本）。仅 phone 模块验证，网络层改动位于 common（tablet 自然继承不在验证范围）。

## Technical Context

**Language/Version**: ArkTS（API 26 / HarmonyOS 26.0.0，兼容模式 linter）
**Primary Dependencies**: @ohos/retrofit（本地 har）、taskPool、PersistentStorage、@kit.CryptoArchitectureKit（MD5，用于 WBI 签名摘要）
**State Management**: 沿用 State Management V1（@State/@StorageLink/AppStorage/PersistentStorage）；推荐流刷新索引用 AppStorage 会话级状态
**Storage**: PersistentStorage.PersistProp 新增 2 个设备 Cookie 键（buvid3/buvid4）
**Testing**: 无自动化测试；真机人工对比网页版验证 + 构建验证
**Target Platform**: HarmonyOS 手机（phone 模块验证）
**Project Type**: HarmonyOS 多模块应用（common HAR + phone/tablet entry）
**Performance Goals**: WBI 密钥内存缓存（避免每次请求重复取 nav）；签名计算 <50ms；搜索/推荐请求延迟与现状持平
**Constraints**: 不引入 MVVM；不改 tablet 源码；沿用现有 retrofit + taskPool 分层；登录 Cookie 复用 qr-login 的 LoginHelper
**Scale/Scope**: 新增 2 文件、修改约 9 文件，全部位于 common 与 phone

## Project Structure

### Documentation (this feature)

```text
spec/web-api-align/
├── spec.md              # 需求规格
├── plan.md              # 本文件
└── tasks.md             # 任务拆解（Phase 3 生成）
```

### Source Code (repository root)

```text
common/src/main/ets/
├── model/response/
│   ├── FingerSpiResponse.ts        # [新增] 指纹接口响应（b_3/b_4）
│   └── NavResponse.ts              # [修改] NavData 增加 wbi_img（img_url/sub_url）
├── utils/
│   ├── WbiSigner.ets               # [新增] WBI 签名器（密钥获取/缓存/mixinKey/参数签名）
│   └── LoginHelper.ets             # [修改] buildCookieHeader 并入 buvid；新增 ensureDeviceCookies
├── network/
│   ├── Api.ts                      # [修改] getSearch/getRecommend/getPopular 参数改造；新增 getFingerSpi
│   ├── TaskManager.ts              # [修改] 对应任务参数透传；新增 fingerSpi 任务
│   ├── ApiManager.ets              # [修改] 签名调用与 Cookie 组装；新增 requestFingerSpi
│   └── ApiConstants.ts             # [修改] 新增热门分页大小常量（web 对齐值 20）
└── Index.ets                       # [修改] 导出新增符号

common/src/main/ets/components/home/
└── SearchBar.ets                   # [修改] onSubmit 使用提交事件文本修复回车 bug

product/phone/src/main/ets/pages/
├── Splash.ets                      # [修改] storageInit +2 PersistProp；initTask 预取设备 Cookie
└── SearchResult.ets                # [修改] 空结果/风控友好提示
```

**Structure Decision**: 遵循现有项目架构（common HAR 分层 + phone 页面），不做 MVVM 迁移。WBI 签名器作为独立 util 单文件实现（含 mixinKey 置换表与签名算法），Cookie 组装职责并入现有 LoginHelper（它已持有 buildCookieHeader），不新增持久化机制。

## Complexity Tracking

> 无 Constitution Check 违规，无需条目。

## Research & Decisions

### R1: WBI 签名机制
- **Decision**: 新增 `WbiSigner`（common/utils/WbiSigner.ets）：从 nav 接口响应的 `wbi_img.img_url/sub_url` 提取 img_key/sub_key（URL 末段文件名去扩展名），经标准 64 项置换表生成 32 位 mixinKey；签名流程：参数加 `wts`（当前秒级时间戳）→ 过滤值中的 `!'()*` 字符 → 键排序 → URL 编码拼接 → 追加 mixinKey → MD5 得 `w_rid`。MD5 使用 `@kit.CryptoArchitectureKit` 的 cryptoFramework 实现。密钥内存缓存（模块级单例，当日有效），获取失败降级为不签名请求并 BLog 告警。
- **Rationale**: B 站 Web 端公开的签名标准流程，社区广泛验证；nav 接口无需登录即可返回 wbi_img，与 qr-login 已有的 requestNavInfo 链路复用。
- **Alternatives considered**: 纯 TS 手写 MD5（维护成本高，系统 kit 已提供）；每次请求重新取密钥（nav 请求放大，弃用）。

### R2: 设备 Cookie（buvid3/buvid4）
- **Decision**: 新增指纹接口调用链：`GET {apiBase}/x/frontend/finger/spi` → `data.b_3/b_4`（即 buvid3/buvid4），持久化到 PersistentStorage 键 `ohBiliBuvid3`/`ohBiliBuvid4`（Splash storageInit 注册，默认 ""）。`LoginHelper.buildCookieHeader()` 扩展为：buvid3 + buvid4 + 登录 Cookie（SESSDATA/bili_jct/DedeUserID，未登录时仅设备 Cookie）。新增 `ensureDeviceCookies()`：键为空时调指纹接口获取并写入；获取失败用本地随机 UUID 兜底并告警。Splash initTask 预取。
- **Rationale**: buvid3 是 B 站 Web 端风控的必备设备标识；官方指纹接口返回的值与网页版一致，第三方客户端标准做法；与网页版登录态叠加后即可获得一致的个性化数据（FR-008）。
- **Alternatives considered**: 沿用硬编码假 Cookie（2023 年陈旧值，风控高风险，本轮要移除的根源）；本地随机生成 buvid3（格式可被识别为非法，仅作失败兜底）。

### R3: 搜索对齐
- **Decision**: 搜索端点切换为 Web 端现行签名端点 `x/web-interface/wbi/search/type`；getSearch 方法签名扩展（cookie, search_type, keyword, page, wRid, wts），ApiManager.requestSearch 组装：Cookie=buildCookieHeader()，签名参数由 WbiSigner 对 {search_type, keyword, page} 计算后透传。移除硬编码假 Cookie。响应模型 SearchResponse 沿用。
- **Rationale**: 旧端点 `x/web-interface/search/type` 未签名请求已被风控降级，是"结果与网页版不一致"的直接原因；切至 wbi 端点 + 签名 + 真实 Cookie 后与网页版一致。
- **Alternatives considered**: App 端搜索接口（需模拟 AppKey/sign，用户已确认网页版基准）；保留旧端点仅加签名（部分字段语义已与 web 现行不同）。

### R4: 回车搜索修复
- **Decision**: `SearchBar.ets` 的 `onSubmit` 改为使用提交事件携带的文本（API 12+ `onSubmit((enterKey, event?: SubmitEvent) => event.text)`，实现时经文档确认 SubmitEvent 可用性与确切字段），事件文本优先、`this.keyword`（onChange 同步值）兜底；`searchKeyword()` 增加 BLog 日志记录导航时的关键字。同时 SearchResult 空数据态展示"无结果"提示而非空白。
- **Rationale**: 现象为回车可导航但无结果，两路（回车/按钮）代码路径相同，差异最可能来自中文输入法组合输入与 onChange 的提交时序（回车时 this.keyword 仍为空 → 走 placeholder 分支搜了默认词）；事件文本是 IME 提交的权威值，绕开时序问题。修复后无论根因是时序还是历史风控偶发，行为都收敛为与按钮一致。
- **Alternatives considered**: 仅加日志等复现（用户已明确要修，不采用）；TextInput 改受控 @State 组件（改动面大，不必要）。

### R5: 推荐流对齐
- **Decision**: getRecommend 方法参数扩展为 Web 首页 feed 现行参数集（cookie + ps + fresh_idx_1h/fresh_idx_4h/fresh_idx + fresh_type=4 + feed_version=V2 + wRid/wts），由 ApiManager.requestRecommend 统一计算签名并传递 Cookie；fresh_idx 系列在 ApiManager 内维护（AppStorage 会话级计数，每次刷新递增；1h/4h 按会话内刷新次数衰减），刷新（setData）与加载（addAllData）行为保持现有页面逻辑。登录态下 Cookie 含 SESSDATA → 服务端返回个性化流，未登录返回热门向流，与网页版一致。
- **Rationale**: `x/web-interface/index/top/feed/rcmd` 即网页版首页推荐端点，参数补齐 + 签名 + Cookie 后内容池与网页版对齐；feed_version 由 V3（社区去广告旧值）改为 V2（网页版现行值）以对齐官方逻辑。
- **Alternatives considered**: 保留 V3（用户要求对齐官方，不采用）；App 端推荐接口（需 AppKey 模拟，已排除）。

### R6: 热门对齐
- **Decision**: getPopular 传递 Web 版分页大小 ps=20（新增 ApiConstants 常量），保留 pn 分页；请求携带 Cookie（buildCookieHeader()）。热门接口无需 WBI 签名（Web 端该接口不强制）。
- **Rationale**: 端点已与网页版同源，差异仅在分页大小（现状 24 → Web 20）与 Cookie 缺失；最小改动对齐。
- **Alternatives considered**: 全量 WBI 化热门（非必需，增加签名依赖）。

### R7: 风控与降级策略
- **Decision**: 各请求链路识别风控/异常码（如 -412、-799）与空结果：BLog.e 记录，SearchResult 展示"请求过于频繁，请稍后再试"或"无结果"提示；WBI 密钥获取失败 → 不签名重试一次 → 仍失败按无签名降级发出请求；设备 Cookie 获取失败 → 随机 UUID 兜底。任何降级不阻塞页面主流程。
- **Rationale**: FR-007 要求全链路不崩溃不白屏；外部接口风控不可控，降级保障可用性。
- **Alternatives considered**: 失败直接报错阻断（体验差，不采用）。

## Data Model

### 新增/修改响应模型

- **FingerSpiResponse**（新增，common/model/response/FingerSpiResponse.ts）: `b_3: string`（buvid3）、`b_4: string`（buvid4）
- **NavData 扩展**（NavResponse.ts）: 新增 `wbi_img?: WbiImg`；**WbiImg**: `img_url: string`、`sub_url: string`

### 持久化键（PersistentStorage，Splash storageInit 注册）

| 键 | 类型 | 默认 | 含义 |
|---|---|---|---|
| ohBiliBuvid3 | string | "" | 设备 Cookie buvid3 |
| ohBiliBuvid4 | string | "" | 设备 Cookie buvid4 |

### 会话级状态（AppStorage，不持久化）

- 推荐流刷新索引（fresh_idx 及 1h/4h 派生值）由 ApiManager 维护

### WBI 签名数据流

`nav.wbi_img` → img_key/sub_key →（置换表）→ mixinKey(32字符) → 签名(参数+wts → 排序 → 编码 → +mixinKey → MD5) → `w_rid`+`wts` 附加到请求 Query

## Contracts & Interfaces

### B 站 HTTP 接口（retrofit DataService 方法变更）

1. **getFingerSpi**（新增）: `GET {apiBase}/x/frontend/finger/spi` → `Promise<Response<FingerSpiResponse>>`
2. **getSearch**（修改）: `GET x/web-interface/wbi/search/type`，参数 `@Header('Cookie') cookie, @Query('search_type') search_type, @Query('keyword') keyword, @Query('page') page, @Query('w_rid') wRid, @Query('wts') wts`
3. **getRecommend**（修改）: `GET x/web-interface/index/top/feed/rcmd`，参数 `@Header('Cookie') cookie, @Query('ps') ps, @Query('fresh_idx_1h') freshIdx1h, @Query('fresh_idx_4h') freshIdx4h, @Query('fresh_idx') freshIdx, @Query('fresh_type') freshType, @Query('feed_version') feedVersion, @Query('w_rid') wRid, @Query('wts') wts`
4. **getPopular**（修改）: `GET x/web-interface/popular`，参数 `@Header('Cookie') cookie, @Query('ps') ps, @Query('pn') pn`

### common 公开方法（ApiManager）

- `requestFingerSpi(): Promise<FingerSpiResponse>`（失败返回 null）
- `requestSearch(keyword, pn): Promise<boolean>` — 内部组装 Cookie + WBI 签名（签名参数 {search_type:'video', keyword, page}），移除硬编码 Cookie
- `requestRecommend(freshIdx, isFresh): Promise<boolean>` — 签名扩展参数集 + Cookie；freshIdx 语义保留（页面调用不变）
- `requestPopular(pn): Promise<boolean>` — ps=20 + Cookie
- 其余方法签名不变

### WbiSigner（common/utils/WbiSigner.ets，新增导出）

- `getWbiKeys(forceRefresh: boolean): Promise<boolean>` — 取 nav 提取 img_key/sub_key 并缓存；成功 true
- `signParams(params: Record<string, string>): Promise<Record<string, string>>` — 追加 wts 计算签名；无密钥时返回原参数（降级不签名）+ BLog 告警
- 内部：mixinKey 置换表、字符过滤、MD5 摘要（cryptoFramework）

### LoginHelper（修改）

- `buildCookieHeader(): string` — 返回 `buvid3=...; buvid4=...` +（已登录时）`SESSDATA=...; bili_jct=...; DedeUserID=...`；buvid 为空时跳过该项
- `ensureDeviceCookies(): Promise<void>` — buvid 键为空时调 requestFingerSpi 写入；失败随机 UUID 兜底（格式对齐 buvid3 形态）
- 其余方法不变

### UI 契约

- **SearchBar.ets**: `onSubmit` 优先使用提交事件文本；`searchKeyword()` 记录 BLog；行为对回车/按钮收敛一致
- **SearchResult.ets**: isLoading 结束且数据源为空时展示提示文案（区分"无结果"与"请求频繁稍后再试"）
- **Splash.ets**: storageInit 追加 2 个 PersistProp；initTask 追加 `LoginHelper.ensureDeviceCookies()`（异步不阻塞）
- 推荐/热门页面（Recommend.ets/Popular.ets）不改动：ApiManager 内部参数升级后自动生效
