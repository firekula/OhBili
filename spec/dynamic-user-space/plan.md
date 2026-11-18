# Implementation Plan: 动态页与个人主页（用户空间）

**Input**: Feature specification from `spec/dynamic-user-space/spec.md`

## Summary

为 phone 端实现两大能力：**动态页**——"动态" tab 基于登录态拉取关注 UP 主动态流（`x/polymer/web-dynamic/v1/feed/all`，offset 游标分页），按动态主体类型分发渲染（视频卡片/图文九宫格/转发嵌套/文字折叠/长尾类型降级）；**个人主页**——新增通用路由页 `pages/UserSpace`（`x/space/wbi/acc/info` 资料 + 既有 `x/web-interface/card` 数据 + `x/space/wbi/arc/search` 投稿列表，风控时降级 `x/series/recArchivesByKeywords`），从视频页 UP 主、动态页作者、我的页头部三入口进入。tablet 零改动，通过 `NavHelper` 设备类型门禁保证 common 组件在 tablet 上行为不变。

## Technical Context

**Language/Version**: ArkTS（HarmonyOS SDK API 26，ArkTS 严格模式）
**Primary Dependencies**: @ohos/retrofit（ DataService 装饰式声明 + ServiceBuilder）、@ohos.taskpool（并发网络任务）、@ohos/pulltorefresh（HomePullToRefresh 封装）、WbiSigner（WBI 签名）、zxing 既有依赖不变
**State Management**: State Management V1（跟随项目现状，@State/@Link/@StorageLink/LazyForEach + IDataSource）
**Storage**: AppStorage + PersistentStorage 既有登录键（isOhBiliLoggedIn/ohBiliDedeUserId/ohBiliUname/ohBiliFace…），无新增持久化
**Testing**: devecocli build + 模拟器（127.0.0.1:5555，Mate 90 Pro，1280×2832）人工验证；Debug 日志开关沿用 Feedback 页
**Target Platform**: 仅 phone 产品（product/phone）；tablet（product/tablet）源码零改动、行为不变
**Project Type**: 既有 HarmonyOS 多产物工程（common HAR + phone/tablet 两个 entry）
**Performance Goals**: 动态列表首屏 3s 内呈现；LazyForEach + 数据源懒加载保证长列表流畅
**Constraints**: 所有交互只读；接口风控需有降级路径；路由沿用 router + main_pages.json；common 改动不得破坏 tablet 构建
**Scale/Scope**: 新增 4 个响应模型、4 个 API 端点、约 8 个 UI 组件、2 个新路由页 + 1 个重写页；入口接线 3 处

## Project Structure

### Documentation (this feature)

```text
spec/dynamic-user-space/
├── spec.md              # 需求规格（已批准）
├── plan.md              # 本文件
└── tasks.md             # Phase 3 产出
```

### Source Code (repository root)

```text
common/src/main/ets/
├── model/
│   ├── DataSourceManager.ts                  # [改] +DynamicDataSource、+SpaceArcDataSource
│   └── response/
│       ├── DynamicFeedResponse.ts            # [新] 动态流响应模型（modules 结构）
│       ├── SpaceAccInfoResponse.ts           # [新] 空间用户资料响应模型
│       ├── SpaceArcSearchResponse.ts         # [新] 投稿列表响应模型（arc/search）
│       └── SeriesArchivesResponse.ts         # [新] 投稿列表降级响应模型（series/recArchives）
├── network/
│   ├── Api.ts                                # [改] +4 端点：feed/all、space/acc/info、space/arc/search、series/recArchivesByKeywords
│   ├── TaskManager.ts                        # [改] +4 taskPool 任务与包装方法
│   └── ApiManager.ets                        # [改] +requestDynamicFeed/requestSpaceInfo/requestSpaceArchives
├── utils/
│   └── NavHelper.ets                         # [新] 设备门禁导航（goUserSpace/goGallery）
├── components/
│   ├── dynamic/
│   │   ├── DynamicItemView.ets               # [新] 动态条目分发容器（作者栏+内容+数据栏）
│   │   ├── DynamicVideoCard.ets              # [新] 视频动态卡片（可进播放页）
│   │   ├── DynamicDrawGrid.ets               # [新] 图文九宫格（1/2/4 自适应布局）
│   │   ├── DynamicTextView.ets               # [新] 文字内容（超长折叠/展开）
│   │   ├── DynamicForwardContent.ets         # [新] 转发内容（嵌套原动态，一层递归）
│   │   └── DynamicSimpleCard.ets             # [新] 专栏/番剧/合集等降级卡片
│   ├── video/VideoOverview.ets               # [改] UP 主头像/昵称点击 → NavHelper.goUserSpace
│   └── mine/UserHead.ets                     # [改] 已登录点击头部 → 自己的空间页
└── Index.ets                                 # [改] 导出新增模型与组件

product/phone/src/main/
├── ets/pages/
│   ├── Moments.ets                           # [重写] 动态流（登录引导保留 + HomePullToRefresh 分页）
│   ├── UserSpace.ets                         # [新] 用户空间页（资料头 + 投稿网格分页）
│   └── Gallery.ets                           # [新] 全屏图片预览页（黑底 Swiper，点击关闭）
└── resources/base/profile/main_pages.json    # [改] 注册 pages/UserSpace、pages/Gallery

product/tablet/                               # [零改动] 仅回归构建验证
```

**Structure Decision**: 跟随既有项目架构（common HAR + 产品 pages + router 导航 + State V1 + taskPool/retrofit 网络层 + DataSourceManager 数据源模式），不引入 MVVM。动态组件放 `common/components/dynamic/` 以对齐既有组件分区；两个新路由页与既有页面同置 `product/phone/ets/pages/`。文件数量由类型分发的自然边界决定（每动态类型一个渲染组件），未做进一步合并以保证单一职责与 LazyForEach 复用。

## Complexity Tracking

（无 Constitution 违规，无需条目。）

## Research & Decisions

- **Decision 1 — 动态类型分发不依赖数字枚举**：按 `module_dynamic.major` 下实际存在的主体对象（archive/draw/opus/article/pgc/ugc_season/…）分发渲染，`orig` 存在则按转发处理；不使用 B 站动态 type 数字值做主判断。
  **Rationale**: 社区文档已下线（B 站法务函后 bilibili-API-collect 删除），type 枚举值存在漂移风险（如图文从 draw 迁移到 opus）；主体对象存在性是稳定信号。
  **Alternatives considered**: 按 type 枚举 switch（风险高）；仅支持视频/图文（不满足"全类型"需求）。

- **Decision 2 — 投稿列表主备双接口**：主用 `x/space/wbi/arc/search`（WBI 签名 + Cookie），失败（code=-352 风控或网络异常）时降级 `x/series/recArchivesByKeywords`（无需 WBI）。
  **Rationale**: arc/search 数据最全但风控敏感；series 接口是社区验证过的低风控替代。
  **Alternatives considered**: 仅 arc/search（风控即全禁）；仅 series（数据字段少、无分页总数）。

- **Decision 3 — 空间页资料与数据分源**：资料（昵称/头像/签名/等级）用 `x/space/wbi/acc/info`（WBI）；数据（关注/粉丝/获赞/投稿数）用既有 `x/web-interface/card`；acc/info 失败时以 card 字段兜底渲染（缺签名/等级显示占位）。
  **Rationale**: card 接口已在工程内验证可用且覆盖三个数据字段；acc/info 提供资料但风控敏感。
  **Alternatives considered**: 仅 card（缺签名/等级，体验差）；acc/info + relation/stat + 单独关注数接口（请求数多、维护复杂）。

- **Decision 4 — NavHelper 设备类型门禁**：common 组件（VideoOverview/UserHead/动态组件）中所有进入 `pages/UserSpace` 的跳转收敛到 `NavHelper.goUserSpace`，内部仅当 `deviceInfo.deviceType === 'phone'` 时 `router.pushUrl`，否则记录日志静默返回；`goGallery` 同理。
  **Rationale**: VideoOverview/UserHead 为 common 组件、被 tablet 复用，而 UserSpace/Gallery 仅在 phone 注册；门禁保证 tablet 点击行为与现状完全一致（无跳转、无报错），满足 FR-011。
  **Alternatives considered**: 在 tablet 同步注册页面（违反"tablet 不动"）；每组件散落 deviceInfo 判断（重复、易漏）。

- **Decision 5 — 全屏图片预览用路由页**：`pages/Gallery` 接收 `{ urls, index }` 参数，黑底 Swiper + Image（contain），点击整页返回。
  **Rationale**: 独立页面天然覆盖全屏与返回栈语义，状态简单；overlay 方案需在各宿主页维护显隐状态。
  **Alternatives considered**: 宿主页内 overlay（状态管理复杂）；三方图片库（违反轻量假设）。

- **Decision 6 — 播放页参数复用 BaseVideo 协议**：动态视频卡片与空间投稿点击均构造 `BaseVideo`（复用 `EmptyBaseVideo(bvid)` 后填充 title/pic/pubdate/duration/owner/stat 已知字段）作为 `pages/Video` 路由参数。
  **Rationale**: 与既有 RecommendItem/PopularItem → Video 的参数协议一致，播放页按 bvid 自行加载完整数据。
  **Alternatives considered**: 扩展路由参数协议（侵入播放页，破坏既有调用方）。

- **Decision 7 — 动态流分页状态归页面持有**：Moments 页持有 offset 游标与 has_more 标志（对齐 RecommendView 持有 freshIdx 的既有模式），数据经 DataSourceManager 的 DynamicDataSource 供 LazyForEach 消费。
  **Rationale**: 与既有代码组织一致；DataSourceManager 保持纯数据源职责。

- **Decision 8 — "没有更多了"由 PullToRefresh 结果文案承载**：onLoadMore 在 `has_more=false` 时 resolve 文案字符串，由 @ohos/pulltorefresh 展示尾部提示。
  **Rationale**: 复用库能力，避免自绘尾部组件。
  **Alternatives considered**: 自绘"没有更多"Footer（多余工作量）。

- **Decision 9 — 图文动态双格式兼容**：九宫格渲染同时识别 `major.draw.items`（旧图文）与 `major.opus.pictures`（新图文 opus），统一为图片数组渲染。
  **Rationale**: B 站图文动态已迁移 opus 格式，存量 draw 仍存在。
  **Alternatives considered**: 仅 opus（丢存量）；仅 draw（丢新格式）。

## Data Model

（均为接口形态字段定义，实现时按 ArkTS interface 落地；可缺失字段一律可选。）

### DynamicFeedResponse（`x/polymer/web-dynamic/v1/feed/all` 响应）

- `DynamicFeedResponse extends BaseResponse<DynamicFeedData>`
- `DynamicFeedData`: `has_more: boolean`、`offset: string`（下一页游标）、`items: DynamicItem[]`
- `DynamicItem`: `id_str: string`（唯一键，LazyForEach key）、`modules: DynamicModules`
- `DynamicModules`: `module_author?: ModuleAuthor`、`module_dynamic?: ModuleDynamic`、`module_stat?: ModuleStat`
- `ModuleAuthor`: `mid: number`、`name: string`、`face: string`、`pub_time: string`、`pub_action?: string`（如"投稿了视频"）
- `ModuleDynamic`: `desc?: DynamicDesc`、`major?: DynamicMajor`、`orig?: ModuleDynamic`（转发时的原动态）、`module_tag?: { text: string }`
- `DynamicDesc`: `text: string`、`rich_text_nodes?: DynamicRichTextNode[]`；`DynamicRichTextNode`: `type?: string`、`text?: string`
- `DynamicMajor`（可选主体，按存在性分发）: `archive?: MajorArchive`、`draw?: MajorDraw`、`opus?: MajorOpus`、`article?: MajorArticle`、`pgc?: MajorPgc`、`ugc_season?: MajorUgcSeason`、`live?: MajorLive`
  - `MajorArchive`: `aid: number`、`bvid: string`、`title: string`、`cover: string`、`desc?: string`、`duration_text?: string`、`stat?: { view?: string, danmaku?: string }`
  - `MajorDraw`: `items: MajorDrawItem[]`；`MajorDrawItem`: `src: string`、`width?: number`、`height?: number`
  - `MajorOpus`: `title?: string`、`summary?: DynamicDesc`、`pics?: MajorDrawItem[]`
  - `MajorArticle`: `id: number`、`title: string`、`desc?: string`、`covers?: string[]`
  - `MajorPgc`: `title?: string`、`cover?: string`、`season_id?: number`、`epid?: number`
  - `MajorUgcSeason`: `title?: string`、`cover?: string`
  - `MajorLive`: `title?: string`、`cover?: string`
- `ModuleStat`: `forward?: { count: number }`、`comment?: { count: number }`、`like?: { count: number }`

### SpaceAccInfoResponse（`x/space/wbi/acc/info` 响应）

- `SpaceAccInfoResponse extends BaseResponse<SpaceAccInfo>`
- `SpaceAccInfo`: `mid: number`、`name: string`、`face: string`、`sign?: string`、`level?: number`、`official?: { role?: number, title?: string }`

### SpaceArcSearchResponse（`x/space/wbi/arc/search` 响应）

- `SpaceArcSearchResponse extends BaseResponse<SpaceArcData>`
- `SpaceArcData`: `list: { vlist: SpaceArcItem[] }`、`page: { pn: number, ps: number, count: number }`
- `SpaceArcItem`: `bvid: string`、`title: string`、`pic?: string`、`created: number`（发布时间戳）、`length: string`（"mm:ss"）、`play: number`、`author?: string`、`description?: string`

### SeriesArchivesResponse（`x/series/recArchivesByKeywords` 响应，降级）

- `SeriesArchivesResponse extends BaseResponse<SeriesArchivesData>`
- `SeriesArchivesData`: `archives: SeriesArchiveItem[]`、`page?: { num: number, size: number, total: number }`
- `SeriesArchiveItem`: `aid: number`、`bvid: string`、`title: string`、`pic?: string`、`duration?: number`（秒）、`pubdate?: number`、`sta?: { view?: number, danmaku?: number }`、`owner?: { mid: number, name: string, face?: string }`

### 页面间传递的聚合模型

- `SpaceUserProfile`（ApiManager 组装）：`mid`、`name`、`face`、`sign`、`level`、`following`、`follower`、`likeNum`、`archiveCount`、`profileLoaded: boolean`（acc/info 是否成功，失败时签名/等级用占位）
- 复用既有 `BaseVideo`/`Owner`/`Stat`/`EmptyBaseVideo`（Response.ts）作为播放页路由参数；`CardInfoResponse`（既有）作为空间数据源。

## Contracts & Interfaces

### API 端点契约（Api.ts 新增，均 GET，携带既有 Cookie 构造）

| 端点 | 关键参数 | 响应模型 | 备注 |
|---|---|---|---|
| `x/polymer/web-dynamic/v1/feed/all` | `@Header Cookie`、`timezone_offset=-480`、`offset`（首页空）、`features=itemOpusStyle`；`@Headers UA + Referer(t.bilibili.com)` | DynamicFeedResponse | offset 游标分页 |
| `x/space/wbi/acc/info` | `@Header Cookie`、`mid`、`w_rid`/`wts`（WbiSigner 对 `{mid}` 签名） | SpaceAccInfoResponse | 风控敏感，失败降级 |
| `x/space/wbi/arc/search` | `@Header Cookie`、`mid`、`pn`、`ps=30`、`order=pubdate`、`w_rid`/`wts`（WBI 对全参数签名） | SpaceArcSearchResponse | 主投稿列表 |
| `x/series/recArchivesByKeywords` | `mid`、`keywords=''`、`ps=30`、`pn` | SeriesArchivesResponse | 降级投稿列表 |

WBI 签名复用 `WbiSigner.signParams`；Cookie 复用 `LoginHelper.buildCookieHeader()`（含设备 buvid + 登录凭证）。

### TaskManager / ApiManager 方法契约

- `TaskManager.requestDynamicFeed(cookie, offset): Promise<ApiResponse<DynamicFeedResponse>>`（taskPool 任务）
- `TaskManager.requestSpaceAccInfo(cookie, mid, wRid, wts): Promise<ApiResponse<SpaceAccInfoResponse>>`
- `TaskManager.requestSpaceArcSearch(cookie, mid, pn, ps, order, wRid, wts): Promise<ApiResponse<SpaceArcSearchResponse>>`
- `TaskManager.requestSeriesArchives(mid, pn, ps): Promise<ApiResponse<SeriesArchivesResponse>>`
- `ApiManager.requestDynamicFeed(offset: string, isRefresh: boolean): Promise<boolean>`——成功后写入 DynamicDataSource（刷新清空重填 / 追加），页级 offset 由返回值携带（返回结构含 `has_more` 与新 `offset`，实现为轻量结果对象）
- `ApiManager.requestSpaceInfo(mid: number): Promise<SpaceUserProfile | null>`——并行/顺序拉取 acc/info + card 并组装；acc/info 失败时以 card 兜底（profileLoaded=false）
- `ApiManager.requestSpaceArchives(mid: number, isRefresh: boolean): Promise<boolean>`——arc/search 主、series 降级；成功写入 SpaceArcDataSource；刷新时清空重填；无更多返回明确结果
- `DataSourceManager.getDynamicSource(): DynamicDataSource`、`DataSourceManager.getSpaceArcSource(mid): SpaceArcDataSource`（空间页按 mid 实例隔离）

### 页面与组件契约

- **`pages/UserSpace`**（@Entry，注册 main_pages.json）：路由参数 `{ mid: number }`；结构 = OhNavBar（标题"用户空间"或昵称）+ 资料头（头像/昵称/LV 徽标/签名 + 关注/粉丝/获赞三列数据）+ 投稿网格（两列复用 RecommendItemView，经 SpaceArcItem→RecommendItem 映射）+ 上拉分页 + 空态/错误态/重试。
- **`pages/Gallery`**（@Entry，注册 main_pages.json）：路由参数 `{ urls: string[], index: number }`；黑底 Swiper(index) + Image(contain)，点击任意处 `router.back()`。
- **`Moments` 重写**：未登录保留现有登录引导（文案/按钮/跳转 Login 不变）；已登录 = HomePullToRefresh + DynamicDataSource + LazyForEach + DynamicItemView；onRefresh/onLoadMore 调 ApiManager.requestDynamicFeed；has_more=false 时加载更多 resolve "没有更多了"。
- **`DynamicItemView({ item: DynamicItem })`**：作者栏（头像+昵称+pub_time，点击 → NavHelper.goUserSpace(author.mid)）+ 按 major 分发（archive→DynamicVideoCard；draw/opus→DynamicTextView + DynamicDrawGrid；article/pgc/ugc_season/live/无 major→DynamicTextView/DynamicSimpleCard）+ 底部数据栏（转发/评论/点赞计数）；`orig` 存在 → DynamicForwardContent。
- **`DynamicVideoCard({ archive: MajorArchive, author: ModuleAuthor })`**：封面 16:9 + 时长角标 + 标题 + 播放/弹幕；点击构造 BaseVideo 跳 `pages/Video`。
- **`DynamicDrawGrid({ images: MajorDrawItem[] })`**：1 图单图（限高自适应）、2/4 图两列、其余三列九宫格；点击 → NavHelper.goGallery(urls, index)。
- **`DynamicTextView({ text: string })`**：默认最多 6 行，超出显示"展开"，点击切换折叠态。
- **`DynamicForwardContent({ orig, author })`**：转发理由文字 + 嵌套原动态（一层内复用 major 分发；orig 缺失显示"原动态已失效"）。
- **`DynamicSimpleCard({ title, cover, desc, typeName })`**：简化卡片；点击 toast"该类型内容暂不支持查看"。
- **`NavHelper.goUserSpace(mid: number)` / `NavHelper.goGallery(urls: string[], index: number)`**：仅 `deviceInfo.deviceType === 'phone'` 时跳转，否则日志静默。
- **VideoOverview（改）**：UP 主头像/昵称区域包可点击 → `NavHelper.goUserSpace(owner.mid)`；tablet 上为静默无操作（与现状一致）。
- **UserHead（改）**：已登录态整个头部可点击 → `NavHelper.goUserSpace(own mid)`（own mid 取 AppStorage `ohBiliDedeUserId`）；未登录行为不变（跳 Login）。

### 验证契约

- phone 构建产物部署模拟器后：动态 tab 三场景（未登录引导/已登录列表/空态错误态）、空间页三入口、Gallery 预览、视频跳转链路逐条人工验证（任务清单 Phase 3 细化）。
- tablet 构建零警告通过且行为与改动前一致（回归）。

## Changelog

- 2026-11-17 初版（Phase 2 产出）。
