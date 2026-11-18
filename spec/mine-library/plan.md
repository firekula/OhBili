# Implementation Plan: 我的页内容库（mine-library）

**Input**: Feature specification from `spec/mine-library/spec.md`

## Summary

为 phone 端补齐"我的"页四宫格功能：历史记录/我的收藏/稍后再看（B 站云端数据的浏览与管理，cookie+csrf 写操作）与完整离线缓存（清晰度选择、串行下载队列、缓存管理、断网本地播放）。技术路线：延续既有 common HAR + product/phone 架构与网络层三件套（Api/TaskManager/ApiManager）模式；离线缓存基于现有 **durl 单文件播放流**直接下载单文件（复用 `x/player/playurl` 加 `qn` 参数选档），本地播放走 AvPlayer `fdSrc` / IjkPlayer 本地路径分支；下载用 `@ohos.request.agent` 串行队列 + 元数据 JSON 持久化。

## Technical Context

**Language/Version**: ArkTS / ArkUI（HarmonyOS SDK API 26）
**Primary Dependencies**: 既有自研网络层（retrofit 风格装饰器 + taskPool）、`@ohos/pulltorefresh`、zxing、`@ohos.request`（下载）、`@ohos.file.fs`（本地文件）、AVPlayer/IjkPlayer（播放）
**State Management**: State Management **V1**（延续既有工程，增量功能不迁移 V2；本特性不引入 MVVM）
**Storage**: 应用沙箱 `filesDir/offline/`（离线视频文件 + `index.json` 任务元数据）；云端数据不落库、按需请求
**Testing**: `devecocli build --modules phone` + `devecocli run` 部署 + verify_ui（按用户故事）
**Target Platform**: HarmonyOS phone（模拟器 Mate 90 Pro x86_64 / 真机 ARM）；tablet 仅保证回归构建，零源码改动
**Project Type**: HarmonyOS 多模块应用（common HAR + product/phone + product/tablet）
**Performance Goals**: 列表页滚动 60fps；下载进度回调驱动 UI 刷新不卡主线程；单文件下载吞吐受 CDN 限制为准
**Constraints**: 破坏性操作二次确认；未登录不发起账号数据请求；本地播放不请求网络视频流
**Scale/Scope**: 新增 5 个 phone 页面、7 个 common 新文件、2 个新组件；修改网络三件套/数据源/四宫格/视频页；预计增量 < 4000 行

## Project Structure

### Documentation (this feature)

```text
spec/mine-library/
├── spec.md              # 需求规格（已批准）
├── plan.md              # 本文件
└── tasks.md             # /spec-tasks 输出
```

### Source Code (repository root)

```text
common/src/main/ets/
├── model/
│   ├── CacheTask.ets                        # [新] 离线缓存任务模型（状态机字段）
│   ├── DataSourceManager.ets                # [改] +HistoryDataSource/FavMediaDataSource/WatchLaterDataSource
│   └── response/
│       ├── HistoryResponse.ts               # [新] 历史列表响应（HistoryItem 含进度/类型）
│       ├── FavFolderResponse.ts             # [新] 收藏夹列表（FavFolder 含 media_count）
│       ├── FavResourceResponse.ts           # [新] 收藏夹内容（FavMedia 含时效状态）
│       ├── WatchLaterResponse.ts            # [新] 稍后再看（WatchLaterItem）
│       └── PlayUrlResponse.ts               # [改] +accept_quality/accept_description/timelength（可选字段）
├── network/
│   ├── Api.ts                               # [改] +历史(列表/单删/清空)、收藏(夹列表/夹内容/deal)、稍后再看(列表/加/移除)、playurl(qn)
│   ├── TaskManager.ts                       # [改] +对应 taskPool 任务与包装方法
│   └── ApiManager.ets                       # [改] +9 个业务方法；requestPlayUrl 增加可选 qn/platform 参数
├── utils/
│   ├── NavHelper.ets                        # [改] +goHistory/goFavorite/goWatchLater/goOfflineCache（phone 门禁）
│   └── DownloadManager.ets                  # [新] 串行下载队列、request.agent 封装、元数据持久化、监听器注册
├── components/
│   ├── mine/MineOpt.ets                     # [改] 四宫格可点击 → NavHelper 路由
│   └── video/VideoActionRow.ets             # [新] 视频页操作行（收藏/稍后再看/缓存 + 清晰度弹窗 + 收藏夹多选弹窗）
├── components/video/Player.ets              # [改] 本地播放分支（localPath 参数，AvPlayer fdSrc / Ijk 本地路径）
└── player/AvPlayer.ets                      # [改] +fdSrc 本地文件播放支持
common/Index.ets                             # [改] 导出新增公共符号

product/phone/src/main/ets/pages/
├── History.ets                              # [新] 历史记录页（列表/续播/单删/清空）
├── Favorite.ets                             # [新] 收藏夹列表页
├── FavDetail.ets                            # [新] 收藏夹内容页（取消收藏）
├── WatchLater.ets                           # [新] 稍后再看页（移除）
├── OfflineCache.ets                         # [新] 离线缓存管理页（进度/存储占用/删除/播放入口）
├── Video.ets                                # [改] 接入 VideoActionRow；路由参数 +startAt(续播)/+localPath(本地播放)
└── Mine.ets                                 # [不动] 四宫格在 MineOptView 内改造
product/phone/src/main/resources/base/profile/main_pages.json   # [改] +5 页面注册
```

**Structure Decision**: 遵循既有项目架构（common HAR 共享层 + product/phone 页面层，无 MVVM 迁移）。理由：纯增量功能，现有分层（model/response 模型、network 三件套、utils 工具、components 业务组件、pages 页面）完全覆盖需求；新增 DownloadManager 归入 utils（与 WindowManager 同级模式），CacheTask 模型归入 model，与 UserSpace/动态页先例一致。tablet 零改动（FR-011）。

## Complexity Tracking

无 Constitution 违规项——不新增工程/不引入 MVVM/不迁移状态管理版本。

## Research & Decisions

1. **离线缓存流格式：durl 单文件下载**
   - **Decision**: 复用现有 `x/player/playurl`（当前返回 durl 单文件流，Player 已按单 URL 播放），加 `qn` 参数选档，直接下载单文件至沙箱。
   - **Rationale**: 现状播放即 durl（`resp.data.durl[0].url`），单文件下载→本地单文件播放链路最短，AvPlayer/IjkPlayer 均原生支持本地 MP4。
   - **Alternatives considered**: DASH 双流（视频+音频分离）下载 + AVMuxer 合流——需 fMP4 解封装与混流，复杂度和失败面大，拒绝。
2. **下载实现：`@ohos.request.agent` + App 层串行队列**
   - **Decision**: 用 `request.agent` 执行单文件下载（支持自定义 header：B 站 CDN 要求 UA+Referer；自带进度回调），App 层 DownloadManager 维护"同时仅 1 个任务下载、其余等待"的串行队列。
   - **Rationale**: 系统级下载能力，进度/失败回调完备，无需手写 http 分块写文件。
   - **Alternatives considered**: `@ohos.net.http` 手动流式写文件——控制力强但需自管进度与断点，本期不需要暂停/恢复，拒绝。
3. **本地播放：AvPlayer `fdSrc` / IjkPlayer 本地路径**
   - **Decision**: Player 增加 localPath 分支：AvPlayer 播放器用 `fs.open` 取 fd 后走 fdSrc；IjkPlayer 直接传沙箱路径。Video 页通过路由参数 `localPath` 进入本地模式，跳过 playurl 请求。
   - **Rationale**: 两种播放器对本地文件的接入方式不同，分别适配；与现有 initPlay 分发结构兼容，改动最小。
   - **Alternatives considered**: 统一 `file://` URL——AVPlayer 对该 scheme 支持不保证，拒绝。
4. **历史列表分页：`x/v2/history` pn/ps**
   - **Decision**: 采用 `GET x/v2/history?pn&ps`（web cookie）分页；若实测服务端仅认游标，回退为 `max/view_at` 游标分页（实现时验证，不影响模型结构）。
   - **Rationale**: 与既有 pn/ps 模式一致，改动面最小。
   - **Alternatives considered**: 直接上 cursor 分页——历史列表页无需跨端对齐，简单优先。
5. **写操作鉴权：csrf（bili_jct）随查询参数**
   - **Decision**: 所有 POST 写操作（历史单删/清空、收藏 deal、稍后再看加/移除）携带 `csrf`（取自 AppStorage `ohBiliBiliJct`）+ Cookie。
   - **Rationale**: B 站 web 写接口标准要求；网络框架 `@POST`+`@Query` 已验证支持此形态（SMS 登录先例）。
6. **风控预案：必要时套 WBI 签名**
   - **Decision**: history/fav/toview 端点默认不 WBI 签名；若返回 -352/-403，按既有 WbiSigner 补签（同 space 端点的处理先例），并补浏览器 UA/Referer 头。
   - **Rationale**: 先最简，风控出现时再增量处理；先例已验证可行。
7. **删除交互：行尾删除按钮 + AlertDialog 确认**
   - **Decision**: 列表条目行尾放删除/移除图标按钮，点击弹 AlertDialog 二次确认；"清空历史"在页面右上角操作入口，同样确认。
   - **Rationale**: verify_ui 对左滑手势测试不可靠（前期已验证滑动自动化限制），按钮+弹窗可测性最好。
8. **清晰度选择与预估大小**
   - **Decision**: 缓存弹窗列出 `accept_description` 可用档位（来自 playurl 响应扩展字段）；选定档位后请求该 qn 的 playurl，以返回的 `durl.size` 作为预估大小在确认页展示，确认后入队下载。
   - **Rationale**: B 站不在档位列表里给大小，逐档预估需 N 次请求；"选定→确认大小→下载"两步式兼顾准确与请求成本。
9. **缓存元数据持久化**
   - **Decision**: `filesDir/offline/index.json` 持久化任务列表（状态/进度/大小/相对路径），启动时加载并校验文件存在性；存储占用 = 元数据聚合。
   - **Rationale**: 单一 JSON 索引足够（任务量级为几十），无需数据库。

## Data Model

### 响应模型（common/src/main/ets/model/response/）

- **HistoryResponse**: `data` 为 HistoryItem[]：`title/cover/author_face/author_name/view_at/progress(秒)/duration(秒)/aid/bvid/cid`；`history` 子对象含实际 `bvid/cid`；非视频类型（番剧/影视）以 `badge` 与缺失 bvid 标识降级
- **FavFolderResponse**: `data.list` 为 FavFolder[]：`id/media_id/title/media_count/fav_state(当前视频是否已收藏)`；`data.count` 总收藏数
- **FavResourceResponse**: `data.medias` 为 FavMedia[]：`bvid/title/cover/intro/duration/upper.name/fav_time/attr(时效：失效视频标记)`；`data.has_more` 分页标志
- **WatchLaterResponse**: `data.list` 为 WatchLaterItem[]：`aid/bvid/title/cover/owner.name/add_dt(秒)/duration`；条目数上限约 300
- **PlayUrlResponse（扩展）**: 新增可选 `accept_quality: number[]`、`accept_description: string[]`、`timelength(毫秒)`

### 本地模型（common/src/main/ets/model/CacheTask.ets）

- **CacheTask**: `id(bvid_cid_qn 唯一键)/bvid/cid/aid/title/cover/upName/quality(档位值)/qualityDesc/状态(WAITING|DOWNLOADING|COMPLETED|FAILED)/receivedBytes/totalBytes/localDir/fileName/createTime`
- 状态机：WAITING→DOWNLOADING→COMPLETED / FAILED（失败可删除重试；删除任意状态均可，需清理文件）

### 数据源（DataSourceManager 扩展，BasicDataSource 子类）

- **HistoryDataSource**（pn 分页）、**FavMediaDataSource**（pn 分页）、**WatchLaterDataSource**（全量单页，API 一次性返回）

## Contracts & Interfaces

### B 站 API 端点（全部走既有 DataService 装饰器声明）

| 端点 | 方法/参数 | 用途 |
|---|---|---|
| `x/v2/history` | GET，`pn/ps` + Cookie | 历史列表 |
| `x/v2/history/del` | POST，`kid(av{aid})` + `csrf` | 删除单条历史 |
| `x/v2/history/clear` | POST，`csrf` | 清空历史 |
| `x/v3/fav/folder/created/list-all` | GET，`up_mid` + Cookie | 收藏夹列表（含 fav_state） |
| `x/v3/fav/resource/list` | GET，`media_id/pn/ps/keyword=/order=mtime/tid=0/platform=web` + Cookie | 收藏夹内容 |
| `x/v3/fav/resource/deal` | POST，`rid(aid)/type=2/add_media_ids/del_media_ids(逗号分隔)/csrf` | 收藏/取消收藏（多夹一次提交） |
| `x/v2/history/toview/web` | GET + Cookie | 稍后再看列表 |
| `x/v2/history/toview/add` | POST，`aid` + `csrf` | 添加稍后再看 |
| `x/v2/history/toview/del` | POST，`aid` + `csrf` | 移除稍后再看 |
| `x/player/playurl`（扩展） | GET，`bvid/cid` + 可选 `qn/platform=html5/high_quality=1/fnval=0` + Cookie | 播放地址（带 qn 时返回对应档位 durl + 可用档位列表） |

### DownloadManager 公共接口（common/src/main/ets/utils/DownloadManager.ets）

- `getInstance()` 单例；`enqueue(task: CacheTask): void`（入队，串行调度）
- `remove(id: string): void`（删除任务并清理本地文件，下载中可中断取消）
- `getTasks(): CacheTask[]`；`getTotalSize(): number`（存储占用聚合）
- `registerListener(listener)/unregisterListener`（任务状态/进度变化回调，页面注册刷新 UI）
- 启动时从 `index.json` 恢复任务列表；FAILED/WAITING 残留保持原状态待用户操作

### 页面路由契约（phone）

- `History/Favorite/WatchLater/OfflineCache`：无参；未登录时页内渲染登录引导（不发起请求）
- `FavDetail`：`{ mediaId: number, title: string }`
- `Video`（扩展）：既有 BaseVideo 参数不变；新增可选 `startAt: number`（秒，续播起点）与 `localPath: string`（本地模式，跳过 playurl 直接播本地文件）
- MineOptView 四宫格 → NavHelper.goHistory/goFavorite/goWatchLater/goOfflineCache

### 组件契约

- **VideoActionRow**（common/components/video/VideoActionRow.ets）：入参 bvid/cid/aid；内嵌两个弹窗——清晰度选择（选定后二次确认预估大小）与收藏夹多选（fav_state 预勾选，deal 提交增删差集）；"稍后再看"按钮即时 add/del 并 toast 结果
- **MineOptView**（改造）：四宫格点击回调走 NavHelper（phone 门禁，tablet 静默）

## Changelog

- 2026-11-18: 初版生成（对应 spec/mine-library/spec.md v1）。
