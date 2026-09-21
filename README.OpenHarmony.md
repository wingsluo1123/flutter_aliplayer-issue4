# OpenHarmony / HarmonyOS Adaptation

This document describes how to integrate `flutter_aliplayer` on OpenHarmony / HarmonyOS and the current platform boundaries.

The HarmonyOS implementation uses Aliyun's official HarmonyOS player SDK, `premierlibrary` 7.14.0, while preserving the existing Flutter/Dart API and MethodChannel protocol. The SDK HAR files are stored under `ohos/libs/` and declared by `ohos/oh-package.json5`; host applications do not need to copy the HAR files or native libraries again.

## License Requirement

`flutter_aliplayer` is a commercial plugin based on the Aliyun player SDK. A host application must obtain a valid Aliyun player License before using the official HarmonyOS player SDK. The License is not a free resource supplied by this repository, and a License certificate or key issued for another application must not be reused.

The License must match the host application's `bundleName` and must be configured in the host `entry/src/main/module.json5`:

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

Place the certificate issued by Aliyun at:

```text
entry/src/main/resources/rawfile/ohosLicense.crt
```

`example/ohos` only demonstrates the configuration structure. The repository uses a placeholder License key and ignores the certificate file through `.gitignore`. A real application must replace the placeholder with its own License key and certificate. Real License material, certificates, and signing credentials must not be committed to the repository.

References:

- [Aliyun player License integration](https://help.aliyun.com/zh/vod/developer-reference/access-to-license)
- [HarmonyOS player SDK integration guide](https://help.aliyun.com/zh/vod/developer-reference/integrated-harmonyos-next-player-sdk)
- [HarmonyOS player SDK quick start](https://help.aliyun.com/zh/vod/developer-reference/quick-start-for-player-harmonyos-sdk)

## HarmonyOS Application Signing

The License and HarmonyOS application signing are independent configurations:

- The License authorizes the Aliyun player SDK.
- `signingConfig` allows a HAP to be installed on a real device.

Open `example/ohos` in DevEco Studio and configure a local debug signing profile from Project Structure > Signing. Then build a signed HAP. The unsigned `entry-default-unsigned.hap` cannot be installed directly on a real device.

## Dependency Installation and Build

From the Flutter example project:

```bash
cd example
flutter pub get
flutter build hap --debug
```

You can also open this directory in DevEco Studio:

```text
example/ohos
```

Before building:

1. Configure the host application's own License in `entry/src/main/module.json5`.
2. Place the matching `ohosLicense.crt` in `entry/src/main/resources/rawfile/`.
3. Configure a DevEco debug signing profile and select it for the `default` product.
4. Verify playback, rendering, lifecycle, and network behavior on a HarmonyOS device.

## Transparent Video and AlphaRenderMode

The official player SDK provides Alpha rendering. The plugin no longer implements an independent C++ Alpha compositor. Alpha compositing is performed by the official SDK; the plugin is responsible for connecting the player output to the Flutter PlatformView.

The official SDK has two important requirements for Alpha rendering:

- The display view must use `XComponentType.TEXTURE`. The official documentation states that other types may produce a background color and prevent transparent gift effects from showing correctly.
- Call `setAlphaRenderMode` in the XComponent `onLoad` callback, then call `setUrlDataSource`, and bind the output surface with `setSurfaceId(...)`.

An XComponent is embedded into the Flutter Widget tree through a Flutter PlatformView. A `SURFACE` output is a native surface and cannot participate in Flutter Widget compositing in the same way as Flutter content. Therefore, Alpha scenarios must use the `TEXTURE` output required by the official SDK and must not display a native Surface view that covers the Texture output.

The plugin keeps the Dart Alpha API:

```dart
await player.setAlphaRenderMode(1);
final mode = await player.getAlphaRenderMode();
```

The exact Alpha modes, asset format, XComponent type, and surface-binding order must follow the official documentation for the installed Aliyun HarmonyOS SDK version. To output the SDK's composited result directly into a Flutter `Texture(textureId: ...)`, it must first be confirmed that the Aliyun SDK accepts the Flutter TextureRegistry producer's `surfaceId` as the `setSurfaceId` argument and that this surface satisfies the SDK's XComponent, pixel-format, and buffer-lifetime requirements. The current plugin does not claim that this is officially supported or verified.

## Current Official SDK Bridge Coverage

| Capability | Status | Notes |
| --- | --- | --- |
| Single player | Supported | Uses the official HarmonyOS player SDK |
| List player | Supported | Preserves the existing Flutter API and event protocol |
| Live-shift player | Supported | Uses the corresponding official SDK capability |
| MediaLoader / MediaLoaderV2 | Supported | Forwarded through the MethodChannel |
| Downloader | Supported | Forwarded through the MethodChannel |
| Global settings | Supported | Forwarded through the MethodChannel |
| AlphaRenderMode | Bridged | Final transparency behavior depends on the official SDK's Texture/XComponent constraints |

Some interfaces that exist only in the Android/iOS native SDKs may not be supported on HarmonyOS. Unsupported calls return `PlatformException(code: UNSUPPORTED)` to Dart, and the application should catch and degrade gracefully.

## Playback Control Behavior

- `stop()` can be followed by another playback: the plugin resets the player according to the HarmonyOS AVPlayer state requirements, sets the URL again, and prepares it.
- Calling `play()` after completion seeks to the beginning and starts playback again.
- Real-device verification requires a valid License, a signed HAP, and an accessible media URL; successful ArkTS compilation alone does not constitute player acceptance.
