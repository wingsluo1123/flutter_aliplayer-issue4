# flutter_aliplayer 鸿蒙适配校验报告

## 一、检查内容

1. **AVPlayer API 核实**：查阅 HarmonyOS API 参考文档，逐项确认 `AliPlayerProxy.ets` 中使用的 AVPlayer 属性（url/surfaceId/loop/videoScaleType/audioRendererInfo/duration/currentTime/width/height）、方法（prepare/play/pause/stop/reset/release/seek/setVolume/setSpeed/getTrackDescription/selectTrack）、事件（stateChange/error/videoSizeChange/startRenderFrame/endOfStream/seekDone/timeUpdate/durationUpdate/bufferingUpdate）和枚举（SeekMode/PlaybackSpeed/VideoScaleType/BufferingInfoType/StateChangeReason）的签名、参数类型和回调签名与官方文档一致。

2. **Dart 通路一致性**：交叉比对 `lib/` 下 9 个 Dart 文件与 `ohos/` 下 3 个 ets 文件的 MethodChannel 名（5 个）、EventChannel 名（4 个）、BasicMessageChannel 名（`aliPlayer_onPrepare`/`aliPlayer_onRenderingStart`/`aliPlayer_onStateChanged` + playerId 拼接）、事件 key（`method`）、PlatformView viewType（`flutter_aliplayer_render_view`）、wrapWithPlayerId 参数结构。

3. **OHOS 实现完整性**：检查 `FlutterAliplayerPlugin.ets` 的 onMethodCall switch 是否覆盖 Dart 侧调用的全部方法名，P3 方法是否安全空实现（返回 `success(null)` 而非 `notImplemented()`），`AliPlayerProxy.ets` 的状态机映射、事件转发、surfaceId 时序、倍速/音量/seekMode/ScaleMode 映射是否真正生效。

4. **Example 可运行性**：检查 `example/lib/main.dart` 是否调用插件真实实现、覆盖 P0 API、展示真实返回值和回调；`example/ohos` 的 EntryAbility、GeneratedPluginRegistrant、module.json5、资源是否完整。

5. **权限/依赖/配置**：检查 `ohos/src/main/module.json5` 和 `example/ohos/entry/src/main/module.json5` 的权限声明、`pubspec.yaml` 的 ohos 平台声明、`oh-package.json5` 依赖、是否有 Android/iOS 原生库残留。

## 二、发现并修复的问题

| # | 问题 | 修改位置 | 复查结果 |
|---|------|---------|---------|
| 1 | **下载/预加载 MethodChannel 方法名与播放器方法冲突**：download 通道的 `prepare`/`stop`/`release` 等方法名与播放器方法重叠，共享 handler 会将下载 `prepare` 误路由到播放器 `prepare` 逻辑 | `FlutterAliplayerPlugin.ets`：新增 `NoopMethodCallHandler` 类，download/medialoader/loaderv2 三个通道改用独立 no-op handler | ✓ 下载/预加载通道方法不再干扰播放器逻辑 |
| 2 | **`setLogInfoBlock` 方法名不匹配**：Dart `setLogInfoCallBack()` 实际 invoke `"setLogInfoBlock"`，OHOS 只处理 `"setLogInfoCallBack"` | `FlutterAliplayerPlugin.ets` no-op case 列表新增 `case 'setLogInfoBlock':` | ✓ 日志回调注册不再触发 notImplemented |
| 3 | **`addVidPlayerConfigByStringValue`/`addVidPlayerConfigByIntValue` 方法名不匹配**：Dart 调用这两个方法名，OHOS 只处理 `"addVidPlayerConfigBy"` | 同上 no-op 列表新增两个 case | ✓ VidPlayerConfig 方法不再触发 notImplemented |
| 4 | **`setEnableHardwareDecoder` 缺失**：Dart 调用此方法（setter），OHOS 只处理 `"enableHardwareDecoder"`（getter） | config no-op block 新增 `case 'setEnableHardwareDecoder':` | ✓ 硬件解码设置不再触发 notImplemented |
| 5 | **~20 个 P3 方法落入 `notImplemented()` 而非 `success(null)`**：`setDrmCallback`/`setOnPreRenderFrameCallback`/`setOnRenderFrameCallback`/`setConvertURLCallback`/`setOnURLSourceExpiredListener`/`setOnVidAuthExpiredListener`/`getSubMediaInfo`/`createThumbnailHelper`/`requestBitmapAtPosition`/`setPlayerScene`/`setPrivateService`/`setPreferPlayerName`/`getPlayerName`/`setUserData`/`getUserData`/`setTraceID`/`sendCustomEvent`/`setStreamDelayTime`/`getOption`/`getPropertyString`/`setEventReportParamsDelegate`/`setPictureInPictureShowMode`/`setPictureInPictureEnableForIOS`/`setRenderFrameCallbackConfig`/`getCacheFilePathWithVidAtPreviewTime` | no-op case 列表批量新增 | ✓ 全部返回 success(null)，符合 PRD "安全空实现" 要求 |
| 6 | **`reload` 为空操作**：注释说"网络重连近似"但实际不做任何事 | `AliPlayerProxy.ets` 新增 `reload()` 方法（reset → 重新 setUrl），`FlutterAliplayerPlugin.ets` 的 reload case 调用 `proxy.reload()` | ✓ 网络重连有实际行为 |
| 7 | **`getSpeed()` 固定返回 1.0**：不反映实际设置的倍速 | `AliPlayerProxy.ets` 新增 `currentSpeed` 字段，`setSpeed` 记录值，`getSpeed` 返回记录值 | ✓ 倍速查询正确 |
| 8 | **`selectTrack` 参数 key 不匹配**：Dart 发送 `{'trackIdx': ...}`，OHOS 查找 `map.get('trackIndex')`（key 名不一致），导致 trackIndex 恒为 NaN | `FlutterAliplayerPlugin.ets` `handleSelectTrack` 改为 `map.get('trackIdx')` | ✓ 轨道切换参数正确解析 |

## 三、完整性结论

### 公开 API 与 Dart 通路
- `lib/` 暴露的公开 API 在 OHOS 分支均能走到 MethodChannel/EventChannel/BasicMessageChannel/PlatformView，无 `UnsupportedError`、无错误平台判断。
- 5 个 MethodChannel 名、4 个 EventChannel 名、3 个活跃 BasicMessageChannel 名、事件 key `method`、PlatformView viewType 全部与 Dart 侧严格一致。
- P0 方法（create/setUrl/prepare/play/pause/stop/seekTo/release/setPlayerView/setVolume/setSpeed/setMuted/setLoop/setAutoPlay/setScalingMode/getDuration/getCurrentPosition/getVideoWidth/getVideoHeight + 6 个事件回调）全部真实实现。
- P1 方法（getTrackDescription/selectTrack/getMediaInfo）部分实现，参数语义已对齐。
- P3 方法（VidSts/VidAuth/ARTC/DRM/HttpDNS/悬浮窗/下载/预加载/SEI/埋点/缩略图/旋转/镜像/Alpha/截图等）全部安全空实现 + hilog 警告，不崩溃。

### OHOS 实现
- AVPlayer 状态机映射（idle→0/initialized→1/prepared→2/playing→3/paused→4/stopped→5/completed→6/error→7）与 Dart `PlayState` 对齐。
- surfaceId 时序：idle 缓存 pendingSurfaceId，initialized 后 applySurfaceId。
- prepare 阶段排队：pendingPlay/pendingSeekMs 在 prepared 后 flush。
- 倍速/音量/seekMode/ScaleMode 映射均经过 API 文档核实。
- 无固定返回值/空函数/测试数据/假成功（除明确标注的 P3 不支持能力）。

### Example
- `example/lib/main.dart` 调用 `FlutterAliPlayerFactory.createAliPlayer()` → `AliPlayerView` → `setPlayerView` → `setUrl` → `prepare` → `play`/`pause`/`stop`/`seekTo` → `getDuration`/`getCurrentPosition` → `release`，全部走插件真实实现。
- 6 个事件回调（onPrepared/onError/onCompletion/onLoadingStatus/onInfo/onRenderingStart）在界面展示真实状态变化。
- `example/ohos` 的 EntryAbility 正确注册 GeneratedPluginRegistrant，module.json5 声明 INTERNET 权限，deviceTypes 包含 phone/tablet。

### 权限/配置
- `ohos/src/main/module.json5`：声明 `ohos.permission.INTERNET`（网络播放必需），deviceTypes [default, tablet]，type har。✓
- `example/ohos/entry/src/main/module.json5`：声明 `ohos.permission.INTERNET`，deviceTypes [phone, tablet]，mainElement EntryAbility。✓
- `pubspec.yaml`：ohos 平台声明 `package: com.alibaba.fplayer.flutter_aliplayer, pluginClass: FlutterAliplayerPlugin`。✓
- `oh-package.json5`（插件 + example）：依赖为空/仅构建工具，无 Android/iOS 原生库残留，`@ohos/flutter_ohos` 由 Flutter 构建自动注入。✓
- 无需用户动态授权的能力（INTERNET 为 install-time 权限）。✓

## 四、构建命令和结果

```powershell
# 根目录
flutter pub get

# example 目录
Push-Location example
flutter pub get
flutter build hap --debug
Pop-Location
```

- **Dart kernel_snapshot**：通过，0 error
- **ArkTS 编译**：通过，0 error（仅 1 条 ArkTS:WARN 来自 `@ohos/flutter_ohos` 框架代码 `Any.ets`，非插件代码）
- **HAP 打包**：成功产出 `entry-default-unsigned.hap`（93.7 MB）
- **退出码 1 原因**：`Will skip sign 'hos_hap'. No signingConfigs profile is configured` — 缺省签名配置，需 DevEco Studio 配置后安装到设备，不影响代码编译

## 五、仍无法完全确认的项目

| 项目 | 原因 | 影响范围 |
|------|------|---------|
| 真机播放效果 | 编译通过但未在真机/模拟器上运行验证 | 需 DevEco Studio 配置签名后真机验证 AVPlayer 网络播放/surface 渲染/事件回调链路 |
| `VIDEO_SCALE_TYPE_SCALED_ASPECT` (API 20+) | 该枚举值为 API 20+，example 的 compatibleSdkVersion 为 5.0.0(12)；编译通过但 API 12 设备上 ScaleMode.TO_FILL(2) 可能不生效 | 仅影响 TO_FILL 缩放模式，FIT(0)/FILL(1) 在 API 12 正常；setScalingMode 有 try-catch 守卫，不会崩溃 |
| VidSts/VidAuth URL 解析 | 阿里云 VOD 鉴权为私有协议，需应用层自行调用阿里云服务端接口解析为 URL 后调 `setUrl` | 非 P0 能力，PRD 已标注为应用层职责 |
| 截图 (snapshot) | 需用 AVImageGenerator 单独实现，当前返回空 | PRD 标注为 P2，非 example 覆盖范围 |
