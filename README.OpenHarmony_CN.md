# OpenHarmony（鸿蒙）适配说明

本文档描述 `flutter_aliplayer` 插件在 OpenHarmony / HarmonyOS 平台的接入方式与能力边界。

鸿蒙侧使用阿里云官方 HarmonyOS 播放器 SDK `premierlibrary` 7.14.0，通过本插件保留现有 Flutter/Dart API 和 MethodChannel 协议。SDK HAR 位于 `ohos/libs/`，插件会通过 `ohos/oh-package.json5` 自动声明依赖，宿主应用不需要再次复制 HAR 或 native 库。

## License 要求

`flutter_aliplayer` 是基于阿里云播放器 SDK 的商业化插件。使用 HarmonyOS 官方播放器 SDK 前，宿主应用必须向阿里云申请有效的播放器 License；License 不是插件仓库提供的免费资源，也不能使用其他应用的 License 证书或 License key。

License 必须与宿主应用的 `bundleName` 匹配，并在宿主的 `entry/src/main/module.json5` 中配置：

```json5
"metadata": [
  {
    "name": "com.aliyun.alivc_license.licensekey",
    "value": "<YOUR_ALIYUN_PLAYER_LICENSE_KEY>"
  },
  {
    "name": "com.aliyun.alivc_license.licensefile",
    "value": "ohosLicense.crt"
  }
]
```

将阿里云签发的证书放到：

```text
entry/src/main/resources/rawfile/ohosLicense.crt
```

仓库中的 `example/ohos` 仅展示配置结构，License key 使用占位符，证书文件被 `.gitignore` 忽略。实际应用必须替换为自己的 License key 和证书；不能直接使用示例占位符，也不能把真实 License、证书或签名材料提交到代码仓库。

参考文档：

- [阿里云播放器 License 接入](https://help.aliyun.com/zh/vod/developer-reference/access-to-license)
- [HarmonyOS 播放器 SDK 集成指南](https://help.aliyun.com/zh/vod/developer-reference/integrated-harmonyos-next-player-sdk)
- [HarmonyOS 播放器 SDK 快速开始](https://help.aliyun.com/zh/vod/developer-reference/quick-start-for-player-harmonyos-sdk)

## HarmonyOS 应用签名

License 与 HarmonyOS 应用签名是两套独立配置：

- License 用于阿里云播放器 SDK 授权。
- `signingConfig` 用于允许 HAP 安装到真机。

使用 DevEco Studio 打开 `example/ohos`，在 Project Structure 的 Signing 页面配置本机调试签名，然后构建带签名的 HAP。未签名的 `entry-default-unsigned.hap` 不能直接安装到真实设备。

## 安装依赖与构建

使用 Flutter 示例工程：

```bash
cd example
flutter pub get
flutter build hap --debug
```

也可以使用 DevEco Studio 打开以下目录：

```text
example/ohos
```

构建前需要：

1. 在 `entry/src/main/module.json5` 配置宿主应用自己的 License。
2. 将对应的 `ohosLicense.crt` 放入 `entry/src/main/resources/rawfile/`。
3. 配置 DevEco 调试签名并为 `default` product 选择该签名。
4. 在 HarmonyOS 真机上验证播放、渲染、生命周期和网络行为。

## 透明视频与 AlphaRenderMode

官方播放器 SDK 已提供 Alpha 渲染能力，插件侧不再实现独立的 C++ Alpha 合成器。透明画面的合成由官方 SDK 完成，插件负责将播放器输出接入 Flutter 的 PlatformView。

官方 SDK 对 Alpha 渲染有两个关键要求：

- 显示视图必须使用 `XComponentType.TEXTURE`；官方文档明确指出，使用其他类型可能出现背景色，透明礼物动效无法正确透出。
- 应在 XComponent 的 `onLoad` 回调中调用 `setAlphaRenderMode`，然后调用 `setUrlDataSource`，并通过 `setSurfaceId(...)` 绑定输出 surface。

HarmonyOS 的 XComponent 是通过 Flutter PlatformView 嵌入 Flutter Widget 树的。`SURFACE` 类型输出属于原生 surface，不能按 Flutter Widget 的方式与下层 Flutter 内容进行透明合成；因此 Alpha 场景必须确认最终输出使用官方 SDK 要求的 `TEXTURE` 类型，并避免同时显示会覆盖 Texture 输出的原生 Surface 视图。

插件保留 Dart 侧的 Alpha API：

```dart
await player.setAlphaRenderMode(1);
final mode = await player.getAlphaRenderMode();
```

具体 Alpha 模式、素材格式、XComponent 类型和 surface 绑定顺序应以当前版本阿里云 HarmonyOS SDK 官方文档为准。若需要将官方 SDK 的合成结果直接输出到 Flutter `Texture(textureId: ...)`，还需要确认阿里云 SDK 是否允许把 Flutter TextureRegistry 生产者的 `surfaceId` 作为 `setSurfaceId` 参数，以及该 surface 是否满足 SDK 对 XComponent、像素格式和 buffer 生命周期的要求；当前插件未宣称这一点已经得到官方 SDK 支持。

## 当前支持的官方 SDK 桥接能力

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| 单播放器 | 支持 | 使用官方 HarmonyOS 播放器 SDK |
| 列表播放器 | 支持 | 保留现有 Flutter API 和事件协议 |
| 时移播放器 | 支持 | 使用官方 SDK 对应能力 |
| MediaLoader / MediaLoaderV2 | 支持 | 通过 MethodChannel 转发 |
| 下载器 | 支持 | 通过 MethodChannel 转发 |
| 全局设置 | 支持 | 通过 MethodChannel 转发 |
| AlphaRenderMode | 已桥接 | 具体透明合成效果依赖官方 SDK 的 Texture/XComponent 约束 |

部分只存在于 Android/iOS 原生 SDK 的接口在 HarmonyOS 上可能不支持。调用不支持的接口时，Dart 侧会收到 `PlatformException(code: UNSUPPORTED)`，应用应捕获并降级。

## 播放控制行为

- `stop()` 后可以重新播放：插件会按 HarmonyOS AVPlayer 状态要求重新设置 URL 并 prepare。
- 播放完成后再次 `play()`：插件会回到起始位置并重新播放。
- 真实设备验证必须使用有效 License、带签名的 HAP 和可访问的媒体地址；仅完成 ArkTS 编译不能代表播放器功能已验收。
