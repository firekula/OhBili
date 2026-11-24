# PiliPlus × BiliPai 参考项目分析报告（弹幕渲染 + 完整功能对比）

> 分析日期：2026-11-24
> 参考源码位置（本地浅克隆）：
> - `C:\Users\Firekula\AppData\Local\Temp\deveco\BiliPai\` — 原生 Android Kotlin+Compose 第三方 B 站客户端（GPLv3，v0.9.6(608)）
> - `C:\Users\Firekula\AppData\Local\Temp\deveco\PiliPlus\` — Flutter 第三方 B 站客户端的 **OpenHarmony/HarmonyOS 移植 fork**（Flutter 3.35.8-ohos-0.0.2，仅 ohos/ 平台目录）
> - `C:\Users\Firekula\AppData\Local\Temp\deveco\canvas_danmaku\` — 从 pub 镜像下载的 canvas_danmaku 0.3.1 官方源码（PiliPlus 弹幕渲染包）
>
> 分析性质：纯调研报告，未修改 OhBili 任何代码。供后续对话继续使用。

---

# 第一部分：弹幕渲染实现深度分析

## 〇、结论速览

| 维度 | BiliPai（内嵌字节跳动引擎） | PiliPlus（canvas_danmaku 0.3.1） |
|---|---|---|
| 宿主渲染面 | 普通 `android.view.View`，窗口硬件加速 Canvas | Flutter `CustomPaint` + RepaintBoundary |
| 技术路线 | **画布模式**：每帧矢量重绘文本（stroke+fill 两遍 drawText） | **纹理模式**：加入时一次性 `toImageSync` 光栅化成 `ui.Image`，每帧只 `drawImageRect` |
| 帧驱动 | Choreographer + RenderFrameCadence，`invalidate()` 每帧 | 单 Ticker + ValueNotifier tick，空列表自动停表 |
| 描边 | Paint.STROKE 先描后填，默认宽 2.75px、色 argb(97,0,0,0) | 独立 stroke Paragraph 先画，默认 1.5，黑色 |
| 缓存 | DrawItem 对象池（防分配），**无位图缓存** | 每条弹幕一份位图纹理 + >10 条时 Picture 批绘制 |
| 防重叠 | 轨道行 + 速度差投影碰撞检测 | 轨道行 + 速度差投影碰撞检测（思路同源） |

两个项目恰好分别对应了 bilibili "渲染方式" 开关背后的两种经典实现：**直接绘制（画布）** 与 **位图缓存（纹理）**。

## 一、BiliPai（原生 Android Kotlin + 内嵌字节跳动引擎）

### 1.1 架构分层

```
app 层  DanmakuManager.kt（~3200 行编排：分段加载/seek 同步/设置映射/本地发送）
        ↓ 通过 DanmakuEngine 接口解耦
封装层  com.android.purebilibili.danmaku.*
        ByteDanceDanmakuEngine / DanmakuRenderView(FrameLayout 宿主) / 解析器 / BAS 脚本
引擎层  com.bytedance.danmaku.render.engine.*（Apache-2.0，作者 dss886）
        DanmakuView → DanmakuController → RenderEngine → 4 × IRenderLayer
```

- **DanmakuView 是普通 View，不是 SurfaceView/TextureView**（DanmakuView.kt:34）。绘制发生在 `View.draw(canvas)`，直接画进窗口的硬件加速 Canvas，与视频画面同层合成，无独立渲染线程。
- 帧调度：`Choreographer.postFrameCallback` + `RenderFrameCadence`（仅当 frameTimeNs 严格大于上一帧才渲染，"never turn 90/120Hz into uneven 60fps"），随后 `invalidate()` 请求重绘（DanmakuView.kt:49-57）。
- 节流：`pauseInvalidateWhenBlank=true`（DanmakuConfig.kt:220）—— 屏上无弹幕时停止 invalidate，零帧开销。

### 1.2 层与绘制管线

- `RenderEngine` 固定挂 4 层：ScrollLayer、TopCenterLayer、BottomCenterLayer、MaskLayer（RenderEngine.kt:59-67）。
- 每帧 `draw()`：各层收集 `getPreDrawItems()` → 全局按 `drawOrder → layerZIndex → showTime` 排序（仅失序时排）→ 逐条绘制（RenderEngine.kt:123-182）。
- 蒙版弹幕（AI 防遮挡）：mask 路径与可见弹幕同时存在时，对可见弹幕包围盒做 `canvas.saveLayer` + Xfermode，让弹幕"绕开"人物区域（RenderEngine.kt:142-180 + MaskConfig）。

### 1.3 文本与描边（TextDrawItem.kt）

- **两遍绘制**：先 `Paint.Style.STROKE`（strokeWidth 默认 **2.75px**，strokeColor 默认 **argb(97,0,0,0) 半透明黑**，DanmakuConfig.kt:264-274），再 `FILL` 正文。支持逐条覆盖（data.textStrokeWidth/Color）。
- 字体：`Typeface` 全局/逐条可配，`includeFontPadding` 开关处理亚字形留白，FontMetrics memo 缓存。
- 彩色特性：VIP 渐变（#FFD86F→#FF80B5→#8A9FFF，LinearGradient + setLocalMatrix 平移，Shader 只建一次）；UP 主粉色徽章（#FB7299 圆角矩形，宽度计入 measure 参与轨道排布）；下划线双遍绘制。
- 逐条暂停：`CMD_PAUSE_ITEM` 后暂停项的 `lastRenderTimeMs` 仍持续刷新，恢复时不"追赶"暂停期间位移（BaseRenderLine.kt:48-53）。

### 1.4 运动与碰撞（ScrollLine.kt）

- 速度模型：`speed = (itemWidth + viewWidth) / moveTime`，moveTime 默认 8000ms —— **长弹幕快、短弹幕慢**（B 站同款语义）。
- 碰撞：`hasEnoughSpace` 先查行尾空间，再做**速度差投影**：`(newSpeed-speed) × moveTime` 前瞻余量检查，防后发快弹幕屏内追尾慢弹幕（ScrollLine.kt:76-86）。
- 溢出缓冲：`LayerBuffer`（scroll 默认 8 条/4 秒过期；top/bottom 4 条/2 秒）+ `BufferAdmission` 的 **PriorityQueue 打分准入**——按分数保留 top-N、过期强制淘汰、同分先淘汰早到者。
- 对象池：`DrawCachePool` 按 drawType 分桶 `SimplePool(64)` 复用 DrawItem（含 Paint 复用），消除每帧 GC 压力；**这不是位图缓存，只是对象复用**。

### 1.5 App 层编排（DanmakuManager.kt）

- 分段窗口：360 秒一段，`rollWindowForward` 增量加载 + 裁剪；XML protobuf 解析 + **BAS 高级弹幕脚本**（lexer/parser/timeline/easing），SpecialDanmakuWindow / TimedDanmakuWindow 分窗管理。
- Seek 策略：拖动进度条时 `prepareForSeekScrub()` 暂停并清空旧时间线弹幕，松手 `cancelSeekScrub()` 恢复；显式 seek 用 resync 标记去重，避免重复硬重同步（L2728-2835）。
- 倍速联动：`resolveDanmakuEnginePlaySpeedPercent` 把视频倍速映射到 `playSpeedPercent`，`moveTime` 随 `baseDurationMs` 等比重算（L1384-1393）。
- 本地发送：`addLocalDanmaku` 直接注入缓存列表并重排序；字号 18/25/36 经 `resolveBilibiliDanmakuFontScale` 归一。

### 1.6 暴露的设置项（app→engine 映射）

`opacity`（不透明度）、`fontScale`（全屏/非全屏独立）、`useFullscreenTextSize`、`displayArea`（显示区域）、`strokeWidth`（描边）、`massiveMode`（海量模式）、`lineHeight`、`staticDanmakuToScroll`（静态转滚动）、`smartOcclusionEnabled`（智能防遮挡）、`scrollDurationMs`（速度）、倍速同步、类型屏蔽、`fontWeight/bold`、块屏蔽等级。配置变更走 `applyConfigToController(reason)` 统一落引擎。

## 二、PiliPlus（Flutter + canvas_danmaku ^0.3.1）

### 2.1 架构分层

```
PiliPlus 集成层  PlDanmaku widget（view.dart）+ PlDanmakuController（数据层）+ DanmakuOptions（设置映射）
canvas_danmaku   DanmakuScreen（State）→ 3 × RepaintBoundary(CustomPaint)
                ScrollDanmakuPainter / StaticDanmakuPainter / SpecialDanmakuPainter
```

- 包是 pub 托管依赖（sha256 校验 0.3.1），非自研、非 fork。
- 帧驱动：单个 `Ticker`（vsync）推进 `ValueNotifier<int> tick` 触发重绘；**三列表全空时自动 `_ticker.stop()`**，新增弹幕重启（danmaku_screen.dart:466-472, 215-219）。清理惰性——每 10 个 tick 才做一次 `removeWhere`（_lazyTick）。

### 2.2 核心技术：位图纹理缓存（utils.dart:65-145）

1. 弹幕**加入时**用 `ui.ParagraphBuilder` 排版（含 `(count)` 合并前缀缩放 0.6 倍）；
2. 立即 `PictureRecorder` 录制：先画 stroke 段落（`PaintingStyle.stroke`，黑色；VIP 彩色时 stroke 用 #F2509E→#308BCD 渐变 shader），再画 fill 段落，selfSend 附加绿色描边矩形框；
3. `toImageSync` 以 `devicePixelRatio` 为倍率光栅化为 `ui.Image` 纹理；
4. **每帧只做 `canvas.drawImage / drawImageRect`**（DPR=1 直接 drawImage，否则 src→dst 缩放绘制）——矢量文字光栅化每条只发生一次。

- 批绘制优化：可见弹幕 >10 条（batchThreshold）时全部画进一个 `Picture` 再一次性 `drawPicture`。
- 代价：每条弹幕占一份 GPU 纹理内存；`updateOption` 里 fontSize/fontWeight/strokeWidth/fontFamily 任一变化 → **全量 dispose 所有 image 重新光栅化**。

### 2.3 运动与轨道（danmaku_screen.dart）

- 轨道数：`trackCount = viewHeight × area / danmakuHeight`；`safeArea && area==1.0` 时减 1 条给字幕留位。
- 位移按 tick 差分推进：`xPosition += (drawTick - tick)/duration × distance`。
- 碰撞：入屏不重叠 + 快弹幕追尾慢弹幕的投影检查（与 BiliPai 同思路不同表达）。
- 轨道满时：selfSend 强制放第 0 轨；`massiveMode` 随机挑轨叠加；否则丢弃。
- 高级弹幕（mode 7）：`SpecialDanmakuContentItem.fromList(jsonDecode(content))`，支持 `rotateZ` 与 3×3 `matrix`；`_calculateRotatedBounds` 算旋转包围盒，光栅化最长边超过 **8192px 上限**强制降 DPR。描边用 `Shadow(blurRadius=strokeWidth)` 而非 stroke 路径。

### 2.4 数据层（PiliPlus controller.dart）

- gRPC `DmGrpc.dmSegMobile` 按 **6 分钟段**加载，`_requestedSeg` 防重复请求；失败移除标记可重试。
- 存储结构：`Map<百毫秒桶, List<DanmakuElem>>`（`progress ~/ 100`），播放位置监听按 100ms 粒度对齐取桶注入。
- 过滤链：weight 阈值 → 合并重复（count++）→ 正则 filters → isSelf（midHash 匹配）→ 彩色转白（blockColorful）→ 类型屏蔽（2 滚/4 底/5 顶/7 特殊）→ `danmakuStatic2Scroll` 顶底转滚动。
- 本地文件源直接 `DmSegMobileReply.fromBuffer(bytes)`。

### 2.5 暴露的设置项（danmaku_options.dart）

`fontSize = 15 × fontScale`（**全屏/非全屏两套 fontScale**）、`fontWeight`、`area`、`duration`（**danmakuFixedV 开关：固定时长 or 时长÷倍速**）、`staticDuration`、`strokeWidth`、`massiveMode`、`safeArea`、`lineHeight`、五个 hide 开关；不透明度由外层 `AnimatedOpacity` 包装。

## 三、"渲染方式"（画布/纹理）语义对照

| | 画布（直接绘制）— BiliPai 路线 | 纹理（位图缓存）— PiliPlus 路线 |
|---|---|---|
| 每帧成本 | 每条弹幕 2 次矢量 drawText，高密度下文本光栅化开销线性增长 | 每条 1 次 GPU 纹理 blit，几乎与内容复杂度无关 |
| 内存 | 低（只缓存 Paint/对象池） | 每条弹幕一份纹理；海量弹幕时内存显著更高 |
| 设置热切换 | 即时生效（下一帧直接按新 measure/draw） | 需全量 dispose + 重新光栅化 |
| DPR/分辨率适配 | 无额外处理 | 必须按 devicePixelRatio 光栅化，有光栅化尺寸上限（8192） |
| 掉帧表现 | 慢时整帧文字延迟 | 慢时仅位图搬运延迟，视觉一致性更好 |

两者共享的工程共识（B 站系弹幕事实标准）：
1. 速度模型：横穿时长固定（8-10s），长弹幕速度更快；
2. 防追尾碰撞：入屏不重叠 + 速度差×时长前瞻余量；
3. 轨道行：按显示区域百分比和行高算轨道数，满了丢弃或叠加（海量模式）；
4. 描边：先描后填、默认半透明黑/纯黑、宽度可设置；
5. 空屏零开销（pauseInvalidateWhenBlank / ticker.stop）；
6. 分段拉取 + 时间桶注入 + weight/类型/正则过滤链；
7. 拖动进度条即时暂停清屏、松手恢复。

## 四、差异化亮点（事实陈述）

- **BiliPai 独有**：BAS 高级弹幕脚本引擎（lexer/timeline/easing 全套）、蒙版防遮挡（saveLayer+Xfermode）、逆向滚动层、逐条暂停/恢复（无追赶跳变）、蒙版层与可见弹幕包围盒联动的 saveLayer 裁剪、PriorityQueue 打分的缓冲准入。
- **PiliPlus 独有**：全屏/非全屏独立字号档、`danmakuFixedV`（固定速度 vs 固定时长）开关、>10 条 Picture 批绘制、DPR 感知的 drawImage/drawImageRect 双路径、倍速下 duration 自动除以 speed。
- 两者共同缺失：均无用户可见的"渲染方式"开关——各自内定了技术路线。

---

# 第二部分：完整功能对比分析报告

## 一、项目定位与技术栈

| | PiliPlus | BiliPai |
|---|---|---|
| 定位 | Flutter 跨端 B 站客户端，**本仓库是其 OpenHarmony/HarmonyOS 移植 fork** | 原生 Android Kotlin B 站客户端（GPLv3），多模块工程 |
| 语言/框架 | Dart/Flutter `3.35.8-ohos-0.0.2`（仅 `ohos/` 平台目录，无 android/ios） | Kotlin 2.4.21 + Jetpack Compose，minSdk 26 |
| 规模 | `lib/pages/` 109 个页面模块 | 42 个 feature 包 + 14 个 Gradle 模块；API 层 294 端点、3525 行 |
| 播放器 | **media_kit/libmpv**（ohos fork `br_v1.2.6_ohos`，path 依赖） | **Media3/ExoPlayer 1.11.1** |
| 弹幕 | canvas_danmaku ^0.3.1（pub 包，位图纹理路线） | 内嵌字节跳动引擎（dss886，画布直绘路线）+ BAS 脚本 |
| UI 语言 | Material 3 + Material You 动态取色 | Material3 + **Miuix（小米 HyperOS 风格 KMP 库）**+ Haze 液态玻璃 + 弹性动效，双 UI 预设 |
| 状态/存储 | GetX + Hive（KV） | MVVM + DataStore + Room（3 实体）+ Kotlin 多模块分层 |

## 二、播放器核心对比（重点：渲染方式）

### 2.1 视频渲染方式

| | PiliPai | BiliPai |
|---|---|---|
| 渲染面 | **单一模式：libmpv 渲染 API → GPU 纹理**，经 media_kit_video 的 `Video`/`Texture` widget 上屏（controller.dart:758-765） | **双模式自动切换：默认 SurfaceView，按需 TextureView** |
| SurfaceView/TextureView | 无此概念——mpv 输出永远是 Flutter 纹理 | `CompatibleVideoSurface.kt:53` 按策略选型：SDR 翻转/实时画面转场用 TextureView；**HDR10(125)/杜比视界(126)/HDR Vivid(129) 强制 SurfaceView**（TextureView GPU 合成会把 HDR 色调映射为 SDR，VideoPlayerSectionPolicy.kt:1085-1096） |
| 用户设置 | 无"渲染方式"开关 | 无独立用户开关——策略驱动；"实时画面转场"开关间接控制 TextureView 使用（SDR 用 TextureView 一镜到底，HDR 仍 SurfaceView） |
| 系统兼容 | 依赖 media_kit ohos fork 内部处理 | Android 9 SurfaceView 清除重绑 + Android 14–17 Compose surface 同步双 workaround（VideoSurfaceCompatibility.kt） |

**结论**：B 站官方"渲染方式"（SurfaceView/TextureView）语义在 BiliPai 中以 **HDR 安全策略**的形式完整落地——HDR 必走 SurfaceView 保色调，SDR 转场场景才用 TextureView；PiliPai 因 Flutter 架构天然只有纹理一条路，HDR 色调正确性完全依赖 mpv/系统合成器。

### 2.2 硬解与解码格式

| | PiliPai | BiliPai |
|---|---|---|
| 硬解开关 | "开启硬解"+ **hwdec 模式多选**（mediacodec/d3d11va/vaapi/nvdec 等，Android 默认 `auto-safe`），mpv `--hwdec` | `playback.hw_decode` 开关 + **编码偏好首选/次选**（AVC/HEVC/AV1 单选，软解回退） |
| 解码失败处理 | 提示"无法加载解码器…切换至软解"+ 3 秒自动重试 refreshPlayer | PlayerErrorRecoveryPolicy + VideoDecoderDiagnostics |
| 视频信息调试 | 全屏"视频信息"面板（hwdec-current/vo/pitch 等） | PlayerInsightMode 三档（编码/码率/掉帧常驻显示） |
| 杜比音频 | 依赖设备/系统 | **dolby-ffmpeg-decoder 模块**：Media3 FFmpeg 扩展软解 EAC3/AC3（杜比全景声 JECK/JOC），FFmpeg 6.0、arm64-v8a、包名 `androidx.media3.decoder.ffmpeg` 作为扩展 Renderer 注册 |
| Hi-Res | mpv 直解 | **HiResCompatibleRenderersFactory**：给系统 FLAC 解码器预留 ≥1MiB 输入缓冲；Hi-Res 解码失败自动回退 AAC |
| 超分辨率 | **Anime4K**：番剧/影视默认启用，glsl shader 挂 mpv `glsl-shaders` | **Anime4K/FSR1.0 GL 管线**：独立 anime4k feature（GLSurfaceView + shader 仓库），走插件 API |

### 2.3 取流与格式

| | PiliPai | BiliPai |
|---|---|---|
| 主格式 | DASH（`fnval=4048, fourk=1`），音视频双流分离：视频走 `Media()`、音频挂 mpv `audio-files` | DASH，**LocalDashManifestBuilder** 把 B 站音视频轨拼成本地 MPD XML 交给 Media3 DASH |
| 兜底 | durl（FLV/MP4）"已被淘汰，仅做兜底" | 无 FLV/MP4 偏好设置（统一 DASH） |
| 接口 | UGC `/x/player/wbi/playurl`、PGC `/pgc/player/web/v2/playurl`、PUGV `/pugv/player/web/playurl` | WBI playurl + PlayUrlCache（LruCache 防重复解析）+ `dash_segment_requests_enabled` DASH 分段并发开关 |
| 免登录高画质 | `try_look=1` 免登录 1080P | 未见对应开关 |
| CDN | 21 个 CDN 服务商整体替换 host + CDN 测速 + "音频不跟随 CDN" | 17+ upos 镜像自动优选/指定 + CDN 测速 + 自定义规则 + CdnDashSegmentPrefetcher 分段预取（插件化） |

### 2.4 音频/字幕/倍速

| | PiliPlus | BiliPai |
|---|---|---|
| 后台音频 | audio_service（ohos fork）`BaseAudioHandler` + 媒体通知；ohos 侧 `backgroundModes: audioPlayback` | 双服务：`PlaybackService:MediaSessionService`（视频）+ `BackgroundAudioService:MediaLibraryService`（听视频，**支持 Android Auto**）+ 全局 MiniPlayerManager 小窗 |
| 音量均衡 | mpv `lavfi-complex`（dynaudnorm/loudnorm/自定义参数） | LoudnessNormalizationAudioProcessor（Media3 音频处理器） |
| 音轨 | 音质选择（默认 hi-res/蜂窝 k192）、多语言音轨经 mpv 挂载 | 音轨分类策略（标准/Dolby/Hi-Res 徽章）、杜比软解标记、多语言音轨重拉 playurl |
| 字幕 | CC 字幕 → media_kit SubtitleTrack（VTT 转换缓存）；字号/字重/描边/边距/背景不透明度可调；本地字幕加载/保存 | 双字幕轨（主/副）；本地导入 **JSON/BCC/WebVTT/SRT/ASS/SSA** 五格式；**字幕独立字体导入**；玻璃态字幕渲染；VTT/SRT 导出 |
| 倍速 | mpv setRate + 弹幕速度同步；倍速列表自定义页；长按倍速（×2 或预设） | 0.1–8.0x 钳制、11 档预设可增删、记住上次、长按临时加速 1–8x、提示浮层大小可调 |
| 画面比例 | 9 档（fill/contain/cover/4:3/16:9/等宽/等高/原始/scaleDown），记忆 + 竖屏 fill 降级 contain | 同为 9 档映射 AspectRatioFrameLayout，全屏比例独立设置 |
| 播完行为 | mpv PlaylistMode + PlayRepeat | 5 档：自动连播/播完暂停/顺序/单循环/列表循环 |

### 2.5 弹幕（浓缩，详见第一部分）

| | PiliPlus（canvas_danmaku） | BiliPai（ByteDance engine） |
|---|---|---|
| 路线 | **纹理模式**：一次性光栅化 + 每帧位图 blit | **画布模式**：硬件加速 Canvas 每帧矢量重绘 |
| 独有 | DPR 双路径、Picture 批绘制、全屏双字号档 | **BAS 高级弹幕脚本**、蒙版防遮挡、逆向滚动、逐条暂停、PriorityQueue 准入、UP 徽章/VIP 渐变/下划线 |

## 三、手势与交互

| 能力 | PiliPlus | BiliPai |
|---|---|---|
| 横滑 seek | 相对时长（滑全屏=百分比）或固定秒数，带缩略图预览 | 滑动跳转 + 灵敏度设置 + 预览 |
| 纵滑 | 左亮度/右音量/中间滑全屏（可反向） | 同类分区 + 手势灵敏度、躺卧模式 |
| 双击 | 可选"左退右进中暂停"或双击播放暂停 | 双击快进幅度可调 |
| 长按 | 倍速（×2 或预设，震动反馈，直播禁用） | 长按临时加速 1–8x |
| 其他 | 双指缩小视频、全屏锁定、mpv 截图、键盘控制 | 区域截图 feature、锁定按钮、平板键盘快捷键、预测性返回 + 26 种视频卡片 morph 转场 |
| 竖屏沉浸 | 竖屏扩大 | **PortraitVideoPager 竖屏上下滑** + Story 竖屏故事模式 |

## 四、账号与登录

| | PiliPlus | BiliPai |
|---|---|---|
| 登录方式 | 扫码/密码（极验+风控短信）/短信/Cookie 四 Tab | TV 扫码/密码短信（极验）/Cookie 导入/**PiliPlus 身份导入**/**设备间扫码传输登录态**（分块+加密+KeyStore） |
| 多账号 | Hive 多账号 + **4 槽位账号分型**：主账号/心跳记录/推荐/视频取流 各可用不同账号或匿名，API 级映射可视化 | 多账号 + 按用途分账号（播放账号可与登录账号不同）+ 账号台账页 |
| 凭证安全 | Hive 明文 + cookie jar | **SessionStorageCipher 会话加密落盘** |
| 凭证类型 | Cookie + access_token/refresh_token（gRPC 头用 accessKey） | Cookie + appkey 签名（TV/Android/HD/64 位四套 appkey）+ TokenManager |

## 五、网络层

| | PiliPlus | BiliPai |
|---|---|---|
| HTTP | dio 5.9 + 可选 **HTTP/2**（dio_http2_adapter）+ 重试拦截器 + brotli | Retrofit 3.0 + OkHttp 5.5（brotli）+ 自定义 DNS + 15+ Retrofit 实例 |
| gRPC | 完整生成代码：grpc-over-HTTP POST（gzip protobuf），覆盖弹幕/动态/评论/私信/空间/音频 | 手写 gRPC-over-HTTP 客户端（ProtoWire 手工 wire 编解码，无 .proto 生成），覆盖评论/动态/IM/长连接广播 |
| 签名 | WBI（mixinKey 打乱+md5，每日缓存） | WBI（nav 取钥、磁盘缓存、启动预热、412 风控专门建模）+ AppKey appsec MD5 |
| 代理 | 应用层代理（HTTP1/2 均生效，同步给 mpv http-proxy）+ 忽略证书选项 | NetworkProxyPolicy + GithubMirrorPolicy（更新镜像） |

## 六、业务功能全景

**两者都有**（约 40+ 项）：推荐/热门/分区首页、直播全套（分区/关注/搜索/SuperChat/直播弹幕 WS/表情）、番剧影视、课程（PUGV）、视频详情全套（相关/评论/简介/分段看点/投币/笔记/AI 总结）、动态 feed + 发布/转发/投票/话题、消息中心 + 私信（gRPC IM）、搜索聚合 + 热搜、历史（含暂停恢复）、收藏夹、稍后再看、用户空间（投稿/合集/充电/小店）、专栏、听视频/音频区、投屏（DLNA）、下载离线、画中画、后台播放、WebDAV 备份、空降助手（SponsorBlock）、黑名单、弹幕屏蔽规则、检查更新、扫码/密码/Cookie 登录、多账号、深色/动态取色。

**PiliPlus 独有**：
- **HarmonyOS 一等公民支持**（ohos 宿主 + 全套 ohos-fork 插件生态，git_clone.ps1 从 gitcode OpenHarmony TPC 克隆）
- 免登录 1080P（try_look）；HTTP/2；音量均衡（lavfi-complex）
- 相对滑动手势；**首页 Tab 可编辑**（直播/推荐/热门/分区/番剧/影视）
- 动态发布端完整（投票/预约/@/话题选择）；充电排行/小店/漫画投稿等长尾 Tab（109 页面覆盖极广）
- **互动视频（stein graph）**；登录设备管理/登录日志；BGM h5 音乐页

**BiliPai 独有**：
- **TV 端**（Compose TV：播放/弹幕/评论/搜索/扫码登录/续播）
- **插件系统**：12 个内置 Kotlin 插件（空降助手/去广告/Anime4K/CDN 选线/DLNA/Google Cast 等）+ JSON 规则插件（URL 导入+编辑器）+ `.bilipai.js` JS 插件（headless WebView 运行时，四桥注入，扩展内容源）+ `.bpplugin` 预览 + `.bpskin` 皮肤包
- **Google Cast 投屏 + DLNA 本地代理服务器（NanoHTTPD）**
- **设备间接力**（NSD+TLS，播放进度跨设备迁移）；Android Auto（听视频）
- 桌面小组件（播放控制 RemoteViews）；杜比视界/HDR Vivid 正确渲染
- **AI 水军识别 + 评论存档导入导出**；区域截图；生物识别隐私锁；外部歌单导入；黑名单云同步；第三方直播站点抽象（虎牙）；多套品牌图标 + 233 娘 Lottie

**两者都无**：漫画阅读器（均为链接跳转）、passkey、全量云同步、Xposed hook。

## 七、扩展能力细对比

| 能力 | PiliPlus | BiliPai |
|---|---|---|
| 下载 | 自研 DownloadService（仿 bilimiao entry.json/index.json），DASH 分轨 | 自研 DownloadManager + WorkManager 断点续传 + 弹幕资产下载 + 离线播放走本地 MPD |
| 投屏 | dlna_dart | DLNA（SSDP+本地代理）+ Google Cast 双路，均插件化 |
| PiP | floating 插件（手动/自动、SDK≥36 setPipAutoEnterEnabled、PiP 不加载弹幕） | 系统 PiP 全场景（视频/番剧/直播/竖屏/听视频 1:1） |
| 后台 | audio_service 通知 | MediaSessionService + MediaLibraryService + MiniPlayer 小窗 + Android Auto |
| 桌面小部件 | ❌ | ✅ 播放/续播小部件 |
| 插件化 | ❌ | ✅ 四形态插件 + 能力清单授权 |
| TV | ❌ | ✅ app-tv 模块 |

## 八、设置体系

- **PiliPlus**：8 大组（隐私/推荐/视频/播放/样式/其他/WebDAV/关于）+ **设置项搜索页**；播放相关粒度极细——硬解模式多选、视频同步算法（video-sync/autosync）、音频输出设备排序、扩大缓冲区、CDN 测速、蜂窝/WiFi 独立画质音质、首选/次选解码格式（DVH1/AV1/HEVC/AVC）。
- **BiliPai**：9 大组（界面/动效/播放/首页动态/导航/隐私/下载备份/插件中心/帮助）；播放页 9 个 section——视频解码（硬解+编码偏好）、倍速、网络画质（CDN 选线/弹性缓冲/定向流量/省流量模式三态 480P 封顶/画质链 16→129）、诊断档位、连播、手势、小窗后台。
- 差异要点：PiliPlus 暴露更多 **mpv 专家参数**；BiliPai 暴露更多 **产品化策略**（省流量三态、画质模式 AUTO/LOCKED、播完行为 5 档、诊断档位）。

## 九、UI 设计语言与主题

| | PiliPlus | BiliPai |
|---|---|---|
| 基座 | Material 3 + dynamic_color/flex_seed_scheme 动态取色 | Material3 + MaterialKolor 动态取色 + **壁纸种子取色** |
| 风格化 | 纯黑主题、界面缩放、页面过渡动画 | **Miuix（top.yukonga.miuix.kmp 全家桶）可选整体 UI**、Haze 2.0.1 液态玻璃（可调模糊/对比度/彩光/形变）、Cupertino 备选、澎湃 OS 运动参数、金标联盟 SharedViewKit 卡片转场 |
| 品牌 | — | 233 娘/蓝雪女仆 Lottie（brand-motion 模块）、多套应用图标别名 |
| 字体 | App 字重 + 独立字体大小设置页 | 应用级自定义字体导入（字重轴）+ 字幕独立字体 |

## 十、数据持久化

| | PiliPlus | BiliPai |
|---|---|---|
| 偏好 | Hive（KV） | DataStore Preferences |
| 数据库 | — | Room（仅 3 实体：拉黑 UP/AI 水军记录/搜索历史） |
| 缓存 | dio 层 + 图片缓存 | OnDemandRequestCache（LruCache+TTL+in-flight 去重）、PlayUrlCache、SubtitleCueMemoryCache、Coil 3 + 省流量降质拦截器、封面预取调度 |
| 同步 | WebDAV 设置同步 | WebDAV 手动+自动定时备份（Worker）、设置分享文件、黑名单云同步 |

## 十一、PiliPlus 的 ohos/ 目录（对 OhBili 的特殊参考价值）

- 标准 DevEco/hvigor 工程结构：`AppScope/`、`entry/`、`hvigor/`，compatibleSdkVersion 5.1.0(18)，deviceTypes: ["phone"]
- `EntryAbility.ets` 继承 **`FlutterAbility`（@ohos/flutter_ohos）** 并注册 GeneratedPluginRegistrant；`Index.ets` 用 `FlutterPage` 挂载 Flutter 视图 —— 即 **OpenHarmony Flutter 宿主层**，无业务插件代码（插件全部由 git_pub 的 ohos-fork 提供）
- `entry/src/main/module.json5`：`backgroundModes: ["audioPlayback"]`；权限 INTERNET/READ_MEDIA/WRITE_MEDIA/GET_NETWORK_INFO/KEEP_BACKGROUND_RUNNING
- `git_clone.ps1` 专门克隆 gitcode.com 上 OpenHarmony SIG/TPC 的 ohos 版插件（media_kit/audio_service/volume_controller/wakelock_plus/file_picker 等 path fork）
- **结论**：其 ohos 目录只含 Flutter 宿主，无原生 ArkTS 业务代码可移植；参考价值在架构决策与插件生态清单

## 十二、综合评价

| | PiliPlus（ohos fork） | BiliPai |
|---|---|---|
| 架构哲学 | 借力成熟引擎：libmpv 全能解码 + pub 生态 + ohos TPC 插件 fork，工程量小、功能覆盖面大（109 页面） | 自建工程体系：14 模块 + 294 端点 + 自研弹幕引擎/下载器/插件运行时/TV 端，工程质量与集成度极高 |
| 播放上限 | mpv（软解兜底、shader 超分、参数全开放），但 HDR 语义依赖合成器 | Media3 + HDR 策略化 SurfaceView/TextureView + 杜比软解扩展 + Hi-Res 缓冲修复，**播放正确性工程最扎实** |
| 弹幕上限 | 纹理模式，高密度稳，无高级弹幕 | 画布模式 + BAS 脚本 + 蒙版防遮挡，**B 站全弹幕类型覆盖最全** |
| 平台 | **可在 HarmonyOS 运行** | 仅 Android（手机 + TV） |
| 可迁移性结论 | 借鉴集中在：**mpv/纹理输出经验、账号分型、CDN 策略、页面功能清单** | 借鉴集中在：**渲染策略（HDR→SurfaceView 等价物、弹幕双路线）、Media3 式本地 DASH 拼装、插件架构、设置信息架构**；全部需以 ArkTS 重写 |

---

## 附：关键数字速查

- BiliPai：Media3 1.11.1；FFmpeg 6.0（仅 eac3+ac3，arm64-v8a）；BilibiliApi 294 端点/3525 行/15+ Retrofit 实例；内置插件 12 个；feature 包 42 个；设置根分类 9 个；倍速 0.1–8.0x；清晰度链 129→127→126→125→120→116→112→100→80→74→64→32→16；播完行为 5 档；Manifest 服务 3 个（PlaybackService/BackgroundAudioService/MessageNotificationService）
- PiliPlus：lib/pages 109 模块；首页 3 Tab（首页/动态/我的）+ 首页二级 6 Tab（直播/推荐/热门/分区/番剧/影视，可编辑）；账号 4 槽位分型；CDN 21 选 1；弹幕分段 6 分钟；gRPC-over-HTTP gzip protobuf
- canvas_danmaku 0.3.1：strokeWidth 默认 1.5；batchThreshold 10；maxRasterizeSize 8192；duration 默认 10s
- ByteDance 弹幕引擎：strokeWidth 默认 2.75px / argb(97,0,0,0)；moveTime 默认 8000ms；scroll 缓冲 8 条/4s；对象池 SimplePool(64)
