# Feature Specification: DASH 取流与高清播放（方案 A：本地 MPD + 段代理 + 系统 AvPlayer）

**Created**: 2026-11-24  
**Status**: Approved（2026-11-24）  
**Input**: docs/参考项目分析-PiliPlus与BiliPai弹幕及完整功能对比.md 第 1 项功能差距（DASH 取流）；spike 验证已完成（模拟器 + 真机双端通过，分支 `test/dash-spike`）

## Overview

在 OhBili（phone 模块）中实现 B 站 DASH 音视频分离取流与播放：通过 wbi playurl（fnval=4048）获取 dash 流，本地拼装 MPD（SegmentBase 字节区间形式），经本地 HTTP 服务（MPD 分发 + CDN 段代理）交给系统 AvPlayer 的 DASH demuxer 播放。登录用户可解锁 1080P/1080P 高码率/4K 等高清档位，清晰度菜单与切换保持现有交互，DASH 不可用时自动回退现有 durl 链路。spike 已在模拟器与真机双端验证整条管线（含 DASH ABR 自动升降档）。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - DASH 高清播放 (Priority: P1)

用户播放普通视频时走 DASH 管线（音视频分离流），可播放其账号权限内最高档位（未登录 360P~720P，登录 1080P 及以上），画面与声音正常，起播速度与现状相当。

**Why this priority**: DASH 管线是本功能的最小可用切片，高清档位解锁是相对现状（legacy durl 封顶）的核心价值。

**Independent Test**: 登录后播放任意普通视频 → 播放正常且清晰度菜单显示 1080P 及以上档位 → 选择 1080P 播放画面明显变清晰。

**Acceptance Scenarios**:

1. **Given** 用户已登录，**When** 播放普通视频，**Then** 走 DASH 管线起播，正常网络下 5 秒内出画面
2. **Given** DASH 播放中，**When** 持续观看，**Then** 音视频同步、无因本地代理造成的规律性卡顿
3. **Given** 用户已登录且视频支持，**When** 打开清晰度菜单，**Then** 菜单包含 1080P（及更高）档位且可选

---

### User Story 2 - 清晰度切换（DASH 链路，含自动档） (Priority: P1)

用户在清晰度菜单选择档位（含「自动」档，默认）后：手动档位按所选清晰度锁定播放；自动档由播放器按网络状况自适应升降档；切换均保持播放进度与弹幕位置连续。

**Why this priority**: 清晰度切换是播放器核心交互；自动档利用 DASH ABR 免费获得网络自适应能力，是 DASH 管线相对 durl 的体验增量。

**Independent Test**: 播放中打开清晰度菜单 → 默认为「自动」→ 手动切到 1080P → 短暂加载后从原进度以 1080P 锁定播放，弹幕同步。

**Acceptance Scenarios**:

1. **Given** DASH 播放中，**When** 用户切换清晰度（手动档），**Then** 新档位起播后进度与切换前偏差不超过 1 秒
2. **Given** 清晰度菜单，**When** 用户查看，**Then** 含「自动」档且为默认选中
3. **Given** 自动档播放中且网络波动，**When** 可用带宽变化，**Then** 播放清晰度自适应升降档，无中断
4. **Given** 用户切换到无权限档位（如非大会员选 4K），**When** 服务端回退实际档位，**Then** 提示实际生效档位（沿用现状回退提示）
5. **Given** 用户选择过某档位（手动或自动），**When** 之后播放新视频，**Then** 优先使用记忆档位起播（沿用 `ohBiliPlayQn`，自动档以特殊值记忆）

---

### User Story 3 - DASH 失败自动回退 durl (Priority: P1)

DASH 链路任一环节失败（接口无 dash 字段、MPD/服务构建失败、播放器 error）时，自动回退现有 durl 链路播放，用户无感知（最多感知到多一次加载）。

**Why this priority**: 回退保障存量可用性——DASH 是增强而非替换，任何回归都是事故。

**Independent Test**: 构造 dash 缺失场景（如断网重试、接口异常）→ 播放器自动走 durl 链路 → 视频仍可播放。

**Acceptance Scenarios**:

1. **Given** playurl 响应无 dash 字段（如部分老视频/特殊内容），**When** 取流完成，**Then** 自动按现有 durl 链路起播
2. **Given** DASH 播放中收到 error 事件（如 CDN 段请求持续失败），**When** 播放器进入 error 状态，**Then** 自动回退 durl 链路并从当前进度续播
3. **Given** 本地 HTTP 服务启动失败（如端口不可用且重试耗尽），**When** 尝试 DASH 起播，**Then** 回退 durl 链路，不崩溃不白屏

---

### User Story 4 - 编码偏好选择 (Priority: P2)

用户可在播放器设置菜单选择视频编码偏好（AVC / HEVC / AV1，默认 AVC），DASH 流按偏好过滤；所选编码设备不支持时自动降级到可用编码。

**Why this priority**: 不同设备解码能力差异大（spike 实测模拟器无 AV1 解码器直接 prepare 失败）；偏好设置让高端设备用高压缩编码、低端设备保兼容。

**Independent Test**: 播放器设置菜单选择 HEVC → 重新播放视频 → 正常播放且走 HEVC 流。

**Acceptance Scenarios**:

1. **Given** 播放器设置菜单，**When** 用户选择编码偏好，**Then** 选择持久化（重启保持）
2. **Given** 偏好编码在 MPD 中无 Representation（如该视频无 AV1 流），**When** 构建 MPD，**Then** 自动降级到次优先编码（AV1→HEVC→AVC）而非播放失败
3. **Given** 默认（未设置过），**When** 构建 MPD，**Then** 使用 AVC（最大设备兼容性）

---

### Edge Cases

- 端口占用：本地服务端口被占时自动 +1 重试（固定起始端口，最多 N 次），耗尽后走 durl 回退
- 播放器销毁/页面退出：本地 HTTP 服务随播放器释放关闭，无端口泄漏、无僵尸连接
- dash 流缺 SegmentBase（如 P2P CDN 特殊流）：跳过该 Representation；全部缺失则回退 durl
- 切换视频/切集：旧 MPD 失效，服务更新内容；并发请求不串台（以最新 bvid/cid 为准）
- B 站 URL 双重转义（`\u0026`）：构建 MPD 时统一还原
- 匿名（未登录）：dash 请求按现状 wbi 降级签名逻辑执行，能取到则播（档位受限），取不到回退 durl

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 取流 MUST 走 wbi playurl（fnval=4048、fourk=1），支持指定 qn（记忆档位）与登录态 cookie
- **FR-002**: MPD 构建器 MUST 以 SegmentBase 字节区间形式输出本地 MPD（isoff-on-demand profile），包含视频/音频两个 AdaptationSet，并按编码偏好过滤视频 Representation
- **FR-003**: 本地 HTTP 服务 MUST 提供 MPD 分发与 CDN 段代理：代理注入 `User-Agent`/`Referer`，透传 `Range`/`Content-Range`/`Content-Type`/状态码；上游失败返回 502
- **FR-004**: MPD 中段 URL MUST 重写为本地代理 URL（BaseURL 指向 127.0.0.1 服务）
- **FR-005**: 播放 MUST 使用 AvPlayer `setMediaSource` + `PlaybackStrategy`（起播档位映射 preferredWidth/Height），并按 stateChange 状态机驱动 prepare/play
- **FR-006**: 清晰度菜单数据源 MUST 来自 dash 响应（accept_quality/accept_description），切换 MUST 保持进度与弹幕分段续播（复用现有 switchSourceResume 机制）
- **FR-013**: 清晰度菜单 MUST 含「自动」档位（默认选中）：自动档下 MPD 包含全部可用 Representation，由系统 DASH demuxer 按网络状况自适应升降档（真机已验证 ABR 升档）；手动选档时 MPD 仅保留该 qn 对应 Representation（锁定档位），偏好持久化
- **FR-007**: DASH 任一环节失败 MUST 自动回退现有 durl 链路（无 dash 字段、构建失败、服务启动失败、播放 error 事件），回退后不重复触发回退（防循环）
- **FR-008**: 编码偏好 MUST 提供 AVC/HEVC/AV1 三选项（默认 AVC），存储于设置并持久化；无对应流时按 AV1→HEVC→AVC 顺序降级
- **FR-009**: 本地服务 MUST 随播放器生命周期启停：端口冲突自动重试，销毁时释放
- **FR-010**: 番剧链路（epId>0）本阶段 MUST 保持现状 durl，不受 DASH 改动影响
- **FR-011**: spike 代码 MUST 全部移除：DashSpike 页面、main_pages 注册、Splash 直跳、以及临时的 `[SPIKE]` 标记改动收敛进正式实现
- **FR-012**: 段代理 MUST 仅代理 B 站 CDN 域名（白名单校验），不作为开放代理

### Key Entities

- **BiliDash / BiliDashStream / BiliSegmentBase（响应模型）**: playurl dash 段结构（video[]/audio[]/dolby/flac、id/codecs/bandwidth/width/height/SegmentBase），spike 版转正
- **DashMpdBuilder（MPD 构建器）**: 输入 dash 响应 + 编码偏好 + 代理基地址，输出 MPD 字符串；职责：Representation 过滤、URL 双重转义还原、XML 转义、代理 URL 重写
- **LocalDashServer（本地 HTTP 服务）**: TCPSocketServer 封装；职责：MPD 内存分发、段代理（http kit 上游请求 + 头注入 + Range 透传）、端口冲突重试、生命周期管理
- **DashPlaybackSession（DASH 播放会话）**: 串联取流 → MPD 构建 → 服务启动 → setMediaSource → 状态机推进 → 错误回退的编排单元
- **编码偏好（CodecPreference）**: AVC/HEVC/AV1 用户设置项，持久化存储

## Implementation Approach (实现方案，spike 双端验证通过)

### 架构（生产形态）

```
wbi playurl(fnval=4048, qn) ──> BiliDash 模型
        │
        ▼
DashMpdBuilder（编码过滤 + SegmentBase + BaseURL→代理重写）
        │
        ▼
LocalDashServer (127.0.0.1:PORT)          AvPlayer
  ├─ GET /dash.mpd    ── 内存 MPD ──>  setMediaSource(mpdUrl, headers)
  └─ GET /seg?url=…   <── Range ────    DASH demuxer 段请求
        │  注入 UA/Referer，透传 Range
        ▼
   B 站 CDN (206/Content-Range)
```

### 关键技术决策（spike 实测依据）

1. **本地 MPD 必须经 HTTP 分发**：`createMediaSourceWithUrl` 只接受 HTTP(S) MPD；本地裸路径与 `fd://` 均不触发 DASH demuxer（state 停留 idle），且 `AVMimeTypes` 无 `APPLICATION_MPD`（仅 M3U8）。→ 需要本地 HTTP 服务。
2. **段代理必须存在**：`setMediaSource` 的自定义头不透传到跨域段请求（真机/模拟器实测 CDN 403；同 URL+头 http kit 直连 206）。→ BaseURL 重写为本地代理，代理注入 UA/Referer 并透传 Range/Content-Range，全程 206 无失败。
3. **PlaybackStrategy 起播档位**：preferredWidth/Height 由所选 qn 的分辨率映射；真机实测起播后 DASH ABR 自动升档工作（720P→1080P 高码率），无需自实现升降档。
4. **编码过滤是硬需求**：模拟器实测选中设备无解码器的流（AV1）直接 prepare 失败（5400106）。→ MPD 构建时按偏好过滤 Representation。
5. **回退链设计**：dash 响应无效 → durl；prepare/error → reset 后 durl 续播；回退仅尝试一次，防循环。
6. **清晰度切换**：手动档采用「重取 playurl(qn) + 重建 MPD + switchSourceResume 续播」（与现状交互一致、实现直接）；DASH `selectTrack` 无缝切换列为后续优化。
7. **自动档位**：清晰度菜单新增「自动」（默认）。自动档请求最高 qn 以取全流，MPD 含全部（编码过滤后的）Representation，PlaybackStrategy 起播档位居中，后续升降档交由系统 demuxer ABR（真机已验证）；手动档 MPD 仅保留所选 qn 的 Representation 以锁定档位。
8. **音质**：本阶段不做切换 UI，默认选取 dash 响应中最高可用音质档。

### 落地位置（初步）

- `common/src/main/ets/player/`：LocalDashServer、DashMpdBuilder 新增
- `common/src/main/ets/components/video/Player.ets`：getPlayUrl/switchQuality 增加 DASH 分支与回退
- `common/src/main/ets/network/`：requestPlayUrlWbiDash 转正（spike 版已有）
- 播放器设置菜单：编码偏好入口

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 登录用户 DASH 可用的视频播放成功率 ≥ 现状 durl 基线（真机回归通过）
- **SC-002**: 正常网络下 DASH 起播（进入页面到出画面）≤ 5 秒，不劣化现状
- **SC-003**: 清晰度切换后进度偏差 ≤ 1 秒，弹幕分段连续
- **SC-004**: 连续播放 10 分钟无因本地代理造成的规律性卡顿（buffering 事件频率与 durl 相当）
- **SC-005**: DASH 不可用场景（无 dash 字段/服务失败/播放 error）100% 自动回退 durl 可播
- **SC-006**: spike 代码零残留（全仓检索 `SPIKE`、`DashSpike` 无结果，Splash 路由还原）

## Assumptions

- 仅 phone 模块实现；tablet 模块后续单独对齐（与 qr-login spec 同口径）
- 番剧（epId>0）本阶段保持 durl 现状
- B 站 wbi playurl 的 dash 可用性稳定；接口/风控变化属外部依赖风险，回退链兜底
- 匿名 dash（低档位）可用性以实测为准，不可用则匿名走 durl（现状封顶 720P）
- 弹幕倍速联动、播完行为、CDN 替换测速、手势等对比文档其余差距项不在本期范围
- spike 验证结论（2026-11-24 真机：probe 206 → prepared 1280x720 → PLAYING → ABR 升档 1080P 高码率）作为技术方案依据

## Open Questions

（已全部决策，2026-11-24）

1. **清晰度切换实现**：✅ 手动档「重取 playurl + 重建 MPD + 续播」；另按用户要求新增「自动」档（DASH ABR 网络自适应，默认选中，见 FR-013）
2. **音质档位**：✅ 本期默认最高可用音质，不做切换 UI
3. **编码偏好入口**：✅ 播放器设置菜单
