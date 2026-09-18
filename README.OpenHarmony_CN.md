# OpenHarmony（鸿蒙）适配说明

本文档描述 `flutter_aliplayer` 插件在 OpenHarmony / HarmonyOS 平台的能力与差异。鸿蒙侧播放器基于 MediaKit `AVPlayer` 实现（见 `ohos/` 目录），替代 Android / iOS 使用的阿里云播放器 SDK。

## 透明通道视频渲染（AlphaRenderMode）— 已支持

鸿蒙侧已实现透明通道视频合成渲染（issue #3 问题一），采用 **Flutter Texture 路径**：AVPlayer 输出到离屏 surface，由 C++（EGL/GLES）shader 按模式采样 RGB 半区与 Alpha 半区合成，合成结果经 `TextureRegistry` 作为 Flutter 纹理输出——透明区域能正确透出下层 Flutter Widget。

> 为何不用 XComponent + GLES：XComponent 的 SURFACE 是原生 surface，真机实验证明它不参与 Flutter 的 alpha 合成，透明区无法透出下层 Widget，因此改用 Texture 路径。

相关实现文件：

| 文件 | 职责 |
| --- | --- |
| `ohos/src/main/cpp/AlphaCompositeRenderer.cpp/.h` | 合成核心：按 mode 切分半区、shader 预乘 alpha、旋转校准、缩放 |
| `ohos/src/main/cpp/AlphaCompositorNapi.cpp` | NAPI 导出：createRenderer / setMode / setVideoSize / setScalingMode / getComposedSize / getProducerSurfaceId / destroyRenderer |
| `ohos/types/libalpha_compositor/index.d.ts` | ArkTS 类型声明 |
| `ohos/src/main/ets/components/plugin/AliPlayerProxy.ets` | surfaceId 重放、合成尺寸上报、缩放转发 |
| `ohos/src/main/ets/components/plugin/FlutterAliplayerPlugin.ets` | 方法分发、textureId 返回、错误返回 |

### 支持的模式

| mode | 含义 |
| --- | --- |
| 0 | 无 Alpha，AVPlayer 直出 XComponent surface（默认路径，零开销） |
| 1 | Alpha 在画面**右侧**（左半 RGB + 右半灰度蒙版） |
| 2 | Alpha 在画面**左侧** |
| 3 | Alpha 在画面**上侧** |
| 4 | Alpha 在画面**下侧** |

### 用法（OHOS）

```dart
// mode=1-4: 开启 Alpha 合成, 返回 textureId 用于 Texture widget 显示
final ret = await player.setAlphaRenderMode(1);
final textureId = (ret as Map?)?['textureId'] as int?;
if (textureId != null && textureId > 0) {
  // 用 Texture widget 显示合成画面（可叠放在任意 Widget 之上）
  Texture(textureId: textureId);
}

// mode=0: 切回普通直出渲染（释放合成纹理）
await player.setAlphaRenderMode(0);

// 查询当前模式
final mode = await player.getAlphaRenderMode(); // 兼容 getAlPhaRenderMode 历史拼写
```

注意事项：

- `setAlphaRenderMode(1-4)` 需在渲染视图创建（`onCreated`）之后调用；`prepare` 前后均可，若在 `prepared` 之后调用，surfaceId 切换会在允许赋值的状态自动重放，无需手动重试；
- **Alpha 模式下必须隐藏 `AliPlayerView` / `XComponent`**：XComponent 是原生 SURFACE，不参与 Flutter 的 alpha 合成，若与 `Texture` 同时显示会盖住合成结果，导致透明区透不出来。典型写法是用 `Visibility(visible: textureId == null)` 包裹 `AliPlayerView`；
- 播放中切换 mode 即时生效（shader uniform 热更新）；
- 视频源需为对应模式的 RGB+Alpha 拼接格式（如左半彩色内容 + 右半灰度蒙版）；
- `getVideoWidth/Height` 与 `onVideoSizeChanged` 返回的是**合成后（可见内容）尺寸**，半幅模式（1/2 取左右半、3/4 取上下半）为原始拼接尺寸的一半，与 Android SDK 语义一致；
- `setScalingMode` 的缩放基准是合成后的半幅尺寸，而非原始拼接尺寸（FIT 留黑边 / FILL 裁切 / TO_FILL 拉伸）；
- 横竖屏旋转：按 `OH_NativeImage` 的 transform 矩阵校准显示尺寸，旋转 90/270 时显示宽高与 buffer 宽高互换后参与宽高比计算。

### 已验证（真机 HAD-W32 / HarmonyOS 7.0.0.105 / API 26）

验证方法：使用「左半 RGB 四象限色块 + 右半灰度蒙版」的拼接素材，对真机截图做像素级判定——蒙版不透明区应显示对应象限的 RGB 颜色，透明区应透出下层红色垫层（`rgb(244,66,54)`）。

| 验收项 | 结果 |
| --- | --- |
| mode=1/2/3/4 只显示 RGB 内容，透明区透出下层 Widget | 通过。mode=1 时蒙版不透明区显示对应 RGB 颜色、其余透出红色垫层；mode=3（Alpha 在上半）时左半透出垫层、右半显示不透明内容，方向语义正确 |
| mode=0 行为与当前一致 | 通过。`textureId` 释放为 null，尺寸回到全幅拼接尺寸，画面直出 XComponent，无合成开销 |
| `getAlphaRenderMode()` 返回最近一次设置的值 | 通过。逐一点选 0/1/3 回读均一致 |
| 播放中切换 mode、`prepare` 前后设置 mode 均生效 | 通过。播放中切换即时生效；`prepare` 之前设置同样生效；`prepare` 之后调用走 surfaceId 延后重放 |
| 横竖屏下合成画面不错位 | 通过。竖屏（1320x2848）与横屏（2848x1320）下，不透明区均固定在同一方位，无翻转 / 拉伸 / 裁切 |

其他：播放稳定无崩溃；纹理持续出帧（`OHOSExternalTexture::MarkNewFrameAvailable` 序号递增）。

### 已知限制

- 上述横竖屏验证在 2in1 形态设备（HAD-W32）上完成，通过窗口旋转触发；**手机 / 平板的物理旋转建议自行复验一次**（2in1 桌面形态固定横屏，系统可能拒绝旋转请求）；
- HLS（.m3u8）源在部分设备的 AVPlayer 上不受支持（`CONTAINER_ERR` / 5400106），与 Alpha 渲染无关，属设备媒体内核格式能力差异。

## 其他能力差异

部分依赖阿里云播放器 SDK 原生能力的接口暂不支持。调用不支持的接口时，Dart 侧会抛出 `PlatformException(code: UNSUPPORTED)`，请 catch 后降级：

| 接口 | 状态 | 说明 |
| --- | --- | --- |
| `setRotateMode` / `getRotateMode` | 静默忽略 | 可通过外层 Widget `Transform.rotate` 实现 |
| `setMirrorMode` / `getMirrorMode` | 静默忽略 | 可通过外层 Widget `Transform` 实现 |
| `setVideoBackgroundColor` | 静默忽略 | 可通过容器 Widget 背景色实现 |
| `setOutputAudioChannel` | 静默忽略 | — |

## 播放控制行为说明（与 Android/iOS 对齐的修复）

- **stop 后可重新播放**：`stop()` 内部会 reset 并重新 setUrl + prepare（AVPlayer stop 后不允许直接 prepare），不会出现 5400102 状态错误；
- **播放完成后再次播放**：`play()` 在 completed 状态下自动 seek(0) 重新起播，进度条归零。
