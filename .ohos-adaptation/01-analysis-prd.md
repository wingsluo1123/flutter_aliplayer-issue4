# flutter_aliplayer 鸿蒙适配 PRD

> 基于 `.ohos-adaptation/01-analysis.json` 的现状分析,结合 HarmonyOS Media Kit / ArkUI / Network Kit / DRM Kit 等原生能力语义编写。

## 一、判断依据

- **插件类型:plugin_mixed**。同时使用 MethodChannel(5 个)、EventChannel(4 个)、按 playerId 拼接的 BasicMessageChannel(十余个,含双向回调)、PlatformView(SurfaceView/TextureView/AliDisplayView),属于混合型插件。
- **架构:standalone**。单 plugin 包,Dart 层通过 `FlutterAliPlayerFactory.instanceMap` 按 `playerId` 管理多实例,事件由 `flutter_aliplayer_event` 单一 EventChannel 广播后在 Dart 侧按 playerId 分发。
- **核心风险:内核不可复用**。播放内核为阿里云闭源商用 SDK(AliyunPlayer 7.15.0 / AliVCSDK),鸿蒙侧无对应版本,必须用 HarmonyOS **Media Kit 的 AVPlayer(`@ohos.multimedia.media`)** 重新实现;Aliyun VOD 生态数据源(VidSts/VidAuth/VidMps)、ARTC/RTS 超低延时直播、Aliyun 本地缓存/HttpDNS 等私有能力无法对等映射。
- **HarmonyOS 语义核实结论**(已查 API 参考):
  - 视频播放内核 → **AVPlayer**(`@ohos.multimedia.media`),支持 `url`(fd:// / http:// / https:// / HLS)、`surfaceId`、`loop`、`videoScaleType`、`audioInterruptMode`、`audioRendererInfo`、`state`、`currentTime`、`duration`、`muted`、`speed`、`volume`;方法 `prepare/play/pause/stop/reset/release/seek/getTrackDescription/selectTrack/setMediaSource`;事件 `on('stateChange')`/`on('error')` 等。网络播放需声明 **ohos.permission.INTERNET**。
  - 视频渲染面 → **XComponent**(`getXComponentSurfaceId()` + `onSurfaceCreated/Changed/Destroyed`),将 surfaceId 交给 AVPlayer。
  - 帧提取(截图/缩略图)→ **AVImageGenerator**(`@ohos.multimedia.media`)。
  - 网络下载/预加载 → **@ohos.net.http**(无开箱预加载,需自行实现)。
  - DRM → **DRM Kit**(`@ohos.multimedia.drm`),接口模型与 Aliyun DRM 不同。
  - 悬浮窗/画中画 → 窗口能力(`@ohos.window`)/ PiP 能力,与 Android `SYSTEM_ALERT_WINDOW` 模型不同。

---

## 二、能力清单

### 1. 播放器实例与生命周期管理

| 项 | 说明 |
|---|---|
| 公开 API | `FlutterAliPlayerFactory.createAliPlayer({playerId})` / `createAliListPlayer` / `createAliLiveShiftPlayer` / `FlutterAliplayer.init(id)` / `create()` / `release()` / `releaseAsync()` |
| 输入条件 | 可选 `playerId`(多实例);`PlayerType`(Single/List/LiveShift) |
| 用户可见行为 | 创建并持有一个播放器实例,按 playerId 注册到 `instanceMap` |
| 输出/状态变化 | 原生侧创建对应播放器对象并加入 Map;`release` 时移除并释放资源 |
| 平台能力 | HarmonyOS AVPlayer 提供 `idle→initialized→prepared→playing→paused→completed→stopped→(error→)released` 状态机,需在鸿蒙侧按 playerId 维护 AVPlayer 实例 Map 与生命周期 |
| 适配风险 | 多实例管理需自行实现;AVPlayer 无"列表播放器/时移播放器"子类概念,列表与时移需在鸿蒙侧封装层模拟 |

### 2. 视频源设置

| 项 | 说明 |
|---|---|
| 公开 API | `setUrl(url)` / `setVidSts(...)` / `setVidAuth(...)` / `setVidMps(mpsInfo)` / `setLiveSts(...)` / `switchStream(url)` / `setDataSource(timeLineUrl,url)` |
| 输入条件 | URL 字符串,或 vid+sts/auth/mps/liveSts 凭证 |
| 用户可见行为 | 设置播放源;URL 方式直接可播;vid 方式需鉴权解析后获得可播放地址 |
| 输出/状态变化 | 原生侧将数据源交给播放器内核 |
| 平台能力 | AVPlayer 仅接受 `url`(fd:// / http/https / HLS)或 `setMediaSource(MediaSource)`。vid+sts/auth/mps 需由应用层(或适配层)调用阿里云 VOD 服务端接口解析为 URL 后再交给 AVPlayer |
| 适配风险 | **高**。VidSts/VidAuth/VidMps/LiveSts 与阿里云鉴权强绑定,鸿蒙侧无原生 SDK 可解析,需应用层自行实现鉴权→URL 解析;`switchStream`(直播切清晰度)需重建/切换 MediaSource |

### 3. 播放控制

| 项 | 说明 |
|---|---|
| 公开 API | `prepare()` / `play()` / `pause()` / `stop()` / `seekTo(position,seekMode)` / `setStartTime(time,seekMode)` / `reload()` / `clearScreen()` / `clearScreenSync()` |
| 输入条件 | seek 位置(ms)+ SeekMode(Accurate/Inaccurate) |
| 用户可见行为 | 起播/暂停/停止/跳转/重连 |
| 输出/状态变化 | AVPlayer 状态机迁移;`currentTime`/`duration` 更新 |
| 平台能力 | AVPlayer `prepare()/play()/pause()/stop()/reset()/release()/seek(timeMs,mode)`;`seek` 支持 `SwitchMode`(精准/不精准);`setStartTime` 起播位置可用 `PlaybackStrategy` 传递 |
| 适配风险 | 中。AVPlayer 的 seek 模式枚举与 Aliyun SeekMode 数值不同,需做映射;`reload`(网络重连)可用 `reset`+重新 `setMediaSource` 近似;`clearScreen` 需在渲染层处理(置黑/暂停解码) |

### 4. 视频渲染面

| 项 | 说明 |
|---|---|
| 公开 API | `AliPlayerView`(Widget) / `setPlayerView(viewId)` / `aliPlayerViewType`(surfaceview/textureview/displayview) |
| 输入条件 | 坐标 x/y/width/height + viewType |
| 用户可见行为 | 在 Flutter 视图树中嵌入原生视频渲染面 |
| 输出/状态变化 | 创建 PlatformView,产出 viewId;`setPlayerView` 将渲染面与播放器绑定 |
| 平台能力 | HarmonyOS 用 **XComponent** 作为 PlatformView,通过 `getXComponentSurfaceId()` 获取 surfaceId,在 `onSurfaceCreated` 回调中将其赋给 `avPlayer.surfaceId`;`onSurfaceChanged/Destroyed` 处理尺寸变化与释放 |
| 适配风险 | 中。需实现 OHOS PlatformView(ets)注册 `flutter_aliplayer_render_view`;SurfaceView/TextureView/DisplayView 三种 viewType 在鸿蒙侧统一为 XComponent,差异仅在 surfaceId 传递时机;全屏切换/列表复用时需处理 surface 重建与 `setSurface(null)` 等价逻辑 |

### 5. 播放配置(AVPConfig)

| 项 | 说明 |
|---|---|
| 公开 API | `getConfig()` / `setConfig(map)` / `getPlayConfig()` / `setPlayConfig(AVPConfig)` |
| 输入条件 | 缓冲水位(startBuffer/highBuffer/maxBuffer)、网络超时/重试、maxDelayTime(直播)、referer/userAgent/httpProxy/httpHeaders、enableSEI/enableLocalCache、disableAudio/disableVideo、positionTimerIntervalMs 等 |
| 用户可见行为 | 影响起播速度、卡顿恢复、网络容错行为 |
| 输出/状态变化 | 播放器内核应用配置 |
| 平台能力 | AVPlayer 无等价的统一 Config 对象;部分能力可映射:`audioRendererInfo`(音频用途)、`audioInterruptMode`(焦点)、HTTP 头可通过 `MediaSource` 的 `dataSrc`/headers 设置;缓冲水位/超时重试 AVPlayer 未全部开放,需依赖系统默认或通过 `PlaybackStrategy` 有限控制 |
| 适配风险 | **高**。AVPConfig 字段约 25 个,大量在鸿蒙侧无对等 API,需逐字段标注"支持/部分支持/不支持",不支持的做静默忽略并日志提示 |

### 6. 轨道管理

| 项 | 说明 |
|---|---|
| 公开 API | `getMediaInfo()` / `getSubMediaInfo()` / `getCurrentTrack(trackIdx)` / `currentTrack(TrackType)` / `selectTrack(trackIdx,{accurate})` / `setDefaultBandWidth/Resolution/AudioLanguage` |
| 输入条件 | TrackType(video/audio/subtitle/vod)或 trackIndex |
| 用户可见行为 | 查询/切换音视频/字幕轨;设置默认码率/清晰度/音频语言 |
| 输出/状态变化 | `OnTrackReady`/`OnTrackChanged` 回调;播放轨切换 |
| 平台能力 | AVPlayer `getTrackDescription()` 返回 `MediaDescription[]`,`selectTrack(index, SwitchMode)` 切换(API 12+);默认码率/清晰度无直接等价,需在 `MediaSource`/`PlaybackStrategy` 或轨道选择逻辑中模拟 |
| 适配风险 | 中。TrackInfo 数据结构字段与 `AVPTrackInfo`/`AliTrackInfo` 不一致,需做模型转换;`setDefaultBandWidth` 等需在 prepare 前基于 track 描述自行选择 |

### 7. 字幕

| 项 | 说明 |
|---|---|
| 公开 API | `addExtSubtitle(url)` / `selectExtSubtitle(trackIndex,enable)` / `setOnSubtitleShow/Hide/Header/ExtAdded` |
| 输入条件 | 外挂字幕 URL + trackIndex |
| 用户可见行为 | 加载/选择外挂字幕;字幕显示/隐藏/头信息回调 |
| 输出/状态变化 | 字幕轨添加/启用;回调触发 |
| 平台能力 | AVPlayer `url` 属性可设置外挂字幕文件地址(API 参考 line 3097);字幕显示/隐藏事件需通过 `on` 系列回调监听 |
| 适配风险 | 中。ass 字幕头信息(`setOnSubtitleHeader`)由调用者自行渲染的能力,需确认 AVPlayer 是否暴露原始字幕头;不支持的回调做空实现 |

### 8. 截图与缩略图

| 项 | 说明 |
|---|---|
| 公开 API | `snapshot(path)` / `setOnSnapShot` / `createThumbnailHelper(url)` / `requestBitmapAtPosition(position)` / `setOnThumbnailPreparedListener` / `setOnThumbnailGetListener` |
| 输入条件 | 保存路径 / 缩略图 URL / 位置(ms) |
| 用户可见行为 | 截取当前帧保存为图片;从远端缩略图获取指定位置位图 |
| 输出/状态变化 | `OnSnapShot(path)` 回调;`OnThumbnailGetSuccess(bitmap,range)` 回调 |
| 平台能力 | 截图与帧提取改用 **AVImageGenerator**(`@ohos.multimedia.media`,`fetchFrameByTime` 等)提取指定时间帧像素数据,再写入文件;缩略图 URL 获取需自行用 `@ohos.net.http` 下载并解析 |
| 适配风险 | 中。AVImageGenerator 异步模型与 Aliyun 缩略图 Helper 不同;返回的位图数据格式(Uint8List/Int64List range)需对齐 Dart 侧回调签名 |

### 9. 渲染模式(缩放/旋转/镜像/Alpha/背景色)

| 项 | 说明 |
|---|---|
| 公开 API | `setScalingMode/ getScalingMode` / `setRotateMode/getRotateMode` / `setMirrorMode/getMirrorMode` / `setAlphaRenderMode/getAlphaRenderMode` / `setVideoBackgroundColor` |
| 输入条件 | ScaleMode(ToFill/AspectFit/AspectFill)、RotateMode(0/90/180/270)、MirrorMode(None/H/V)、AlphaRenderMode |
| 用户可见行为 | 画面比例/旋转/镜像/透明通道渲染变化 |
| 输出/状态变化 | 渲染参数生效 |
| 平台能力 | AVPlayer `videoScaleType`(`VIDEO_SCALE_TYPE_FIT/FILL_AUTO/FILL`)对应缩放;旋转/镜像无直接等价,需在 XComponent/渲染层用 transform 或自定义渲染处理;Alpha 透明通道渲染 AVPlayer 不支持 |
| 适配风险 | 中高。缩放可映射;旋转/镜像需在 ArkUI transform 层模拟;Alpha 渲染模式(右/左/上/下侧 alpha)鸿蒙侧无原生支持,需标注不可用 |

### 10. 音量/倍速/静音/循环/快启

| 项 | 说明 |
|---|---|
| 公开 API | `setVolume/getVolume` / `setSpeed/getSpeed` / `setMuted/isMuted` / `setLoop/isLoop` / `setAutoPlay/isAutoPlay` / `setFastStart` / `setMaxAccurateSeekDelta` / `setOutputAudioChannel` |
| 输入条件 | volume(0~2)、speed(0.5~2.0)、bool 开关 |
| 用户可见行为 | 音量/倍速/静音/循环/自动播放行为变化 |
| 输出/状态变化 | AVPlayer 属性更新 |
| 平台能力 | AVPlayer `volume`(0~1,注意上限差异)、`speed`(PlaybackSpeed 枚举:0.75/1.0/1.25/1.75/2.0 等,需映射)、`muted`、`loop` 均支持;`setFastStart`/`setMaxAccurateSeekDelta` 无等价 |
| 适配风险 | 中。volume 上限 Aliyun 允许 0~2(>1 可能噪音),AVPlayer 限 0~1,需 clamp;speed 枚举值集合不同需映射表 |

### 11. 事件回调(约 30 种)

| 项 | 说明 |
|---|---|
| 公开 API | `setOnPrepared/OnRenderingStart/OnVideoSizeChanged/OnSnapShot/OnSeekComplete/OnSeiData/OnLoadingStatusListener/OnStateChanged/OnInfo/OnCompletion/OnTrackReady/OnSubTrackReady/OnVideoRendered/OnError/OnTrackChanged/OnThumbnail*/OnSubtitle*/OnSeekLiveCompletion/OnTimeShiftUpdater/OnStreamSwitchedSuccess/Fail/OnEventReportParams/OnPipStatusChanged/OnLogInfoCallBack` 等 |
| 输入条件 | 注册回调函数 |
| 用户可见行为 | 播放过程中各类事件透传至 Dart |
| 输出/状态变化 | EventChannel 广播 Map(`{method, playerId, ...}`),Dart 侧 `_onEvent` 按 method 分发 |
| 平台能力 | AVPlayer `on('stateChange')`/`on('error')`/`on('videoSizeChanged')`(如有)/`on('positionUpdate')`(如有)/`on('bufferingUpdate')` 等可覆盖大部分;部分 Aliyun 专有事件(SEI/首帧渲染/渲染帧回调/埋点 params)无等价,需空实现或用近似回调 |
| 适配风险 | **高**。事件 method 名与字段必须与 Dart 侧 `_onEvent` switch 完全一致,否则回调丢失;SEI 数据(`onSeiData` 返回 type/uuid/data)AVPlayer 无直接支持;`onEventReportParams`(埋点)鸿蒙侧无等价,需空实现 |

### 12. 列表播放器(FlutterAliListPlayer)

| 项 | 说明 |
|---|---|
| 公开 API | `addVidSource/addUrlSource` / `removeSource` / `getCurrentUid` / `clear` / `setPreloadCount` / `setMaxPreloadMemorySizeMB` / `setDefinition` / `moveToNext/moveToPre/moveTo` / `updatePreloadConfig` / `setPreloadScene` / `setMultiBitratesMode` / `enablePreloadStrategy/setPreloadStrategy` |
| 输入条件 | URL/vid + uid 列表;预加载个数/内存;清晰度 |
| 用户可见行为 | 短视频列表顺序播放与预加载 |
| 输出/状态变化 | 列表前进/后退/跳转;预加载触发 |
| 平台能力 | AVPlayer 无内置列表播放器,需在鸿蒙侧封装"多 AVPlayer 实例池 + 预加载策略":维护 N 个 AVPlayer,`moveTo` 时切换活跃实例并预取相邻项;vid 源需先解析为 URL |
| 适配风险 | **高**。预加载策略(动态 offset/码率模式/首帧优先)是 Aliyun SDK 私有能力,鸿蒙侧需自行实现且效果难对齐;`setPreloadStrategy` JSON 参数解析逻辑需重写 |

### 13. 直播时移播放器(FlutterAliLiveShiftPlayer)

| 项 | 说明 |
|---|---|
| 公开 API | `getCurrentLiveTime` / `getCurrentTime` / `seekToLiveTime` / `setDataSource(timeLineUrl,url)` / `setOnSeekLiveCompletion` / `setOnTimeShiftUpdater` |
| 输入条件 | 时移 timelineUrl + 播放 url;目标 liveTime |
| 用户可见行为 | 直播回看/时移到指定时间 |
| 输出/状态变化 | `onTimeShiftUpdater`(currentTime/shiftStart/shiftEnd)回调 |
| 平台能力 | AVPlayer 可播放 HLS 时移流(DVR);`currentTime` 可查询;但"直播现实时间/getCurrentLiveTime"与时移 timeline 解析为 Aliyun 私有逻辑,需应用层解析 timelineUrl 获取时间轴 |
| 适配风险 | **高**。timeline 协议为阿里云私有,鸿蒙侧无原生支持;`seekToLiveTime` 需将 liveTime 转为流内 position 再 seek |

### 14. 视频下载(FlutterAliDownloader)

| 项 | 说明 |
|---|---|
| 公开 API | `prepare(type,vid,...)` / `start(vid,index)` / `selectItem` / `setSaveDir` / `stop/delete/getFilePath/release` / `updateSource` / `setDownloaderConfig` / `getFullSaveForIOS` |
| 输入条件 | DOWNLOADTYPE_STS/AUTH + vid + 凭证;trackIndex;保存目录 |
| 用户可见行为 | 下载视频到本地;进度/完成/错误事件 |
| 输出/状态变化 | EventChannel 广播 `download_prepared/progress/process/completion/error` |
| 平台能力 | HarmonyOS 无开箱视频下载器,需基于 **@ohos.net.http** 自行实现分片下载与进度回调;vid 源需先解析为可下载 URL;安全下载(`initService` 加密校验文件)无法复用 Aliyun 私有加密 |
| 适配风险 | **高**。需完整重写下载引擎;加密下载/鉴权更新逻辑依赖 Aliyun 服务端,鸿蒙侧仅能实现普通明文下载 |

### 15. 媒体预加载(MediaLoader v1/v2)

| 项 | 说明 |
|---|---|
| 公开 API | v1:`load/loadWithBandWidth/resume/pause/cancel` + `setOnLoadStatusListener`;v2:`addTask(BaseVideoSource)/addUrlTask/addVidAuthTask/addVidStsTask/resumeTask/pauseTask/cancelTask/getPreloadConfig/setPreloadConfig` |
| 输入条件 | URL/vid + duration/bandWidth;PreloadConfig |
| 用户可见行为 | 播放前预取媒体数据以加速起播 |
| 输出/状态变化 | `onCompleted/onCancel/onError/onErrorV2` 回调(v2 带 taskId) |
| 平台能力 | HarmonyOS 无开箱媒体预加载,需基于 `@ohos.net.http` 自行实现"按 duration 预取字节范围 + 暂停/恢复/取消";PreloadConfig 全局单例需在鸿蒙侧维护 |
| 适配风险 | **高**。预加载与 AVPlayer 的衔接(预取数据如何喂给播放器)鸿蒙侧无 Custom DataSource 通路(除非用 `MediaSource` + `dataSrc` 自定义数据源),实现复杂度高 |

### 16. 全局设置(FlutterAliPlayerGlobalSettings)

| 项 | 说明 |
|---|---|
| 公开 API | `setGlobalEnvironment` / `setOption` / `disableCrashUpload` / `enableEnhancedHttpDns` / `setCacheUrlHashCallback` / `setNetworkCallback` / `setAdaptiveDecoderGetBackupURLCallback` / `setSystemBrightness/getSystemBrightness` |
| 输入条件 | GlobalEnv 枚举 / 选项键值 / 回调 |
| 用户可见行为 | 全局网络/DNS/缓存/亮度策略 |
| 输出/状态变化 | 全局配置生效;双向回调触发 |
| 平台能力 | HttpDNS/http2/IP 解析/网络数据回调均为 Aliyun SDK 私有,鸿蒙侧无等价;`setSystemBrightness` 可用 `@ohos.brightness` 或窗口亮度近似;`setCacheUrlHashCallback`/`setNetworkCallback`/`getBackupUrlCallback` 需在适配层提供占位实现 |
| 适配风险 | **高**。大部分全局网络优化能力无法对等映射,需标注不可用并保证调用不崩溃 |

### 17. 全局播放器设置(FlutterAliplayer 静态方法)

| 项 | 说明 |
|---|---|
| 公开 API | `getSDKVersion/getDeviceUUID/isFeatureSupport` / `setAudioSessionTypeForIOS` / `enableConsoleLog/setLogLevel/setLogInfoCallBack/setLogOption/getLogLevel` / `setUseHttp2/enableHttpDns/setDNSResolve/setIpResolveType` / `setFairPlayCertIDForIOS` / `enableHWAduioTempo/forceAudioRendingFormat` / `netWorkReConnect` / `enableLocalCache/setCacheFileClearConfig/clearCaches` / `enableNetworkBalance` / `createDeviceInfo/addBlackDevice` / `createVidPlayerConfigGenerator/setPreviewTime/setHlsUriToken/addVidPlayerConfigBy*/setEncryptType/generatePlayerConfig` |
| 输入条件 | 见各方法 |
| 用户可见行为 | 日志/网络/缓存/DRM 证书/设备信息等全局行为 |
| 输出/状态变化 | 全局状态更新 |
| 平台能力 | `getSDKVersion` 可返回适配层版本;日志可用 `hilog`(`@ohos.hilog`);`enableLocalCache`/`setCacheFileClearConfig`/`clearCaches` 需基于 `@ohos.file.fs` 自行实现;`createVidPlayerConfigGenerator` 系列(vid playerConfig 生成)为 Aliyun 私有,需在应用层实现;FairPlay 证书/HttpDNS/http2/IP 解析/硬件音频变速/音频渲染格式强制等无等价 |
| 适配风险 | **高**。静态方法约 30 个,半数以上无鸿蒙对等,需逐个标注并做安全空实现 |

### 18. DRM

| 项 | 说明 |
|---|---|
| 公开 API | `setDrmCallback(requestProvision,requestKey)` |
| 输入条件 | provision/key 请求回调 |
| 用户可见行为 | DRM 媒体播放时触发证书/密钥请求 |
| 输出/状态变化 | BasicMessageChannel `requestProvision`/`requestKey` 双向回调 |
| 平台能力 | HarmonyOS **DRM Kit**(`@ohos.multimedia.drm`):`MediaKeySystem`/`MediaKeySession` 体系,provision/key 流程由系统管理;AVPlayer 内置 DRM 集成 |
| 适配风险 | **高**。Aliyun DRM 回调模型(Flutter 侧返回字符串)与 DRM Kit 的 `MediaKeySession` 异步模型差异大;FairPlay(Aliyun)与鸿蒙 DRM 体系不互通 |

### 19. 悬浮窗与画中画

| 项 | 说明 |
|---|---|
| 公开 API | 悬浮窗:`showFloatViewForAndroid/hideFloatViewForAndroid/checkFloatViewPermission/requestFloatViewPermission/setFloatViewIcon/setFloatViewUIVisible`;画中画:`setPipController`/`setPictureInPictureShowMode`/`setPictureInPictureEnableForIOS` |
| 输入条件 | viewId / bool / 图标 asset |
| 用户可见行为 | 播放器以悬浮窗/画中画形式显示 |
| 输出/状态变化 | `OnPipStatusChanged/OnWillStartPip/OnWillStopPip` 回调 |
| 平台能力 | 悬浮窗可用 `@ohos.window` 的 `TYPE_FLOAT` 窗口近似,但需确认权限模型;画中画可用鸿蒙 PiP 能力(若设备支持);两者均与 Android `SYSTEM_ALERT_WINDOW`/iOS AVPiP 模型不同 |
| 适配风险 | **高**。悬浮窗权限申请流程不同;画中画为 iOS 专有标注,鸿蒙侧需重新实现;不支持的需守卫 |

### 20. 双向回调(URL/Auth 过期、预渲染帧、渲染帧、URL 转换)

| 项 | 说明 |
|---|---|
| 公开 API | `setOnURLSourceExpiredListener/removeOnURLSourceExpiredListener` / `setOnVidAuthExpiredListener/removeOnVidAuthExpiredListener` / `setOnPreRenderFrameCallback` / `setOnRenderFrameCallback` / `setConvertURLCallback` |
| 输入条件 | 注册回调(部分返回 Future/bool) |
| 用户可见行为 | 播放前 URL/Auth 过期时向 Dart 请求新凭证;渲染前/渲染帧由 Dart 决定是否渲染;URL 转换 |
| 输出/状态变化 | BasicMessageChannel 双向通信,Dart 返回结果给原生 |
| 平台能力 | AVPlayer 无"播放前请求新凭证"的内建回调,需在适配层监听错误(如 403)后主动触发 Dart 回调并重新 `setMediaSource`;预渲染/渲染帧回调 AVPlayer 不暴露;URL 转换需在 `setMediaSource` 前由适配层调用 Dart |
| 适配风险 | **高**。BasicMessageChannel 双向回调(尤其返回 Future)需精确处理时序;预渲染帧/渲染帧回调鸿蒙侧无对等,需空实现 |

---

## 三、适配优先级建议

1. **P0(必须)**:播放器实例/生命周期、URL 播放、播控(prepare/play/pause/stop/seek/release)、XComponent 渲染、基础事件(stateChange/error/videoSizeChanged/currentPosition/buffering)、缩放/音量/倍速/静音/循环。
2. **P1(重要)**:轨道管理(getTrackDescription/selectTrack)、外挂字幕、截图(AVImageGenerator)、AVPConfig 子集(缓冲水位/httpHeaders/userAgent)、列表播放器基础能力(addUrlSource/moveTo)。
3. **P2(尽力)**:VidSts/VidAuth(需应用层解析 URL)、缩略图、直播时移、媒体预加载、视频下载(普通)、日志/缓存/设备信息。
4. **P3(不适配/空实现)**:ARTC/RTS 超低延时直播、FairPlay、Aliyun HttpDNS/http2/IP 解析/网络数据回调/降级/滤镜、Alpha 渲染、SEI、埋点 params、悬浮窗/画中画(视设备能力)、预渲染帧/渲染帧回调、安全下载加密校验。

## 四、总体结论

复杂度 **very_high**,建议 **proceed_with_caution**。以 HarmonyOS **AVPlayer + XComponent** 为内核重新实现 P0/P1 能力可控;但 Aliyun VOD 生态数据源、ARTC 直播、Aliyun 网络优化与 DRM 等私有能力无法对等映射,需在 PRD 与 example 中明确标注限制,并对所有无对等 API 做安全空实现 + 日志提示,避免运行时崩溃。
