# OpenHarmony（鸿蒙）适配说明

本文档描述 `flutter_aliplayer` 插件在 OpenHarmony / HarmonyOS 平台的能力与差异。鸿蒙侧播放器基于 MediaKit `AVPlayer` 实现（见 `ohos/` 目录），替代 Android / iOS 使用的阿里云播放器 SDK。

## 透明通道视频渲染（AlphaRenderMode）— 已支持

鸿蒙侧已实现透明通道视频合成渲染（issue #3 问题一），采用 **Flutter Texture 路径**：AVPlayer 输出到离屏 surface，由 C++（EGL/GLES）shader 按模式采样 RGB 半区与 Alpha 半区合成，合成结果经 `TextureRegistry` 作为 Flutter 纹理输出——透明区域能正确透出下层 Flutter Widget。

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
- 播放中切换 mode 即时生效（shader uniform 热更新）；
- 视频源需为对应模式的 RGB+Alpha 拼接格式（如左半彩色内容 + 右半灰度蒙版）；
- `getVideoWidth/Height` 与 `onVideoSizeChanged` 返回的是**合成后（可见内容）尺寸**，半幅模式（1/2 取左右半、3/4 取上下半）为原始拼接尺寸的一半，与 Android SDK 语义一致；
- `setScalingMode` 的缩放基准是合成后的半幅尺寸，而非原始拼接尺寸（FIT 留黑边 / FILL 裁切 / TO_FILL 拉伸）；
- 横竖屏旋转：按 `OH_NativeImage` 的 transform 矩阵校准显示尺寸，旋转 90/270 时显示宽高与 buffer 宽高互换后参与宽高比计算。

### 已验证（真机）

- 合成画面正常渲染，透明区域正确透出下层 Widget（红/蓝底色垫层实验验证 alpha 渐变生效）；
- 播放稳定无崩溃；播放中设置 mode 生效；
- `setAlphaRenderMode` 在 `prepare` 之后调用同样生效（surfaceId 延后重放）；
- 纹理持续出帧（`OHOSExternalTexture::MarkNewFrameAvailable` 序号递增）。

### 已知限制

- 横竖屏旋转的校准逻辑基于 transform 矩阵实现，已在源码层面完成；**真机旋转回归仍建议自行复验一次**；
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
