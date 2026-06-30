# 测试分析报告

**生成日期**: 2026-06-29
**项目名称**: flutter_aliplayer 鸿蒙化适配测试分析

---

## 第一部分：概述

### 1.1 插件基本信息

| 项目 | 内容 |
|------|------|
| 插件名称 | flutter_aliplayer |
| 版本 | 7.15.0 |
| 仓库地址 | 阿里云播放器 Flutter 插件 |
| 许可证 | 阿里云商用 SDK 许可 |
| 已支持平台 | Android、iOS（鸿蒙化适配新增 HarmonyOS） |

### 1.2 插件简介

flutter_aliplayer 是阿里云播放器官方 Flutter 插件，封装了 AliyunPlayer SDK（独立 SDK / 音视频终端 SDK），为 Flutter 应用提供点播、直播、短视频列表、直播时移等播放能力，并支持视频下载、媒体预加载、画中画、外挂字幕、截图、缩略图、DRM、悬浮窗等扩展能力。原插件通过 MethodChannel（5 个）、EventChannel（4 个）、按 playerId 拼接的 BasicMessageChannel（十余个）以及 PlatformView（SurfaceView/TextureView/AliDisplayView）实现 Flutter 与原生 SDK 的通信。

鸿蒙化适配以 HarmonyOS Media Kit 的 AVPlayer 为播放内核重新实现，XComponent 作为视频渲染面，AVImageGenerator 用于截图与帧提取，DRM Kit 用于 DRM 流程，@ohos.net.http 用于网络下载与预加载。Aliyun VOD 生态数据源（VidSts/VidAuth/VidMps）、ARTC/RTS 超低延时直播、Aliyun 本地缓存/HttpDNS、FairPlay 等私有能力在鸿蒙侧无对等映射，需做安全空实现并日志提示。

### 1.3 典型使用场景

**目标用户：**
- 视频点播/直播应用开发者
- 短视频与列表播放应用开发者
- 阿里云 VOD/RTS 生态用户

**典型使用场景：**
1. 在 Flutter 应用中嵌入视频点播播放器并控制播放
2. 在视频列表中顺序播放多个视频源并预加载相邻项
3. 直播回看与时移播放
4. 视频截图、外挂字幕、轨道切换等增强播放体验
5. 视频离线下载与播放前媒体数据预加载

---

### 1.4 功能模块一览

| 模块编号 | 功能名称 | 描述 | 优先级 |
|----------|----------|------|--------|
| F-01 | 播放器实例与生命周期管理 | 创建、持有、释放播放器实例，按 playerId 多实例管理 | P0 |
| F-02 | 视频源设置 | 设置 URL/VidSts/VidAuth/VidMps/LiveSts 数据源，切换流 | P0 |
| F-03 | 播放控制 | prepare/play/pause/stop/seek/setStartTime/reload/clearScreen | P0 |
| F-04 | 视频渲染面 | AliPlayerView PlatformView 嵌入与绑定 | P0 |
| F-05 | 播放配置 AVPConfig | 缓冲水位、网络超时、HTTP 头、userAgent 等配置 | P1 |
| F-06 | 轨道管理 | 查询/切换音视频/字幕轨，设置默认码率/语言 | P1 |
| F-07 | 字幕 | 添加/选择外挂字幕，字幕回调 | P1 |
| F-08 | 截图与缩略图 | 截取当前帧、获取指定位置缩略图 | P1 |
| F-09 | 渲染模式 | 缩放/旋转/镜像/背景色设置 | P0 |
| F-10 | 音量/倍速/静音/循环/快启 | volume/speed/muted/loop/autoPlay 等播放属性 | P0 |
| F-11 | 事件回调 | 播放器状态、错误、进度、缓冲等事件透传 | P0 |
| F-12 | 列表播放器 | FlutterAliListPlayer 列表/预加载能力 | P1 |
| F-13 | 直播时移播放器 | FlutterAliLiveShiftPlayer 时移回看 | P2 |
| F-14 | 视频下载 | FlutterAliDownloader 普通明文下载 | P2 |
| F-15 | 媒体预加载 | MediaLoader v1/v2 播放前预取 | P2 |
| F-16 | 全局设置 | FlutterAliPlayerGlobalSettings 全局网络/亮度 | P2 |
| F-17 | 全局播放器设置 | FlutterAliplayer 静态方法：版本/日志/缓存等 | P2 |
| F-18 | DRM | setDrmCallback 证书/密钥回调（鸿蒙侧空实现） | P3 |
| F-19 | 悬浮窗与画中画 | 悬浮窗/PiP 能力（鸿蒙侧空实现） | P3 |
| F-20 | 双向回调 | URL/Auth 过期、预渲染帧等双向回调 | P3 |

### 1.5 API 接口

**公开 API 列表**:

- `FlutterAliPlayerFactory.createAliPlayer({playerId})`: 创建播放器实例。（返回值：`FlutterAliplayer` - 播放器实例）
- `FlutterAliPlayerFactory.createAliListPlayer()`: 创建列表播放器实例。（返回值：`FlutterAliListPlayer`）
- `FlutterAliPlayerFactory.createAliLiveShiftPlayer()`: 创建直播时移播放器实例。（返回值：`FlutterAliLiveShiftPlayer`）
- `FlutterAliplayer.init(id)` / `create()` / `release()` / `releaseAsync()`: 实例初始化与释放。（返回值：`Future<void>`）
- `setUrl(url)` / `setVidSts(...)` / `setVidAuth(...)` / `setVidMps(...)` / `setLiveSts(...)` / `switchStream(url)` / `setDataSource(timeLineUrl,url)`: 设置播放源。（返回值：`Future<void>`）
- `prepare()` / `play()` / `pause()` / `stop()` / `seekTo(position,seekMode)` / `setStartTime(time,seekMode)` / `reload()` / `clearScreen()` / `clearScreenSync()`: 播放控制。（返回值：`Future<void>`）
- `setPlayerView(viewId)` / `aliPlayerViewType`: 渲染面绑定与类型。（返回值：`void`）
- `getConfig()` / `setConfig(map)` / `getPlayConfig()` / `setPlayConfig(AVPConfig)`: 播放配置读写。（返回值：`AVPConfig` / `Future<void>`）
- `getMediaInfo()` / `getSubMediaInfo()` / `getCurrentTrack(trackIdx)` / `currentTrack(trackType)` / `selectTrack(trackIdx,{accurate})` / `setDefaultBandWidth/Resolution/AudioLanguage`: 轨道管理。（返回值：`Future<MediaInfo>` / `Future<void>`）
- `addExtSubtitle(url)` / `selectExtSubtitle(trackIndex,enable)`: 外挂字幕。（返回值：`Future<void>`）
- `snapshot(path)` / `createThumbnailHelper(url)` / `requestBitmapAtPosition(position)`: 截图与缩略图。（返回值：`Future<void>`）
- `setScalingMode/ setRotateMode/ setMirrorMode/ setAlphaRenderMode/ setVideoBackgroundColor`: 渲染模式。（返回值：`Future<void>`）
- `setVolume/ setSpeed/ setMuted/ setLoop/ setAutoPlay/ setFastStart`: 播放属性。（返回值：`Future<void>`）
- `setOnPrepared/ OnRenderingStart/ OnError/ OnCompletion/ OnInfo/ OnVideoSizeChanged/ OnSeekComplete/ OnLoadingStatusListener/ OnStateChanged/ OnTrackReady/ OnTrackChanged/ OnSubtitle*` 等: 事件回调注册。（返回值：`void`）
- `FlutterAliListPlayer.addVidSource/addUrlSource/removeSource/getCurrentUid/clear/setPreloadCount/moveToNext/moveToPre/moveTo`: 列表播放器操作。（返回值：`Future<void>` / `String`）
- `FlutterAliLiveShiftPlayer.getCurrentLiveTime/getCurrentTime/seekToLiveTime/setDataSource`: 时移操作。（返回值：`Future<int>` / `Future<void>`）
- `FlutterAliDownloader.prepare/start/stop/delete/setSaveDir/release`: 下载操作。（返回值：`Future<void>`）
- `FlutterAliPlayerMediaLoader.load/loadWithBandWidth/resume/pause/cancel` 与 v2 `addTask/addUrlTask/resumeTask/pauseTask/cancelTask`: 预加载操作。（返回值：`Future<void>` / `String`）
- `FlutterAliPlayerGlobalSettings.setGlobalEnvironment/setSystemBrightness/getSystemBrightness`: 全局设置。（返回值：`Future<void>` / `Future<int>`）
- `FlutterAliplayer.getSDKVersion/enableConsoleLog/setLogLevel/clearCaches`: 全局播放器设置。（返回值：`Future<String>` / `Future<void>`）

**API 总数**: 约 90 个公开 API

---

## 第二部分：整体测试分析

### 2.1 插件类型

本插件名为 flutter_aliplayer，主要实现视频播放、列表播放、直播时移、视频下载、媒体预加载等功能，通过 MethodChannel（5 个）、EventChannel（4 个）、按 playerId 拼接的 BasicMessageChannel（十余个）以及 PlatformView（SurfaceView/TextureView/AliDisplayView）等多种 Channel 与原生 AliyunPlayer SDK 通信，属于混合型插件。

> **注意**：原插件通过封装 Android AliyunPlayer SDK 与 iOS AliPlayerSDK 实现；鸿蒙化后改用 HarmonyOS AVPlayer + XComponent + AVImageGenerator + DRM Kit + @ohos.net.http 重新实现播放内核与扩展能力。

**插件分析结论**：本插件属于 **plugin_mixed**。

### 2.2 测试策略

**功能测试策略（根据插件类型定制）**：

首先识别插件类型为 plugin_mixed，针对各功能模块分析测试重点：

| 模块 | 功能名称 | 功能类型 | 测试重点 | 测试策略 |
|------|---------|---------|---------|---------|
| F-01 | 播放器实例与生命周期管理 | 平台交互类 | 实例创建/释放、多实例隔离、资源回收 | 等价类划分 + 状态迁移测试 |
| F-02 | 视频源设置 | 平台交互类 | URL/Vid 源设置、流切换、无效源处理 | 等价类划分 + 边界值分析 |
| F-03 | 播放控制 | 平台交互类 | 状态机迁移、seek 精准/不精准、reload 重连 | 状态迁移测试 + 边界值分析 |
| F-04 | 视频渲染面 | UI 组件类 | 渲染面嵌入、绑定、类型切换、全屏重建 | UI 自动化 + 状态迁移测试 |
| F-05 | 播放配置 AVPConfig | 工具类 | 缓冲/网络/HTTP 头配置生效、无效值容错 | 等价类划分 + 边界值分析 |
| F-06 | 轨道管理 | 平台交互类 | 轨道查询/切换、默认值设置、不存在轨道处理 | 等价类划分 + 异常处理测试 |
| F-07 | 字幕 | 平台交互类 | 外挂字幕添加/启用/关闭、无效地址处理 | 等价类划分 + 异常处理测试 |
| F-08 | 截图与缩略图 | 平台交互类 | 帧截图保存、指定位置缩略图、无效路径处理 | 等价类划分 + 边界值分析 |
| F-09 | 渲染模式 | UI 组件类 | 缩放/旋转/镜像/背景色生效 | 等价类划分 + 枚举全覆盖 |
| F-10 | 音量/倍速/静音/循环/快启 | 平台交互类 | 各播放属性生效、越界值容错 | 等价类划分 + 边界值分析 |
| F-11 | 事件回调 | 后台服务类 | 关键事件回调触发、字段一致、时序正确 | 状态迁移测试 + 事件验证 |
| F-12 | 列表播放器 | 平台交互类 | 列表增删、前进/后退/跳转、越界处理 | 等价类划分 + 异常处理测试 |
| F-13 | 直播时移播放器 | 平台交互类 | 时移数据源设置、当前时间查询 | 等价类划分 |
| F-14 | 视频下载 | 后台服务类 | 下载任务准备/开始/停止、进度回调 | 状态迁移测试 |
| F-15 | 媒体预加载 | 后台服务类 | 任务添加/暂停/取消、状态回调 | 状态迁移测试 |
| F-16 | 全局设置 | 工具类 | 全局环境变量、系统亮度 | 等价类划分 |
| F-17 | 全局播放器设置 | 工具类 | SDK 版本查询、日志配置、缓存清理 | 等价类划分 |

**兼容性测试、DFX 测试、安全测试策略**：

| 测试类型 | 测试重点 | 测试策略 |
|----------|----------|----------|
| 兼容性测试 | 验证不同设备款型、不同 HarmonyOS API 版本的兼容性 | 覆盖直板高端、直板中低端、双折叠、阔折叠四种设备款型，覆盖 API19、API21、API22、API23 版本，设备款型与 API 版本交叉验证 |
| DFX 测试 | 覆盖稳定性测试、性能测试、功耗测试、UX 测试 | 通过云测试验证各 DFX 专项测试 |
| 安全测试 | 验证病毒扫描、开源软件漏洞、敏感信息 | 通过安全扫描工具覆盖 |

---

## 第三部分：详细测试分析

### 3.1 功能测试

按功能模块逐一分析，采用 **IBO（Input-Behavior-Output）模型** 进行结构化分析：

### 3.1.1 功能测试点分析

**分析过程说明**：
- 对于涉及**状态转换**的模块，输出状态迁移图和状态迁移表
- 对于涉及**多条件组合**的模块，输出因果图和判定表
- 对于涉及**队列/并发**的模块，输出队列调度流程图
- 对于涉及**数据计算**的模块，输出计算公式和边界值分析表

---

#### F-01 播放器实例与生命周期管理 (P0)

**功能描述**: 创建并持有播放器实例，按 playerId 多实例管理；释放时回收资源并从实例 Map 中移除。

**IBO 分析**:
- **Input（输入）**: playerId 字符串（可选，多实例标识）；PlayerType（Single/List/LiveShift）
- **Behavior（行为）**: 创建播放器实例并注册到 instanceMap；按 playerId 分发事件；释放时回收资源并移除实例
- **Output（输出）**: 播放器实例对象；EventChannel 广播事件 Map；资源释放结果

**分析过程**：

**状态迁移分析**（适用于状态转换类模块）：

```
状态迁移图：

       [create()]            [release()]
[idle] ─────────→ [created] ─────────→ [released]
                       │                    │
                       │ [create dup id]    │ [release dup]
                       ↓                    ↓
                  [error/log]         [no-op/graceful]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| idle | create(playerId) | created | 创建实例并加入 Map |
| created | release() | released | 释放资源并移除实例 |
| released | release() | released | 静默处理，不崩溃 |
| created | create(同 playerId) | created | 替换或返回已存在实例 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效 playerId 与空 playerId 的创建行为；采用边界值分析测试：验证超长 playerId 的容错
- **行为验证**：采用状态迁移测试：验证 idle→created→released 的状态迁移正确性；采用并发测试：验证多实例并行操作互不干扰
- **输出验证**：采用状态验证测试：验证实例创建后可被其他 API 引用；采用资源验证测试：验证释放后资源被回收

**测试方法选择**: 输入为字符串类型，适用**等价类划分**（playerId 有效/空/重复）；行为涉及状态转换，适用**状态迁移测试**
**适用测试方法**: 等价类划分、状态迁移测试、异常处理测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-01-01 | 播放器实例与生命周期管理 | 验证创建单个播放器实例能成功初始化 | 实例对象不为空且可正常使用 | createAliPlayer | L0 |
| F-01-02 | 播放器实例与生命周期管理 | 验证通过自定义 playerId 创建播放器实例 | 不同 playerId 对应独立实例且可区分 | createAliPlayer | L0 |
| F-01-03 | 播放器实例与生命周期管理 | 验证释放播放器实例后资源被回收 | 释放后实例不可再用且无残留资源 | release | L0 |
| F-01-04 | 播放器实例与生命周期管理 | 验证重复释放同一播放器实例不会导致应用崩溃 | 重复释放返回静默成功且应用继续运行 | release | L1 |

---

#### F-02 视频源设置 (P0)

**功能描述**: 设置 URL 或 Vid 类播放源；URL 方式直接可播；vid 方式需鉴权解析后获得可播放地址；支持流切换。

**IBO 分析**:
- **Input（输入）**: URL 字符串（http/https/HLS/fd://）；vid+sts/auth/mps/liveSts 凭证；switchStream 目标 URL
- **Behavior（行为）**: 将数据源交给播放器内核；URL 直接可播；vid 需应用层解析为 URL 后再交给 AVPlayer；switchStream 切换 MediaSource
- **Output（输出）**: 播放器状态变化（idle→initialized）；播放开始或错误事件

**分析过程**：

**判定表**（适用于多条件组合模块）：

| 条件/规则 | 规则 1 | 规则 2 | 规则 3 | 规则 4 |
|----------|-------|-------|-------|-------|
| URL 有效 | Y | Y | N | N |
| 网络可用 | Y | N | Y | N |
| **动作** | 正常播放 | 加载失败/重试 | 解析失败/错误 | 错误事件 |

> 注：Y=满足，N=不满足

**边界值分析**（适用于 URL 长度边界）：

| 测试场景 | 输入值 | 预期输出 | 边界类型 |
|---------|--------|---------|---------|
| 空字符串 | "" | 错误事件 | 下边界 |
| 正常 URL | ~100 字符 | 正常播放 | 中间值 |
| 超长 URL | >4096 字符 | 错误或截断处理 | 越界 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证 http/https/HLS 三类 URL 的播放行为；采用边界值分析测试：验证空字符串与超长 URL 的容错
- **行为验证**：采用状态迁移测试：验证 setUrl 后状态从 idle 迁移到 initialized；采用判定表测试：验证 URL 有效性与网络可用性的组合行为
- **输出验证**：采用事件验证测试：验证错误事件能正确触发；采用状态验证测试：验证播放状态正确迁移

**测试方法选择**: 输入为 URL 字符串，适用**等价类划分**（http/https/HLS）；行为涉及状态转换，适用**状态迁移测试**
**适用测试方法**: 等价类划分、状态迁移测试、异常处理测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-02-01 | 视频源设置 | 验证设置 HTTP URL 播放源能正常起播 | 播放器进入 prepared 状态并开始播放 | setUrl | L0 |
| F-02-02 | 视频源设置 | 验证设置 HTTPS URL 播放源能正常起播 | 播放器进入 prepared 状态并开始播放 | setUrl | L0 |
| F-02-03 | 视频源设置 | 验证切换播放流地址能平滑切换到新流 | 切换后播放新流内容且无中断崩溃 | switchStream | L0 |
| F-02-04 | 视频源设置 | 验证设置无效 URL 能触发错误事件并保持稳定 | 错误事件回调被触发且播放器不崩溃 | setUrl | L1 |

---

#### F-03 播放控制 (P0)

**功能描述**: prepare/play/pause/stop/seek/setStartTime/reload/clearScreen 等播控操作；驱动 AVPlayer 状态机迁移。

**IBO 分析**:
- **Input（输入）**: seek 位置（ms）+ SeekMode（Accurate/Inaccurate）；setStartTime 起播位置；reload 触发信号
- **Behavior（行为）**: 驱动 AVPlayer 状态机迁移（idle→initialized→prepared→playing→paused→completed→stopped→released）；seek 跳转；reload 重连
- **Output（输出）**: 状态变化事件；currentTime/duration 更新；seek 完成回调

**分析过程**：

**状态迁移分析**（适用于状态转换类模块）：

```
状态迁移图：

[idle] → [initialized] → [prepared] → [playing] ↔ [paused]
                                              ↓
                                         [completed]
                                              ↓
                                          [stopped]
                                              ↓
                                          [released]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| idle | setUrl + prepare | prepared | 触发 onPrepared |
| prepared | play() | playing | 触发 onRenderingStart |
| playing | pause() | paused | 暂停解码 |
| playing/paused | stop() | stopped | 停止播放 |
| playing | 自然结束 | completed | 触发 onCompletion |
| 任意 | release() | released | 释放资源 |

**边界值分析**（适用于 seek 位置边界）：

| 测试场景 | 输入值 | 预期输出 | 边界类型 |
|---------|--------|---------|---------|
| 起始位置 | 0 | 跳转到开头 | 下边界 |
| 正常位置 | duration/2 | 跳转到中间 | 中间值 |
| 结束位置 | duration | 跳转到结尾或触发完成 | 上边界 |
| 越界位置 | duration+10000 | 触发完成或错误 | 越界 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证 Accurate/Inaccurate 两种 seekMode；采用边界值分析测试：验证 0、duration/2、duration、越界位置
- **行为验证**：采用状态迁移测试：验证完整状态机迁移路径；采用并发测试：验证快速连续 seek 的容错
- **输出验证**：采用事件验证测试：验证 onPrepared/onSeekComplete/onCompletion 回调触发；采用状态验证测试：验证 currentTime 正确更新

**测试方法选择**: 输入为位置数值 + 枚举，适用**等价类划分 + 边界值分析**；行为涉及状态机，适用**状态迁移测试**
**适用测试方法**: 等价类划分、边界值分析、状态迁移测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-03-01 | 播放控制 | 验证准备播放器能进入可播放状态 | onPrepared 事件触发且状态为 prepared | prepare | L0 |
| F-03-02 | 播放控制 | 验证开始播放能渲染视频画面 | onRenderingStart 事件触发且画面显示 | play | L0 |
| F-03-03 | 播放控制 | 验证暂停播放能停止画面更新但保留当前帧 | 暂停后画面定格且 currentTime 不再增长 | pause | L0 |
| F-03-04 | 播放控制 | 验证停止播放能回到待播状态 | 停止后状态为 stopped 且可重新 prepare | stop | L0 |
| F-03-05 | 播放控制 | 验证精准跳转到指定位置能定位到目标时间 | 跳转后 currentTime 接近目标值且 onSeekComplete 触发 | seekTo(Accurate) | L0 |
| F-03-06 | 播放控制 | 验证跳转到越界位置能容错处理不崩溃 | 越界跳转后不崩溃且回调正常触发 | seekTo | L1 |
| F-03-07 | 播放控制 | 验证重新加载网络流能恢复播放 | reload 后能重新起播并播放当前流 | reload | L1 |

---

#### F-04 视频渲染面 (P0)

**功能描述**: AliPlayerView 作为 PlatformView 嵌入 Flutter 视图树；setPlayerView 将渲染面与播放器绑定；鸿蒙侧用 XComponent 实现。

**IBO 分析**:
- **Input（输入）**: 坐标 x/y/width/height；viewType（surfaceview/textureview/displayview）；viewId
- **Behavior（行为）**: 创建 PlatformView 并产出 viewId；onSurfaceCreated 时获取 surfaceId 交给 AVPlayer；onSurfaceChanged/Destroyed 处理尺寸变化与释放
- **Output（输出）**: 视频画面在 Flutter 视图树中显示；surfaceId 传递给 AVPlayer；画面尺寸自适应

**分析过程**：

**状态迁移分析**（适用于渲染面生命周期）：

```
状态迁移图：

[created] → [surfaceCreated] → [surfaceChanged]* → [surfaceDestroyed] → [released]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| created | XComponent 加载完成 | surfaceCreated | 获取 surfaceId 并赋给 AVPlayer |
| surfaceCreated | 尺寸变化 | surfaceChanged | 更新渲染区域 |
| surfaceChanged | 视图销毁 | surfaceDestroyed | 置空 surfaceId |
| surfaceDestroyed | 重新加载 | surfaceCreated | 重新获取 surfaceId |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证三种 viewType 的渲染行为；采用边界值分析测试：验证零尺寸与超大尺寸的容错
- **行为验证**：采用状态迁移测试：验证 surface 生命周期的正确迁移；采用 UI 测试：验证画面在 Flutter 视图树中正确显示
- **输出验证**：采用视觉验证测试：验证视频画面可见且内容正确；采用尺寸验证测试：验证画面尺寸自适应

**测试方法选择**: 输入为坐标与枚举，适用**等价类划分**；行为涉及视图生命周期，适用**状态迁移测试**
**适用测试方法**: 等价类划分、状态迁移测试、UI 自动化

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-04-01 | 视频渲染面 | 验证嵌入视频渲染面到界面能显示视频画面 | 渲染面在界面正确显示且播放画面可见 | AliPlayerView | L0 |
| F-04-02 | 视频渲染面 | 验证绑定渲染面与播放器能将画面渲染到指定区域 | 播放器输出画面到指定渲染面且位置正确 | setPlayerView | L0 |
| F-04-03 | 视频渲染面 | 验证切换渲染面类型能正常显示画面 | 三种 viewType 切换后画面均能正常显示 | aliPlayerViewType | L0 |
| F-04-04 | 视频渲染面 | 验证全屏切换时渲染面能正确重建 | 切换全屏/窗口后画面不丢失且无黑屏 | AliPlayerView | L1 |

---

#### F-05 播放配置 AVPConfig (P1)

**功能描述**: 配置缓冲水位、网络超时/重试、HTTP 头、userAgent、referer 等播放参数。

**IBO 分析**:
- **Input（输入）**: 缓冲水位数值（startBuffer/highBuffer/maxBuffer）；网络超时/重试次数；httpHeaders/userAgent/httpProxy；positionTimerIntervalMs
- **Behavior（行为）: AVPlayer 应用配置参数；鸿蒙侧无对等 API 的字段静默忽略并日志提示
- **Output（输出）**: 起播速度变化；卡顿恢复行为；网络容错行为

**分析过程**：

**边界值分析**（适用于缓冲水位边界）：

| 测试场景 | 输入值 | 预期输出 | 边界类型 |
|---------|--------|---------|---------|
| 最小缓冲 | 0 | 默认行为或错误 | 下边界 |
| 正常缓冲 | 1000ms | 正常起播 | 中间值 |
| 最大缓冲 | 60000ms | 大缓冲慢起播 | 上边界 |
| 越界缓冲 | -1 或非数字 | 静默忽略或默认 | 越界 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效配置项与无效配置项；采用边界值分析测试：验证缓冲水位的边界值
- **行为验证**：采用配置生效测试：验证 HTTP 头与 userAgent 在网络请求中生效；采用静默忽略测试：验证不支持的字段不导致崩溃
- **输出验证**：采用行为验证测试：验证起播速度与卡顿恢复行为符合配置

**测试方法选择**: 输入为数值与键值对，适用**等价类划分 + 边界值分析**
**适用测试方法**: 等价类划分、边界值分析、异常处理测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-05-01 | 播放配置 AVPConfig | 验证配置缓冲水位能影响起播与卡顿恢复行为 | 起播与卡顿恢复行为符合配置的缓冲水位 | setConfig | L0 |
| F-05-02 | 播放配置 AVPConfig | 验证配置 HTTP 头信息能在网络请求中生效 | 网络请求包含配置的 HTTP 头 | setConfig | L0 |
| F-05-03 | 播放配置 AVPConfig | 验证配置无效缓冲值能容错处理不崩溃 | 无效值被静默忽略或使用默认值且不崩溃 | setConfig | L2 |

---

#### F-06 轨道管理 (P1)

**功能描述**: 查询/切换音视频/字幕轨；设置默认码率/清晰度/音频语言。

**IBO 分析**:
- **Input（输入）**: TrackType（video/audio/subtitle/vod）；trackIndex；默认码率/清晰度/音频语言
- **Behavior（行为）: getTrackDescription 返回轨道列表；selectTrack 切换活跃轨道；setDefault* 在 prepare 前预设默认值
- **Output（输出）**: OnTrackReady/OnTrackChanged 回调；播放轨切换

**分析过程**：

**判定表**（适用于多条件组合模块）：

| 条件/规则 | 规则 1 | 规则 2 | 规则 3 | 规则 4 |
|----------|-------|-------|-------|-------|
| trackIndex 有效 | Y | Y | N | - |
| 轨道类型匹配 | Y | N | - | - |
| 处于 prepared 后 | Y | - | Y | N |
| **动作** | 切换成功 | 类型不匹配报错 | 不存在轨道报错 | 状态错误报错 |

> 注：Y=满足，N=不满足，-=不相关

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证 video/audio/subtitle 三种 TrackType；采用异常处理测试：验证不存在的 trackIndex 的容错
- **行为验证**：采用状态迁移测试：验证 selectTrack 后轨道切换的回调触发；采用默认值测试：验证 setDefault* 在 prepare 前预设的生效
- **输出验证**：采用回调验证测试：验证 OnTrackReady/OnTrackChanged 回调字段正确；采用播放验证测试：验证切换后播放内容对应

**测试方法选择**: 输入为枚举与索引，适用**等价类划分 + 异常处理测试**
**适用测试方法**: 等价类划分、异常处理测试、状态迁移测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-06-01 | 轨道管理 | 验证查询媒体轨道信息能返回轨道列表 | 返回的轨道列表包含 video/audio/subtitle 类型 | getMediaInfo | L0 |
| F-06-02 | 轨道管理 | 验证切换视频轨道能改变清晰度 | 切换后播放画面清晰度变化且 OnTrackChanged 触发 | selectTrack | L0 |
| F-06-03 | 轨道管理 | 验证切换音频轨道能改变音轨语言 | 切换后播放音轨对应所选轨道 | selectTrack | L0 |
| F-06-04 | 轨道管理 | 验证切换不存在的轨道能容错处理不崩溃 | 不存在轨道被拒绝或忽略且不崩溃 | selectTrack | L2 |

---

#### F-07 字幕 (P1)

**功能描述**: 添加外挂字幕 URL；选择/关闭外挂字幕；字幕显示/隐藏/头信息回调。

**IBO 分析**:
- **Input（输入）**: 外挂字幕 URL；trackIndex；enable 开关
- **Behavior（行为）: 加载外挂字幕文件；启用/禁用字幕轨；触发字幕显示/隐藏回调
- **Output（输出）**: 字幕轨添加/启用；OnSubtitleShow/Hide/ExtAdded 回调

**分析过程**：

**状态迁移分析**（适用于字幕轨生命周期）：

```
状态迁移图：

[未添加] → [已添加] → [已启用] ↔ [已禁用]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| 未添加 | addExtSubtitle(url) | 已添加 | 触发 OnSubtitleExtAdded |
| 已添加 | selectExtSubtitle(idx, true) | 已启用 | 触发 OnSubtitleShow |
| 已启用 | selectExtSubtitle(idx, false) | 已禁用 | 触发 OnSubtitleHide |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效字幕 URL 与无效 URL；采用异常处理测试：验证无效 trackIndex 的容错
- **行为验证**：采用状态迁移测试：验证字幕轨添加→启用→禁用的迁移；采用回调验证测试：验证各字幕回调触发
- **输出验证**：采用视觉验证测试：验证字幕显示/隐藏的可观察变化；采用回调验证测试：验证回调字段正确

**测试方法选择**: 输入为 URL 与开关，适用**等价类划分 + 状态迁移测试**
**适用测试方法**: 等价类划分、状态迁移测试、异常处理测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-07-01 | 字幕 | 验证添加外挂字幕能加载字幕文件 | OnSubtitleExtAdded 回调触发且字幕轨可用 | addExtSubtitle | L0 |
| F-07-02 | 字幕 | 验证启用外挂字幕能在画面显示字幕内容 | OnSubtitleShow 回调触发且画面显示字幕 | selectExtSubtitle | L0 |
| F-07-03 | 字幕 | 验证添加无效字幕地址能容错处理不崩溃 | 无效地址返回错误或静默忽略且不崩溃 | addExtSubtitle | L2 |

---

#### F-08 截图与缩略图 (P1)

**功能描述**: 截取当前帧保存为图片；从远端缩略图获取指定位置位图；鸿蒙侧改用 AVImageGenerator 提取帧。

**IBO 分析**:
- **Input（输入）**: 截图保存路径；缩略图 URL；位置（ms）
- **Behavior（行为）: 截取当前播放帧并写入文件；从远端下载缩略图或本地提取指定位置帧
- **Output（输出）**: OnSnapShot(path) 回调；OnThumbnailGetSuccess(bitmap,range) 回调

**分析过程**：

**边界值分析**（适用于位置边界）：

| 测试场景 | 输入值 | 预期输出 | 边界类型 |
|---------|--------|---------|---------|
| 起始位置 | 0 | 返回首帧 | 下边界 |
| 正常位置 | duration/2 | 返回中间帧 | 中间值 |
| 结束位置 | duration | 返回末帧 | 上边界 |
| 越界位置 | duration+1000 | 错误或末帧 | 越界 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效路径与无效路径；采用边界值分析测试：验证位置的边界值
- **行为验证**：采用文件验证测试：验证截图文件正确生成；采用回调验证测试：验证 OnSnapShot/OnThumbnailGet 回调触发
- **输出验证**：采用文件验证测试：验证截图文件可被其他应用读取；采用位图验证测试：验证返回位图格式正确

**测试方法选择**: 输入为路径与位置数值，适用**等价类划分 + 边界值分析**
**适用测试方法**: 等价类划分、边界值分析、异常处理测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-08-01 | 截图与缩略图 | 验证截取当前播放帧能生成图片文件 | OnSnapShot 回调触发且文件可被读取 | snapshot | L0 |
| F-08-02 | 截图与缩略图 | 验证保存截图到指定路径能正确写入 | 截图文件存在于指定路径且内容非空 | snapshot | L0 |
| F-08-03 | 截图与缩略图 | 验证截图到无效路径能容错处理不崩溃 | 无效路径返回错误或静默忽略且不崩溃 | snapshot | L2 |

---

#### F-09 渲染模式 (P0)

**功能描述**: 设置缩放/旋转/镜像/背景色等渲染参数；缩放可映射到 AVPlayer videoScaleType；旋转/镜像需在 ArkUI transform 层模拟。

**IBO 分析**:
- **Input（输入）: ScaleMode（ToFill/AspectFit/AspectFill）；RotateMode（0/90/180/270）；MirrorMode（None/H/V）；背景色数值
- **Behavior（行为）: 缩放模式映射到 videoScaleType；旋转/镜像通过 ArkUI transform 应用；背景色填充渲染区域
- **Output（输出）**: 画面比例/旋转/镜像/背景色变化

**分析过程**：

**判定表**（适用于多条件组合，以缩放模式为例）：

| 条件/规则 | 规则 1 | 规则 2 | 规则 3 |
|----------|-------|-------|-------|
| ScaleMode | ToFill | AspectFit | AspectFill |
| **动作** | 拉伸填满 | 等比留边 | 等比裁剪 |

---

**测试分析**:
- **输入验证**：采用枚举全覆盖测试：验证 ScaleMode 三值、RotateMode 四值、MirrorMode 三值；采用边界值分析测试：验证背景色极值
- **行为验证**：采用视觉验证测试：验证各模式画面变化；采用组合测试：验证缩放+旋转+镜像的组合
- **输出验证**：采用视觉验证测试：验证画面比例/旋转/镜像符合设置

**测试方法选择**: 输入为枚举类型，适用**枚举全覆盖**
**适用测试方法**: 枚举全覆盖、视觉验证、组合测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-09-01 | 渲染模式 | 验证设置等比缩放模式能保持画面比例不变形 | 画面等比缩放且无拉伸变形 | setScalingMode(AspectFit) | L0 |
| F-09-02 | 渲染模式 | 验证设置全屏缩放模式能填满渲染区域 | 画面填满渲染区域可能裁剪 | setScalingMode(ToFill) | L0 |
| F-09-03 | 渲染模式 | 验证设置 90 度旋转能使画面旋转 | 画面按 90 度旋转显示 | setRotateMode | L0 |
| F-09-04 | 渲染模式 | 验证设置水平镜像能使画面水平翻转 | 画面水平翻转显示 | setMirrorMode(H) | L0 |
| F-09-05 | 渲染模式 | 验证设置视频背景色能改变渲染区域底色 | 渲染区域底色为设置的背景色 | setVideoBackgroundColor | L1 |

---

#### F-10 音量/倍速/静音/循环/快启 (P0)

**功能描述**: volume/speed/muted/loop/autoPlay 等播放属性；映射到 AVPlayer 对应属性。

**IBO 分析**:
- **Input（输入）: volume（0~2）；speed（0.5~2.0）；muted/loop/autoPlay 布尔开关
- **Behavior（行为）: AVPlayer 应用音量/倍速/静音/循环属性；autoPlay 在 prepared 后自动 play
- **Output（输出）**: 音量/倍速/静音/循环行为变化

**分析过程**：

**边界值分析**（适用于音量边界）：

| 测试场景 | 输入值 | 预期输出 | 边界类型 |
|---------|--------|---------|---------|
| 静音 | 0 | 无声音 | 下边界 |
| 正常 | 0.5 | 正常音量 | 中间值 |
| AVPlayer 上限 | 1 | 最大音量 | 上边界 |
| Aliyun 上限 | 2 | clamp 到 1 或保留差异 | 越界 |

---

**测试分析**:
- **输入验证**：采用边界值分析测试：验证音量 0/0.5/1/2 与倍速 0.5/1.0/2.0；采用异常处理测试：验证越界值的容错
- **行为验证**：采用属性生效测试：验证静音/循环/自动播放的开关行为；采用映射验证测试：验证 Aliyun 倍速到 AVPlayer 倍速的映射
- **输出验证**：采用听觉/视觉验证测试：验证音量/倍速/循环的可观察变化

**测试方法选择**: 输入为数值与布尔，适用**边界值分析 + 等价类划分**
**适用测试方法**: 边界值分析、等价类划分、异常处理测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-10-01 | 音量/倍速/静音/循环/快启 | 验证调节音量能改变播放音量大小 | 音量随设置值变化且无爆音 | setVolume | L0 |
| F-10-02 | 音量/倍速/静音/循环/快启 | 验证调节播放倍速能改变播放速度 | 播放速度随设置值变化且画面/音频同步 | setSpeed | L0 |
| F-10-03 | 音量/倍速/静音/循环/快启 | 验证静音播放能关闭声音输出 | 静音后无声音输出且画面正常 | setMuted | L0 |
| F-10-04 | 音量/倍速/静音/循环/快启 | 验证开启循环播放能在结束后自动重播 | 播放结束后自动从头开始播放 | setLoop | L0 |
| F-10-05 | 音量/倍速/静音/循环/快启 | 验证设置音量为越界值能容错处理不崩溃 | 越界值被 clamp 或静默忽略且不崩溃 | setVolume | L1 |

---

#### F-11 事件回调 (P0)

**功能描述**: 播放器各类事件透传至 Dart；EventChannel 广播 Map 后按 playerId 分发。

**IBO 分析**:
- **Input（输入）**: 注册回调函数；AVPlayer 内部事件（stateChange/error/videoSizeChanged 等）
- **Behavior（行为）: 原生侧监听 AVPlayer 事件并广播 Map；Dart 侧按 method 分发到对应回调
- **Output（输出）**: Dart 侧回调触发；回调字段与方法名一致

**分析过程**：

**状态迁移分析**（适用于事件触发时序）：

```
状态迁移图：

[prepared] → [onPrepared] → [playing] → [onRenderingStart]
                                          ↓
                                     [onVideoSizeChanged]
                                          ↓
                                     [onInfo(进度)]
                                          ↓
                                     [onCompletion 或 onError]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| prepared | prepare 完成 | 已准备 | 触发 onPrepared |
| playing | 首帧渲染 | 渲染中 | 触发 onRenderingStart |
| 渲染中 | 视频尺寸变化 | 尺寸更新 | 触发 onVideoSizeChanged |
| 渲染中 | 进度更新 | 进度更新 | 触发 onInfo(currentTime) |
| 播放中 | 发生错误 | 错误态 | 触发 onError |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证各类关键事件的注册；采用异常处理测试：验证未注册回调时不崩溃
- **行为验证**：采用状态迁移测试：验证事件触发时序正确；采用字段一致性测试：验证回调字段与 Dart 侧一致
- **输出验证**：采用回调验证测试：验证各关键事件能正确触发；采用时序验证测试：验证事件触发顺序

**测试方法选择**: 行为涉及事件触发，适用**状态迁移测试 + 事件验证**
**适用测试方法**: 状态迁移测试、事件验证、字段一致性测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-11-01 | 事件回调 | 验证准备完成事件能在 prepare 完成时触发 | onPrepared 回调被触发且字段正确 | setOnPrepared | L0 |
| F-11-02 | 事件回调 | 验证渲染开始事件能在首帧渲染时触发 | onRenderingStart 回调被触发 | setOnRenderingStart | L0 |
| F-11-03 | 事件回调 | 验证播放完成事件能在视频结束时触发 | onCompletion 回调被触发 | setOnCompletion | L0 |
| F-11-04 | 事件回调 | 验证播放错误事件能在播放异常时触发 | onError 回调被触发且错误码字段正确 | setOnError | L0 |
| F-11-05 | 事件回调 | 验证视频尺寸变化事件能在画面尺寸变化时触发 | onVideoSizeChanged 回调被触发且宽高字段正确 | setOnVideoSizeChanged | L0 |
| F-11-06 | 事件回调 | 验证缓冲状态变化事件能在卡顿/恢复时触发 | onLoadingStatusListener 回调被触发且状态字段正确 | setOnLoadingStatusListener | L1 |
| F-11-07 | 事件回调 | 验证跳转完成事件能在 seek 完成时触发 | onSeekComplete 回调被触发 | setOnSeekComplete | L1 |

---

#### F-12 列表播放器 (P1)

**功能描述**: 短视频列表顺序播放与预加载；addVidSource/addUrlSource 增加源；moveToNext/moveToPre/moveTo 切换。

**IBO 分析**:
- **Input（输入）: URL/vid + uid 列表；预加载个数；目标 uid
- **Behavior（行为）: 维护播放列表；moveTo 切换活跃项并预取相邻项
- **Output（输出）**: 列表前进/后退/跳转；预加载触发

**分析过程**：

**队列调度流程**（适用于列表管理模块）：

```
队列调度流程图：

[当前项] → [moveToNext] → [下一项] → [预取下下一项]
[当前项] → [moveToPre] → [上一项] → [预取上一项]
[当前项] → [moveTo(uid)] → [目标项] → [预取相邻项]
```

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证 URL 源与 vid 源的添加；采用异常处理测试：验证不存在的 uid 的 moveTo 容错
- **行为验证**：采用状态迁移测试：验证列表前进/后退/跳转的迁移；采用预加载验证测试：验证预加载触发
- **输出验证**：采用播放验证测试：验证切换后播放内容对应；采用回调验证测试：验证列表相关回调触发

**测试方法选择**: 行为涉及队列调度，适用**队列调度测试 + 等价类划分**
**适用测试方法**: 等价类划分、队列调度测试、异常处理测试

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-12-01 | 列表播放器 | 验证添加 URL 播放源到列表能成功加入列表 | 列表项数增加且 getCurrentUid 返回新项 uid | addUrlSource | L0 |
| F-12-02 | 列表播放器 | 验证切换到下一个播放源能播放下一项内容 | 切换后播放下一项内容且列表指针前移 | moveToNext | L0 |
| F-12-03 | 列表播放器 | 验证切换到上一个播放源能播放上一项内容 | 切换后播放上一项内容且列表指针后移 | moveToPre | L0 |
| F-12-04 | 列表播放器 | 验证跳转到不存在的列表项能容错处理不崩溃 | 不存在项被拒绝或忽略且不崩溃 | moveTo | L2 |

---

#### F-13 直播时移播放器 (P2)

**功能描述**: 直播回看/时移到指定时间；setDataSource(timeLineUrl,url) 设置时移源。

**IBO 分析**:
- **Input（输入）: timelineUrl + 播放 url；目标 liveTime
- **Behavior（行为）: 解析 timeline 获取时间轴；seekToLiveTime 将 liveTime 转为流内 position 再 seek
- **Output（输出）: onTimeShiftUpdater 回调（currentTime/shiftStart/shiftEnd）

**分析过程**：

**状态迁移分析**（适用于时移状态）：

```
状态迁移图：

[直播中] → [时移中] → [回到直播]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| 直播中 | seekToLiveTime | 时移中 | 触发 onTimeShiftUpdater |
| 时移中 | 回到直播 | 直播中 | 切回直播流 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效时移源；采用异常处理测试：验证无效 timelineUrl 的容错
- **行为验证**：采用状态迁移测试：验证直播↔时移的迁移；采用回调验证测试：验证 onTimeShiftUpdater 触发
- **输出验证**：采用时间验证测试：验证时移到目标 liveTime 后 currentTime 接近目标

**测试方法选择**: 行为涉及状态转换，适用**状态迁移测试**
**适用测试方法**: 状态迁移测试、等价类划分

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-13-01 | 直播时移播放器 | 验证设置时移数据源能加载时移流 | 时移流加载成功且可播放 | setDataSource | L0 |
| F-13-02 | 直播时移播放器 | 验证查询当前直播时间能返回现实时间 | 返回的 liveTime 为非零时间值 | getCurrentLiveTime | L0 |

---

#### F-14 视频下载 (P2)

**功能描述**: FlutterAliDownloader 普通明文下载；鸿蒙侧基于 @ohos.net.http 实现。

**IBO 分析**:
- **Input（输入）: vid + 凭证 / URL；trackIndex；保存目录
- **Behavior（行为）: prepare 准备下载项；start 开始分片下载；stop 停止下载
- **Output（输出）: download_prepared/progress/process/completion/error 事件

**分析过程**：

**状态迁移分析**（适用于下载任务生命周期）：

```
状态迁移图：

[未准备] → [已准备] → [下载中] → [已完成]
                         ↓
                      [已停止]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| 未准备 | prepare | 已准备 | 触发 download_prepared |
| 已准备 | start | 下载中 | 触发 download_progress |
| 下载中 | 完成 | 已完成 | 触发 download_completion |
| 下载中 | stop | 已停止 | 停止下载 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效源与无效源；采用异常处理测试：验证无写权限目录的容错
- **行为验证**：采用状态迁移测试：验证下载任务状态迁移；采用进度验证测试：验证进度回调触发
- **输出验证**：采用文件验证测试：验证下载完成的文件可被播放；采用回调验证测试：验证各下载事件触发

**测试方法选择**: 行为涉及状态转换，适用**状态迁移测试**
**适用测试方法**: 状态迁移测试、等价类划分

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-14-01 | 视频下载 | 验证准备下载任务能获取可下载项信息 | download_prepared 事件触发且返回可下载项 | prepare | L0 |
| F-14-02 | 视频下载 | 验证开始下载视频能触发进度回调并最终完成 | download_progress 与 download_completion 事件触发且文件生成 | start | L0 |

---

#### F-15 媒体预加载 (P2)

**功能描述**: MediaLoader v1/v2 播放前预取媒体数据以加速起播。

**IBO 分析**:
- **Input（输入）: URL/vid + duration/bandWidth；PreloadConfig
- **Behavior（行为）: 按 duration 预取字节范围；resume/pause/cancel 控制任务
- **Output（输出）: onCompleted/onCancel/onError/onErrorV2 回调

**分析过程**：

**状态迁移分析**（适用于预加载任务生命周期）：

```
状态迁移图：

[未开始] → [预加载中] → [已完成]
                ↓
            [已暂停] → [已恢复] → [已完成]
                ↓
            [已取消]
```

**状态迁移表**：

| 当前状态 | 触发条件 | 下一状态 | 动作/输出 |
|---------|---------|---------|----------|
| 未开始 | load/addTask | 预加载中 | 开始预取 |
| 预加载中 | pause | 已暂停 | 暂停预取 |
| 已暂停 | resume | 预加载中 | 恢复预取 |
| 预加载中 | cancel | 已取消 | 触发 onCancel |
| 预加载中 | 完成 | 已完成 | 触发 onCompleted |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效 URL/vid 任务；采用异常处理测试：验证无效任务的容错
- **行为验证**：采用状态迁移测试：验证预加载任务状态迁移；采用回调验证测试：验证各回调触发
- **输出验证**：采用起播验证测试：验证预加载完成后起播速度提升；采用回调验证测试：验证回调字段正确

**测试方法选择**: 行为涉及状态转换，适用**状态迁移测试**
**适用测试方法**: 状态迁移测试、等价类划分

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-15-01 | 媒体预加载 | 验证添加预加载任务能开始预取媒体数据 | 任务进入预加载中状态且回调触发 | load/addTask | L0 |
| F-15-02 | 媒体预加载 | 验证取消预加载任务能停止预取并触发回调 | onCancel 回调触发且任务终止 | cancel/cancelTask | L0 |

---

#### F-16 全局设置 (P2)

**功能描述**: FlutterAliPlayerGlobalSettings 全局网络/DNS/亮度策略。

**IBO 分析**:
- **Input（输入）: GlobalEnv 枚举；选项键值；亮度数值
- **Behavior（行为）: 全局配置生效；setSystemBrightness 调节屏幕亮度
- **Output（输出）**: 全局状态更新；亮度变化

**分析过程**：

**边界值分析**（适用于亮度边界）：

| 测试场景 | 输入值 | 预期输出 | 边界类型 |
|---------|--------|---------|---------|
| 最暗 | 0 | 屏幕最暗 | 下边界 |
| 中等 | 128 | 屏幕中等亮度 | 中间值 |
| 最亮 | 255 | 屏幕最亮 | 上边界 |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证有效 GlobalEnv 与选项；采用边界值分析测试：验证亮度边界值
- **行为验证**：采用配置生效测试：验证全局配置生效；采用视觉验证测试：验证亮度变化
- **输出验证**：采用状态验证测试：验证全局状态更新；采用视觉验证测试：验证屏幕亮度变化

**测试方法选择**: 输入为枚举与数值，适用**等价类划分 + 边界值分析**
**适用测试方法**: 等价类划分、边界值分析

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-16-01 | 全局设置 | 验证设置系统亮度能改变屏幕亮度 | 屏幕亮度随设置值变化 | setSystemBrightness | L0 |
| F-16-02 | 全局设置 | 验证查询系统亮度能返回当前亮度值 | 返回的亮度值与实际屏幕亮度一致 | getSystemBrightness | L0 |

---

#### F-17 全局播放器设置 (P2)

**功能描述**: FlutterAliplayer 静态方法：getSDKVersion/enableConsoleLog/setLogLevel/clearCaches 等。

**IBO 分析**:
- **Input（输入）: 日志级别枚举；无参数查询
- **Behavior（行为）: getSDKVersion 返回适配层版本；enableConsoleLog 开关控制台日志；clearCaches 清理缓存
- **Output（输出）**: 版本字符串；日志输出；缓存清理结果

**分析过程**：

**判定表**（适用于日志级别组合）：

| 条件/规则 | 规则 1 | 规则 2 | 规则 3 |
|----------|-------|-------|-------|
| 日志级别 | Debug | Info | Error |
| **动作** | 输出所有日志 | 输出 Info+ | 仅输出 Error |

---

**测试分析**:
- **输入验证**：采用等价类划分测试：验证各日志级别；采用返回值验证测试：验证版本字符串格式
- **行为验证**：采用配置生效测试：验证日志开关与级别生效；采用状态验证测试：验证缓存清理结果
- **输出验证**：采用返回值验证测试：验证 getSDKVersion 返回非空字符串；采用日志验证测试：验证日志输出符合级别

**测试方法选择**: 输入为枚举与查询，适用**等价类划分**
**适用测试方法**: 等价类划分、返回值验证

**测试点**:

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-17-01 | 全局播放器设置 | 验证查询 SDK 版本号能返回非空版本字符串 | 返回的版本字符串非空且格式合理 | getSDKVersion | L0 |
| F-17-02 | 全局播放器设置 | 验证开启控制台日志能在控制台看到播放器日志 | 控制台输出播放器相关日志 | enableConsoleLog | L0 |

---

### 3.1.2 测试点汇总

| 功能模块 | 优先级 | 测试点数量 | 覆盖的主要 API |
|----------|--------|------------|----------------|
| 播放器实例与生命周期管理 | P0 | 4 | createAliPlayer, release |
| 视频源设置 | P0 | 4 | setUrl, switchStream |
| 播放控制 | P0 | 7 | prepare, play, pause, stop, seekTo, reload |
| 视频渲染面 | P0 | 4 | AliPlayerView, setPlayerView, aliPlayerViewType |
| 播放配置 AVPConfig | P1 | 3 | setConfig |
| 轨道管理 | P1 | 4 | getMediaInfo, selectTrack |
| 字幕 | P1 | 3 | addExtSubtitle, selectExtSubtitle |
| 截图与缩略图 | P1 | 3 | snapshot |
| 渲染模式 | P0 | 5 | setScalingMode, setRotateMode, setMirrorMode, setVideoBackgroundColor |
| 音量/倍速/静音/循环/快启 | P0 | 5 | setVolume, setSpeed, setMuted, setLoop |
| 事件回调 | P0 | 7 | setOnPrepared, setOnRenderingStart, setOnCompletion, setOnError, setOnVideoSizeChanged, setOnLoadingStatusListener, setOnSeekComplete |
| 列表播放器 | P1 | 4 | addUrlSource, moveToNext, moveToPre, moveTo |
| 直播时移播放器 | P2 | 2 | setDataSource, getCurrentLiveTime |
| 视频下载 | P2 | 2 | prepare, start |
| 媒体预加载 | P2 | 2 | load/addTask, cancel/cancelTask |
| 全局设置 | P2 | 2 | setSystemBrightness, getSystemBrightness |
| 全局播放器设置 | P2 | 2 | getSDKVersion, enableConsoleLog |
| **合计** | - | **63** | - |

### 3.1.3 测试点详细列表

> 以下测试点按功能模块分类罗列，采用统一表格格式，便于后续测试用例设计参考。

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-01-01 | 播放器实例与生命周期管理 | 验证创建单个播放器实例能成功初始化 | 实例对象不为空且可正常使用 | createAliPlayer | L0 |
| F-01-02 | 播放器实例与生命周期管理 | 验证通过自定义 playerId 创建播放器实例 | 不同 playerId 对应独立实例且可区分 | createAliPlayer | L0 |
| F-01-03 | 播放器实例与生命周期管理 | 验证释放播放器实例后资源被回收 | 释放后实例不可再用且无残留资源 | release | L0 |
| F-01-04 | 播放器实例与生命周期管理 | 验证重复释放同一播放器实例不会导致应用崩溃 | 重复释放返回静默成功且应用继续运行 | release | L1 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-02-01 | 视频源设置 | 验证设置 HTTP URL 播放源能正常起播 | 播放器进入 prepared 状态并开始播放 | setUrl | L0 |
| F-02-02 | 视频源设置 | 验证设置 HTTPS URL 播放源能正常起播 | 播放器进入 prepared 状态并开始播放 | setUrl | L0 |
| F-02-03 | 视频源设置 | 验证切换播放流地址能平滑切换到新流 | 切换后播放新流内容且无中断崩溃 | switchStream | L0 |
| F-02-04 | 视频源设置 | 验证设置无效 URL 能触发错误事件并保持稳定 | 错误事件回调被触发且播放器不崩溃 | setUrl | L1 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-03-01 | 播放控制 | 验证准备播放器能进入可播放状态 | onPrepared 事件触发且状态为 prepared | prepare | L0 |
| F-03-02 | 播放控制 | 验证开始播放能渲染视频画面 | onRenderingStart 事件触发且画面显示 | play | L0 |
| F-03-03 | 播放控制 | 验证暂停播放能停止画面更新但保留当前帧 | 暂停后画面定格且 currentTime 不再增长 | pause | L0 |
| F-03-04 | 播放控制 | 验证停止播放能回到待播状态 | 停止后状态为 stopped 且可重新 prepare | stop | L0 |
| F-03-05 | 播放控制 | 验证精准跳转到指定位置能定位到目标时间 | 跳转后 currentTime 接近目标值且 onSeekComplete 触发 | seekTo(Accurate) | L0 |
| F-03-06 | 播放控制 | 验证跳转到越界位置能容错处理不崩溃 | 越界跳转后不崩溃且回调正常触发 | seekTo | L1 |
| F-03-07 | 播放控制 | 验证重新加载网络流能恢复播放 | reload 后能重新起播并播放当前流 | reload | L1 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-04-01 | 视频渲染面 | 验证嵌入视频渲染面到界面能显示视频画面 | 渲染面在界面正确显示且播放画面可见 | AliPlayerView | L0 |
| F-04-02 | 视频渲染面 | 验证绑定渲染面与播放器能将画面渲染到指定区域 | 播放器输出画面到指定渲染面且位置正确 | setPlayerView | L0 |
| F-04-03 | 视频渲染面 | 验证切换渲染面类型能正常显示画面 | 三种 viewType 切换后画面均能正常显示 | aliPlayerViewType | L0 |
| F-04-04 | 视频渲染面 | 验证全屏切换时渲染面能正确重建 | 切换全屏/窗口后画面不丢失且无黑屏 | AliPlayerView | L1 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-05-01 | 播放配置 AVPConfig | 验证配置缓冲水位能影响起播与卡顿恢复行为 | 起播与卡顿恢复行为符合配置的缓冲水位 | setConfig | L0 |
| F-05-02 | 播放配置 AVPConfig | 验证配置 HTTP 头信息能在网络请求中生效 | 网络请求包含配置的 HTTP 头 | setConfig | L0 |
| F-05-03 | 播放配置 AVPConfig | 验证配置无效缓冲值能容错处理不崩溃 | 无效值被静默忽略或使用默认值且不崩溃 | setConfig | L2 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-06-01 | 轨道管理 | 验证查询媒体轨道信息能返回轨道列表 | 返回的轨道列表包含 video/audio/subtitle 类型 | getMediaInfo | L0 |
| F-06-02 | 轨道管理 | 验证切换视频轨道能改变清晰度 | 切换后播放画面清晰度变化且 OnTrackChanged 触发 | selectTrack | L0 |
| F-06-03 | 轨道管理 | 验证切换音频轨道能改变音轨语言 | 切换后播放音轨对应所选轨道 | selectTrack | L0 |
| F-06-04 | 轨道管理 | 验证切换不存在的轨道能容错处理不崩溃 | 不存在轨道被拒绝或忽略且不崩溃 | selectTrack | L2 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-07-01 | 字幕 | 验证添加外挂字幕能加载字幕文件 | OnSubtitleExtAdded 回调触发且字幕轨可用 | addExtSubtitle | L0 |
| F-07-02 | 字幕 | 验证启用外挂字幕能在画面显示字幕内容 | OnSubtitleShow 回调触发且画面显示字幕 | selectExtSubtitle | L0 |
| F-07-03 | 字幕 | 验证添加无效字幕地址能容错处理不崩溃 | 无效地址返回错误或静默忽略且不崩溃 | addExtSubtitle | L2 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-08-01 | 截图与缩略图 | 验证截取当前播放帧能生成图片文件 | OnSnapShot 回调触发且文件可被读取 | snapshot | L0 |
| F-08-02 | 截图与缩略图 | 验证保存截图到指定路径能正确写入 | 截图文件存在于指定路径且内容非空 | snapshot | L0 |
| F-08-03 | 截图与缩略图 | 验证截图到无效路径能容错处理不崩溃 | 无效路径返回错误或静默忽略且不崩溃 | snapshot | L2 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-09-01 | 渲染模式 | 验证设置等比缩放模式能保持画面比例不变形 | 画面等比缩放且无拉伸变形 | setScalingMode(AspectFit) | L0 |
| F-09-02 | 渲染模式 | 验证设置全屏缩放模式能填满渲染区域 | 画面填满渲染区域可能裁剪 | setScalingMode(ToFill) | L0 |
| F-09-03 | 渲染模式 | 验证设置 90 度旋转能使画面旋转 | 画面按 90 度旋转显示 | setRotateMode | L0 |
| F-09-04 | 渲染模式 | 验证设置水平镜像能使画面水平翻转 | 画面水平翻转显示 | setMirrorMode(H) | L0 |
| F-09-05 | 渲染模式 | 验证设置视频背景色能改变渲染区域底色 | 渲染区域底色为设置的背景色 | setVideoBackgroundColor | L1 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-10-01 | 音量/倍速/静音/循环/快启 | 验证调节音量能改变播放音量大小 | 音量随设置值变化且无爆音 | setVolume | L0 |
| F-10-02 | 音量/倍速/静音/循环/快启 | 验证调节播放倍速能改变播放速度 | 播放速度随设置值变化且画面/音频同步 | setSpeed | L0 |
| F-10-03 | 音量/倍速/静音/循环/快启 | 验证静音播放能关闭声音输出 | 静音后无声音输出且画面正常 | setMuted | L0 |
| F-10-04 | 音量/倍速/静音/循环/快启 | 验证开启循环播放能在结束后自动重播 | 播放结束后自动从头开始播放 | setLoop | L0 |
| F-10-05 | 音量/倍速/静音/循环/快启 | 验证设置音量为越界值能容错处理不崩溃 | 越界值被 clamp 或静默忽略且不崩溃 | setVolume | L1 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-11-01 | 事件回调 | 验证准备完成事件能在 prepare 完成时触发 | onPrepared 回调被触发且字段正确 | setOnPrepared | L0 |
| F-11-02 | 事件回调 | 验证渲染开始事件能在首帧渲染时触发 | onRenderingStart 回调被触发 | setOnRenderingStart | L0 |
| F-11-03 | 事件回调 | 验证播放完成事件能在视频结束时触发 | onCompletion 回调被触发 | setOnCompletion | L0 |
| F-11-04 | 事件回调 | 验证播放错误事件能在播放异常时触发 | onError 回调被触发且错误码字段正确 | setOnError | L0 |
| F-11-05 | 事件回调 | 验证视频尺寸变化事件能在画面尺寸变化时触发 | onVideoSizeChanged 回调被触发且宽高字段正确 | setOnVideoSizeChanged | L0 |
| F-11-06 | 事件回调 | 验证缓冲状态变化事件能在卡顿/恢复时触发 | onLoadingStatusListener 回调被触发且状态字段正确 | setOnLoadingStatusListener | L1 |
| F-11-07 | 事件回调 | 验证跳转完成事件能在 seek 完成时触发 | onSeekComplete 回调被触发 | setOnSeekComplete | L1 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-12-01 | 列表播放器 | 验证添加 URL 播放源到列表能成功加入列表 | 列表项数增加且 getCurrentUid 返回新项 uid | addUrlSource | L0 |
| F-12-02 | 列表播放器 | 验证切换到下一个播放源能播放下一项内容 | 切换后播放下一项内容且列表指针前移 | moveToNext | L0 |
| F-12-03 | 列表播放器 | 验证切换到上一个播放源能播放上一项内容 | 切换后播放上一项内容且列表指针后移 | moveToPre | L0 |
| F-12-04 | 列表播放器 | 验证跳转到不存在的列表项能容错处理不崩溃 | 不存在项被拒绝或忽略且不崩溃 | moveTo | L2 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-13-01 | 直播时移播放器 | 验证设置时移数据源能加载时移流 | 时移流加载成功且可播放 | setDataSource | L0 |
| F-13-02 | 直播时移播放器 | 验证查询当前直播时间能返回现实时间 | 返回的 liveTime 为非零时间值 | getCurrentLiveTime | L0 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-14-01 | 视频下载 | 验证准备下载任务能获取可下载项信息 | download_prepared 事件触发且返回可下载项 | prepare | L0 |
| F-14-02 | 视频下载 | 验证开始下载视频能触发进度回调并最终完成 | download_progress 与 download_completion 事件触发且文件生成 | start | L0 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-15-01 | 媒体预加载 | 验证添加预加载任务能开始预取媒体数据 | 任务进入预加载中状态且回调触发 | load/addTask | L0 |
| F-15-02 | 媒体预加载 | 验证取消预加载任务能停止预取并触发回调 | onCancel 回调触发且任务终止 | cancel/cancelTask | L0 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-16-01 | 全局设置 | 验证设置系统亮度能改变屏幕亮度 | 屏幕亮度随设置值变化 | setSystemBrightness | L0 |
| F-16-02 | 全局设置 | 验证查询系统亮度能返回当前亮度值 | 返回的亮度值与实际屏幕亮度一致 | getSystemBrightness | L0 |

| 测试点编号 | 功能模块 | 测试点 | 验证点 | 覆盖 API | 测试点级别 |
|------------|----------|--------|--------|---------|------------|
| F-17-01 | 全局播放器设置 | 验证查询 SDK 版本号能返回非空版本字符串 | 返回的版本字符串非空且格式合理 | getSDKVersion | L0 |
| F-17-02 | 全局播放器设置 | 验证开启控制台日志能在控制台看到播放器日志 | 控制台输出播放器相关日志 | enableConsoleLog | L0 |

---

### 3.2 兼容性测试

兼容性测试采用**华为手机款型 × HarmonyOS 版本**交叉组合验证策略：

#### 3.2.1 设备款型覆盖

| 设备款型 | 验证重点 |
|----------|----------|
| 直板高端 | 验证原生 API 性能表现，确保高端设备无兼容问题 |
| 直板中低端 | 验证原生 API 在中低端设备上的可用性，确保功能正常 |
| 双折叠 | 验证双折叠设备上的 API 行为，确保屏幕适配正常 |
| 阔折叠 | 验证阔折叠设备上的 API 行为，确保屏幕适配正常 |

#### 3.2.2 HarmonyOS 版本覆盖

**版本选择说明**：API 19、21、22、23 当前市场占比超过 96%，是鸿蒙化适配的重点验证版本，其他版本占比低，纳入选测范围。

| HarmonyOS 版本 | API Version | 验证重点 |
|---------|-----------|----------|
| HarmonyOS NEXT | API 23 | 验证最新系统版本兼容性，确保新特性正常 |
| HarmonyOS NEXT | API 22 | 验证 API 22 版本兼容性，确保功能稳定 |
| HarmonyOS NEXT | API 21 | 验证 API 21 版本兼容性，确保广泛适配 |
| HarmonyOS NEXT | API 19 | 验证 API 19 基础版本，确保向后兼容 |
| 其他版本 | API 20 等 | 选测，根据项目需求酌情验证 |

#### 3.2.3 交叉组合矩阵

| 设备款型 | API 23 | API 22 | API 21 | API 19 | 其他 API |
|----------|------------|------------|------------|------------|------------|
| 直板高端 | ✓ | △ | △ | △ | △ |
| 直板中低端 | △ | ✓ | △ | △ | △ |
| 双折叠 | △ | △ | ✓ | △ | △ |
| 阔折叠 | △ | △ | △ | ✓ | △ |

> 注：✓=必测（每个设备款型选择一个 API 版本必测），△=选测（根据项目需求和资源情况酌情选择）

### 3.3 DFX 测试

| DFX 维度 | 测试重点 | 测试策略 |
|----------|----------|----------|
| 稳定性测试 | 长时间运行、异常恢复 | 通过云测试验证应用稳定性 |
| 性能测试 | 响应时间、CPU/内存占用 | 通过云测试验证性能指标 |
| 功耗测试 | 电量消耗、后台功耗 | 通过云测试验证功耗表现 |
| UX 测试 | 界面布局、交互体验 | 通过云测试验证用户体验 |

### 3.4 安全测试

| 安全维度 | 测试重点 | 测试策略 |
|----------|----------|----------|
| 病毒扫描 | 恶意代码检测 | 通过安全扫描工具覆盖 |
| 开源软件漏洞 | 依赖组件漏洞扫描 | 通过安全扫描工具覆盖 |
| 敏感信息 | 隐私数据泄露风险 | 通过安全扫描工具覆盖 |

### 3.5 自动化测试分析

**自动化可行性分析**：

| 模块 | 功能名称 | 测试点数量 | 可自动化测试点 | 自动化方式 | 说明 |
|------|----------|------------|----------------|------------|------|
| F-01 | 播放器实例与生命周期管理 | 4 | 4 | UI 自动化 + 接口自动化 | 创建/释放操作可自动化 |
| F-02 | 视频源设置 | 4 | 4 | UI 自动化 + 接口自动化 | 设置源与切换可自动化 |
| F-03 | 播放控制 | 7 | 7 | UI 自动化 + 接口自动化 | 状态变化可自动验证 |
| F-04 | 视频渲染面 | 4 | 3 | UI 自动化 | 全屏切换的画面需人工辅助 |
| F-05 | 播放配置 AVPConfig | 3 | 3 | 接口自动化 | 配置生效可通过行为验证 |
| F-06 | 轨道管理 | 4 | 4 | UI 自动化 + 接口自动化 | 轨道切换可自动化 |
| F-07 | 字幕 | 3 | 3 | UI 自动化 + 接口自动化 | 字幕回调可自动验证 |
| F-08 | 截图与缩略图 | 3 | 3 | 接口自动化 | 文件生成可自动验证 |
| F-09 | 渲染模式 | 5 | 4 | UI 自动化 | 画面变化需人工辅助 |
| F-10 | 音量/倍速/静音/循环/快启 | 5 | 5 | UI 自动化 + 接口自动化 | 属性生效可自动验证 |
| F-11 | 事件回调 | 7 | 7 | 接口自动化 | 事件触发可自动验证 |
| F-12 | 列表播放器 | 4 | 4 | UI 自动化 + 接口自动化 | 列表操作可自动化 |
| F-13 | 直播时移播放器 | 2 | 2 | UI 自动化 + 接口自动化 | 时移操作可自动化 |
| F-14 | 视频下载 | 2 | 2 | 接口自动化 | 下载进度可自动验证 |
| F-15 | 媒体预加载 | 2 | 2 | 接口自动化 | 任务状态可自动验证 |
| F-16 | 全局设置 | 2 | 2 | 接口自动化 | 亮度变化可自动验证 |
| F-17 | 全局播放器设置 | 2 | 2 | 接口自动化 | 版本/日志可自动验证 |

**自动化覆盖率**：63 个测试点中，60 个可自动化，自动化覆盖率为 **95.2%**。

**无法完全自动化的测试点**：
- F-04-04 全屏切换时渲染面重建：画面是否丢失/黑屏需要人工视觉辅助判定
- F-09-01 等比缩放模式：画面比例是否变形需要人工视觉辅助判定
- F-09-02 全屏缩放模式：画面填满效果需要人工视觉辅助判定
- F-09-05 视频背景色：底色变化需要人工视觉辅助判定

> 注：对于无法完全自动化的测试点，建议采用"自动化 + 人工"混合测试策略。

---

## 第四部分：测试分析总结

### 4.1 测试范围

- **功能模块总数**: 17 个（已排除 F-18/F-19/F-20 三个 P3 不适配/空实现模块）
  - P0 核心功能：8 个（详细测试：正常 + 异常 + 边界）
  - P1 重要功能：5 个（重点测试：正常 + 关键异常）
  - P2 辅助功能：4 个（基本验证：正常流程）
  - P3 不适配/空实现：3 个（DRM、悬浮窗与画中画、双向回调，不生成功能测试点）
- **API 接口总数**: 约 90 个

### 4.2 测试覆盖评估

| 测试对象 | 总数 | 已覆盖 | 覆盖率 |
|----------|------|--------|----------|
| 功能模块 | 17 | 17 | 100% |
| API 接口 | 90 | 60+ | ~67% |
| 测试点 | 63 | 63 | 100% |

### 4.3 测试优先级建议

| 阶段 | 测试范围 | 通过标准 | 重点 |
|------|----------|----------|------|
| 第一阶段 | P0 核心功能（F-01~F-04, F-09~F-11） | 100% 通过率 | 正常 + 异常 + 边界全覆盖 |
| 第二阶段 | P1 重要功能（F-05~F-08, F-12） | 100% 通过率 | 正常流程 + 关键异常 |
| 第三阶段 | P2 辅助功能（F-13~F-17） | 100% 通过率 | 基本功能验证 |

### 4.4 风险识别

- **播放器内核**: AliyunPlayer 闭源商用 SDK 无鸿蒙版本，改用 AVPlayer 重新实现，状态机/属性/事件映射存在差异，需逐项核对
- **多实例管理**: AVPlayer 无内置多实例管理，需在鸿蒙侧按 playerId 自行维护 Map，事件分发时序需保证一致
- **VidSts/VidAuth/VidMps 数据源**: 与阿里云鉴权强绑定，鸿蒙侧无原生 SDK 解析，需应用层自行实现 vid→URL 解析
- **列表播放器/时移播放器**: AVPlayer 无对应子类，预加载策略是 Aliyun SDK 私有能力，鸿蒙侧需自行封装且效果难对齐
- **AVPConfig 字段**: 约 25 个字段大量在鸿蒙侧无对等 API，不支持的需做静默忽略 + 日志提示，避免运行时崩溃
- **事件回调**: 约 30 种事件，method 名与字段必须与 Dart 侧 `_onEvent` switch 完全一致，SEI/埋点 params 无等价
- **XComponent 渲染**: 全屏切换/列表复用时需处理 surface 重建与 `setSurface(null)` 等价逻辑
- **截图与缩略图**: AVImageGenerator 异步模型与 Aliyun Helper 不同，位图数据格式需对齐 Dart 侧签名
- **下载与预加载**: 需基于 @ohos.net.http 自行实现分片下载与字节范围预取，加密下载无法复用 Aliyun 私有加密
- **DRM**: Aliyun DRM 回调模型与鸿蒙 DRM Kit 的 MediaKeySession 异步模型差异大，FairPlay 不互通，建议空实现
- **悬浮窗/画中画**: 权限申请流程与 Android SYSTEM_ALERT_WINDOW 不同，画中画为 iOS 专有标注，建议空实现
- **双向回调**: BasicMessageChannel 返回 Future 的时序需精确处理，预渲染帧/渲染帧回调无对等，建议空实现
- **Alpha 渲染/SEI/HttpDNS/http2/IP 解析**: 均为 Aliyun 私有能力，鸿蒙侧无对等，需安全空实现
- **音量/倍速映射**: Aliyun volume 0~2 与 AVPlayer 0~1 上限不同需 clamp；speed 枚举值集合不同需映射表

---
*本报告由 test-analysis skill 自动生成*
