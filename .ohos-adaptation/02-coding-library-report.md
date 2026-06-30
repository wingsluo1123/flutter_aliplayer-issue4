# flutter_aliplayer 鸿蒙库适配与 Example 生成报告

## 一、库适配实现

### 1.1 适配概述

flutter_aliplayer (v7.15.0) 是阿里云播放器 Flutter 插件，原依赖闭源 AliyunPlayer SDK。鸿蒙侧无对应 SDK，以 HarmonyOS **MediaKit AVPlayer** (`@ohos.multimedia.media`) 为内核重新实现 P0/P1 能力，以 **XComponent (SURFACE)** 为渲染面替代 Android SurfaceView/TextureView/AliDisplayView。

插件类型 `plugin_mixed`，涉及 5 个 MethodChannel、4 个 EventChannel、十余个按 playerId 拼接的 BasicMessageChannel、1 个 PlatformView。

### 1.2 改动文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `pubspec.yaml` | 修改 | 新增 `flutter.plugin.platforms.ohos` 声明 (`package: com.alibaba.fplayer.flutter_aliplayer`, `pluginClass: FlutterAliplayerPlugin`) |
| `lib/flutter_aliplayer.dart` | 修改 | `AliPlayerView.nativeView()` 新增 `Platform.isOhos` 分支，使用 `OhosView` (viewType `flutter_aliplayer_render_view`) |
| `ohos/src/main/ets/components/plugin/FlutterAliplayerPlugin.ets` | 重写 | 插件主入口：注册 5 个 MethodChannel + 4 个 EventChannel + PlatformViewFactory，多实例管理，MethodCall 分发 |
| `ohos/src/main/ets/components/plugin/AliPlayerProxy.ets` | 新建 | AVPlayer 封装层：状态机映射、播控、事件回调转发 (EventChannel + BasicMessageChannel 双通道) |
| `ohos/src/main/ets/components/plugin/AliPlayerViewFactory.ets` | 新建 | PlatformView 四件套：Factory + PlatformView + @Builder + @Component (XComponent SURFACE) |
| `ohos/src/main/module.json5` | 修改 | 新增 `ohos.permission.INTERNET` 权限声明 |
| `ohos/oh-package.json5` | 无改动 | 依赖由 Flutter 构建工具自动注入 `@ohos/flutter_ohos` |
| `ohos/index.ets` | 无改动 | 已由 `flutter create` 生成正确导出 |

清理的文件（`flutter create` 生成的 federated 桩，原插件不使用 platform_interface 模式）：
- `lib/flutter_aliplayer_method_channel.dart` (删除)
- `lib/flutter_aliplayer_platform_interface.dart` (删除)
- `test/flutter_aliplayer_method_channel_test.dart` (删除)

### 1.3 核心实现点

**播放器内核 (AliPlayerProxy.ets)**：
- 使用 `media.createAVPlayer()` 创建实例，绑定 `on('stateChange')/on('error')/on('videoSizeChange')/on('startRenderFrame')/on('endOfStream')/on('seekDone')/on('timeUpdate')/on('durationUpdate')/on('bufferingUpdate')` 事件
- 状态机映射：AVPlayer `idle/initialized/prepared/playing/paused/completed/stopped/error/released` → Aliyun `0~7`
- **prepare 阶段排队**：`pendingPlay`/`pendingSeekMs` 在 `prepared` 状态后 flush，避免 prepare 期间调用 play/seek 静默失败
- **surfaceId 时序**：`idle` 状态缓存 `pendingSurfaceId`，`initialized` 状态后 `applySurfaceId()`
- **audioRendererInfo**：在 `initialized` 状态设置 `STREAM_USAGE_MOVIE`（prepare 前）
- 音量 clamp：Aliyun 0~2 → AVPlayer 0~1
- 倍速映射：浮点 → `PlaybackSpeed` 枚举 (0.5/0.75/1.0/1.25/1.5/1.75/2.0)
- SeekMode 映射：Aliyun ACCURATE(1) → `SEEK_CLOSEST`，INACCURATE(16) → `SEEK_PREV_SYNC`
- ScaleMode 映射：FIT(0) → `VIDEO_SCALE_TYPE_FIT`，FILL(1) → `VIDEO_SCALE_TYPE_FIT_CROP`，TO_FILL(2) → `VIDEO_SCALE_TYPE_SCALED_ASPECT`

**事件下发双通道**：
- EventChannel `flutter_aliplayer_event`（共享 EventSink）：onVideoSizeChanged/onSeekComplete/onLoadingBegin/Progress/End/onInfo/onError/onCompletion/onTrackReady/onRenderingStart 等
- BasicMessageChannel（StringCodec + JSON，按 playerId 拼接）：`aliPlayer_onPrepare{playerId}`、`aliPlayer_onRenderingStart{playerId}`、`aliPlayer_onStateChanged{playerId}`（Dart 侧 `_onEvent` 中 `onStateChanged` 已注释，必须走 BasicMessageChannel）

**PlatformView (AliPlayerViewFactory.ets)**：
- viewType `flutter_aliplayer_render_view`（与 Dart 侧 OhosView 一致）
- `AliPlayerPlatformView extends PlatformView`，`getView()` 返回 `WrappedBuilder<[Params]>`（框架 Params 类型）
- `@Component AliPlayerRenderComponent` 使用 XComponent(SURFACE)，`onLoad` 时通过 `XComponentController.getXComponentSurfaceId()` 获取 surfaceId
- `AliPlayerSurfaceRegistry` 全局注册表桥接 PlatformView 与 ArkUI Component
- `super(StandardMessageCodec.INSTANCE)` 传入 codec

**MethodCall 分发 (FlutterAliplayerPlugin.ets)**：
- `wrapWithPlayerId` 模式：`call.args` 为 `Map<string, Object>`，提取 `arg` 和 `playerId`
- P0 已实现：createAliPlayer/setUrl/setPlayerView/prepare/play/pause/stop/seekTo/release/setVolume/getVolume/setSpeed/getSpeed/setMuted/isMuted/setLoop/isLoop/setAutoPlay/isAutoPlay/setScalingMode/getScalingMode/getDuration/getCurrentPosition/getVideoWidth/getVideoHeight
- P1 部分实现：getTrackDescription/selectTrack/getMediaInfo
- P3 安全空实现（返回 null + hilog 警告）：setVidSts/setVidAuth/setVidMps/setLiveSts/switchStream/snapshot/setRotateMode/setMirrorMode/setAlphaRenderMode/enableHardwareDecoder/setConfig/getConfig/enableLocalCache/clearCaches/loadRtsLibrary/showFloatViewForAndroid 及全部下载器/预加载/全局设置方法

### 1.4 不支持的能力（P3，已标注）

| 能力 | 原因 |
|------|------|
| VidSts/VidAuth/VidMps/LiveSts | Aliyun VOD 鉴权私有协议，需应用层解析为 URL 后调 `setUrl` |
| ARTC/RTS 超低延时直播 | 依赖闭源 RtsSDK，AVPlayer 不支持 ARTC 协议 |
| DRM (setDrmCallback) | Aliyun DRM 与鸿蒙 DRM Kit 模型不互通 |
| FairPlay | iOS 专有 |
| HttpDNS/http2/IP 解析/网络回调 | Aliyun SDK 私有网络优化 |
| 悬浮窗/画中画 | 与 Android SYSTEM_ALERT_WINDOW/iOS AVPiP 模型不同 |
| 视频下载 (FlutterAliDownloader) | 需基于 @ohos.net.http 完整重写，安全下载加密校验无法复用 |
| 媒体预加载 (MediaLoader v1/v2) | 鸿蒙无开箱预加载，需自行实现 |
| SEI 数据 / 埋点 params / 预渲染帧回调 / Alpha 渲染 / 滤镜 | AVPlayer 无对应能力 |
| 截图 (snapshot) | 需用 AVImageGenerator 单独实现，当前返回空 |
| 旋转/镜像 | AVPlayer 不支持，需 ArkUI transform 层扩展 |

### 1.5 执行命令

```powershell
# 生成 ohos 脚手架
flutter create -t plugin --platforms ohos .

# 依赖获取
flutter pub get
Push-Location example; flutter pub get; Pop-Location

# 编译验证
Push-Location example; flutter build hap --debug; Pop-Location
```

### 1.6 构建结果

- `flutter pub get`（根目录 + example）：成功
- `flutter build hap --debug`：**编译成功**（23.3s，0 error）
- HAP 产物：`example/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`（91.5 MB，未签名）
- 未签名原因为缺省签名配置，需通过 DevEco Studio 配置 `Signing Configs`；代码编译无错误

## 二、Example 改动

### 2.1 改动文件

| 文件 | 说明 |
|------|------|
| `example/lib/main.dart` | 视频播放器示例：AliPlayerView + 播控按钮 + 进度条 + 事件回调展示 |
| `example/pubspec.yaml` | 已由 `flutter create` 生成，依赖 `flutter_aliplayer` (path: ../) |
| `example/ohos/entry/src/main/module.json5` | deviceTypes 增加 `tablet` |

### 2.2 使用方式

1. 用 DevEco Studio 打开 `example/ohos`，配置调试签名（File → Project Structure → Signing Configs → 勾选 Automatically generate signature）
2. 连接鸿蒙设备/模拟器
3. 运行 `flutter run` 或在 DevEco Studio 中运行

### 2.3 示例覆盖的 API

- `FlutterAliPlayerFactory.createAliPlayer()` — 创建播放器
- `AliPlayerView(onCreated:)` — PlatformView 渲染面
- `setPlayerView(viewId)` — 绑定渲染面
- `setUrl(url)` — 设置 HLS 测试源
- `prepare()` / `play()` / `pause()` / `stop()` — 播控
- `seekTo(position, SeekMode.ACCURATE)` — 跳转
- `getDuration()` / `getCurrentPosition()` — 查询
- `setOnPrepared` / `setOnError` / `setOnCompletion` / `setOnLoadingStatusListener` / `setOnInfo` / `setOnRenderingStart` — 事件回调
- `release()` — 释放

### 2.4 验证结果

- Dart 编译通过（kernel_snapshot 无错误）
- ArkTS 编译通过（0 error, 258 warn）
- HAP 打包成功（未签名）
- 测试源：Apple HLS bipbop (`https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8`)

## 三、未完成事项

1. **签名配置**：HAP 未签名，需 DevEco Studio 配置后才能安装到设备
2. **真机验证**：编译通过但未在真机/模拟器上运行验证播放效果
3. **截图 (snapshot)**：当前返回空，需用 AVImageGenerator 实现
4. **旋转/镜像**：需在 ArkUI transform 层扩展实现
5. **VidSts/VidAuth**：需应用层调用阿里云 VOD 服务端接口解析为 URL（非插件层职责）
6. **视频下载/预加载**：需基于 @ohos.net.http 完整重写（工作量较大）
7. **DRM**：需改用鸿蒙 DRM Kit (@ohos.multimedia.drm) 体系重新实现
