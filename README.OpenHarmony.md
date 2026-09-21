# OpenHarmony (HarmonyOS) Adaptation Notes

This document describes the capabilities and differences of the `flutter_aliplayer` plugin on OpenHarmony / HarmonyOS.

> **Architecture change (2026-09)**: the OHOS side now **bridges the official Aliyun HarmonyOS player SDK** (`premierlibrary`) instead of re-implementing Aliyun semantics on top of MediaKit `AVPlayer` — matching Android / iOS. The Dart-side MethodChannel protocol is unchanged, so integrators need no code changes.

## 1. License configuration is required (important)

The Aliyun player SDK is license-gated, and **a license is bound to the host app's `bundleName`**.

**The plugin ships as a HAR and cannot carry a license on your behalf** — every HarmonyOS app using this plugin must apply for and configure its own license, or the player will not work. This matches the license requirement on Android / iOS.

### 1.1 Apply

Get `license.crt` and a License Key following the official docs:

- [Manage License](https://help.aliyun.com/zh/apsara-video-sdk/license-authorization-and-management)
- [Obtain the Player SDK License](https://help.aliyun.com/zh/vod/developer-reference/obtain-the-player-sdk-license)

The **HarmonyOS BundleID** entered when creating the application must match the `bundleName` in your project's `AppScope/app.json5`.

### 1.2 Configure

**a. Put the certificate in `rawfile`**: `entry/src/main/resources/rawfile/license.crt`

**b. Add `metadata` to the host app's `entry/src/main/module.json5`** (keys must be all lowercase):

```json5
"metadata": [
  {
    "name": "com.aliyun.alivc_license.licensekey",
    "value": "your License Key"
  },
  {
    "name": "com.aliyun.alivc_license.licensefile",
    "value": "license.crt"
  }
]
```

Log lines indicating success:

```
(licenseManager) license init success
(alivc_license_certificate_validator.cpp) AppIdForLicense: <your bundleName>
```

> Note: a line `Cant not found LicenseKey ... with env` may appear *before* the success line. That is the initial probe failing against the default env and falling back to the explicit key — normal behaviour.

### 1.3 Add the official SDK HAR

The SDK is distributed as a HAR package; place it in the project and reference it with `file:`:

```json5
// ohos/oh-package.json5
"dependencies": {
  "premierlibrary": "file:./libs/premierlibrary.har"
}
```

> **`ohos/libs/` is not committed**: it holds Alibaba Cloud's commercial SDK binaries (about 4.7 MB) and
> is **not** part of this repository. After cloning you **must download it yourself** following the steps
> below, otherwise the build will fail with a missing dependency.

#### 1.3.1 Download the HAR

Download: [HarmonyOS Player SDK release notes](https://help.aliyun.com/zh/vod/developer-reference/harmonyos-player-sdk)

**Rename** the download to `premierlibrary.har` and put it in `ohos/libs/`:

```bash
mkdir -p ohos/libs
mv <downloaded-har-file> ohos/libs/premierlibrary.har
```

#### 1.3.2 Add `libc++_shared.so` (required)

The HAR's `libalivcffmpeg.so` depends on `libc++_shared.so`, but that library is **not inside the HAR**
(since 7.17.0 it is supplied by the integrator). Take a copy from the DevEco Studio NDK and place it in
`ohos/libs/arm64-v8a/`:

```bash
mkdir -p ohos/libs/arm64-v8a
cp "<DevEco-Studio>/sdk/default/openharmony/native/llvm/lib/aarch64-linux-ohos/libc++_shared.so" \
   ohos/libs/arm64-v8a/
```

Without this file the app fails at runtime with `Cannot read property JSBind of undefined`.

The resulting layout should be:

```
ohos/libs/
├── premierlibrary.har
└── arm64-v8a/
    └── libc++_shared.so
```

#### 1.3.3 Notes

- The HAR contains **`arm64-v8a` only** (no `x86_64`) → **a physical device is required; the emulator will not work**;
- The package on the official ohpm registry lags behind the website (website is at 7.17.0 while ohpm still serves 7.6.1), so **prefer downloading the HAR from the website and referencing it with `file:`**;
- The `entry` module must **declare `premierlibrary` itself** (ohpm does not pass dependencies through to consumers, so importing it directly from `entry` reports a missing module).

### 1.4 What happens when the license lapses (verified on device)

**Conclusion: a failed license check blocks playback** — `prepare()` fails and the player enters the error state.

Verified on device (HAD-W32 / API 26):

| Scenario | Result |
| --- | --- |
| Invalid LicenseKey + **valid built-in certificate** | ✅ **Playback still works** (the built-in certificate is what actually authorizes playback) |
| Invalid LicenseKey + **missing/corrupt built-in certificate** | ❌ **Playback blocked**, `onError code=1342242816` (Module=License, ModuleCode=4109) |

The blocking error message:

```
license authorization failed, detail errorMsg: Both Basic or Premium License verify failed;
unknow file type ;LicenseFile Passed is invalid, maybe wrong filePath/fileContent or
licenseFile not match the licenseKey; Please update the LicenseFile.
```

The player state callback reports `onStateChanged=7` (ERROR).

**The built-in certificate carries its own validity window** (visible in logs):

```
Premium LICENSE INFO: SignedTime: 2026-09-20 12:54:13, ExpiredTime: 2036-09-20 12:00:00, Version: Trial
```

**SDK license policy flags** (visible in logs; the SDK does not permit license-less use):

```
allowExpired: 0
canUseWithoutLicense: 0
not allowed UseWithoutLicense
```

**Practical advice:**

- **Always ship `license.crt` inside the package** — as measured, a valid built-in certificate keeps playback working even when the LicenseKey check fails; conversely, a missing/corrupt certificate stops playback outright;
- After renewing, **update `license.crt` as well** (per the official docs this improves authorization success; the LicenseKey stays the same);
- Handle error code `1342242816` (Module=License) in `setOnError` to degrade gracefully instead of showing a blank screen;
- Check the expiry date in the console: VOD console → SDK Management → My Authorizations → License Management → Validity Period.

> **Note**: the "lapse" above was reproduced with an **invalid/corrupt certificate** — internally the SDK takes the same rejection path for certificate expiry (`LicenseExpired` / `CertExpired` are both verification failures). A genuinely expired certificate was not tested, since we cannot issue one ourselves.

## 2. Transparent Video (Alpha Rendering) — Supported

Alpha compositing is **performed inside the official SDK** (`setAlphaRenderMode`); no custom compositor is needed.

### Supported modes

| mode | Meaning |
| --- | --- |
| 0 | No alpha (default) |
| 1 | Alpha on the **right** (left half RGB + right half grayscale mask) |
| 2 | Alpha on the **left** |
| 3 | Alpha on the **top** |
| 4 | Alpha on the **bottom** |

### Usage (OHOS)

```dart
// mode 1-4: enable alpha compositing
await player.setAlphaRenderMode(2);

// mode 0: disable
await player.setAlphaRenderMode(0);

// Query the current mode
final mode = await player.getAlphaRenderMode(); // getAlPhaRenderMode (legacy typo) also accepted
```

**Differences from the previous implementation (integrators should note):**

| Item | Before (custom compositor) | Now (official SDK) |
| --- | --- | --- |
| `setAlphaRenderMode` return value | Returned `{textureId}`; needed a `Texture` widget | **Returns `null`**; no `Texture` widget needed |
| Render surface | Switched to a Flutter texture in alpha mode; `AliPlayerView` had to be hidden | **Always the same XComponent**; nothing needs hiding |
| How frames are displayed | `Texture(textureId: ...)` | Just use `AliPlayerView` (same as normal playback) |

> **Migration note**: if your code contains `Texture(textureId: ...)` or `Visibility(visible: textureId == null)` workarounds, **remove them** — alpha and non-alpha playback now share one rendering path.

Other notes:

- Transparent areas correctly reveal underlying Flutter widgets (verified on device, see below);
- The media asset must use the RGB+Alpha split layout matching the selected mode;
- `getVideoWidth/Height` and `onVideoSizeChanged` report the official SDK's values, with the same semantics as Android / iOS.

### Verified on device (HAD-W32 / OpenHarmony 7.0.0.105 / API 26)

Asset: `split_5989.mp4` (1440×960, left half grayscale mask + right half color, corresponding to mode=2), with a solid red backing layer underneath.

| Acceptance item | Result |
| --- | --- |
| mode=0 has no transparency | Passed. Red coverage in the video area is 0%; frames render normally |
| modes 1-4 work and differ from each other | Passed. Red (backing layer) coverage in the video area was 37% / 22% / 46% / 36% respectively |
| Alpha result reveals underlying Flutter widgets | Passed. Switching the backing layer color (magenta ↔ cyan) inside a PlatformView changed the region color accordingly (64% ↔ 0%) |

## 3. Render surface implementation (migration notes)

The OHOS render surface is an `XComponent` carrying `libraryname: 'premierlibrary'`, and `setSurfaceId` takes **that XComponent's id string**.

Determined by single-variable comparison on device (choice of `setSurfaceId` argument):

| Argument passed | XComponent has `libraryname` | Same instance | Renders |
| --- | --- | --- | --- |
| XComponent **id string** | ✅ | yes | ✅ |
| XComponent **numeric surfaceId** | ✅ | yes | ❌ (reaches `state=3` but no frames) |
| Another XComponent's id string | ✅ | no | ✅ |
| Another XComponent's id string | ❌ | no | ❌ |

**Conclusion**: you must pass the id string of an XComponent that carries `libraryname: 'premierlibrary'`. It need not be the same XComponent instance, but `libraryname` is mandatory (the SDK's `.so` must load as that XComponent's native module so the component gets registered in the SDK's internal `XcomponentMap`).

Alpha additionally requires the render surface to be `XComponentType.TEXTURE` (per the official docs; a `SURFACE` component produces a background color).

### Why not the Flutter texture surface (TextureRegistry)

A common idea is to pass the **producer surfaceId** of a Flutter `TextureRegistry` texture directly to the
official `setSurfaceId`, so the SDK's composited output lands in a Flutter texture and can be displayed
with `Texture(textureId:)`.

**This does not work — the SDK silently ignores it** (verified on device, SDK 7.17.0):

| Check | Result |
| --- | --- |
| Can a real producer surfaceId be obtained | ✅ Yes (`getTextureId()` + `registerTexture()`, returns a non-zero value) |
| Does the official SDK accept that surfaceId | ❌ **No — and it does not report an error** |
| Does `onRenderingStart` fire | ❌ **0 times** |
| Frame pixels during playback | ❌ Two frames have **identical md5** (the picture is frozen) |

The SDK's internal log pinpoints the cause:

```
setSurfaceId(271746875785219)
NativeBase.cpp: ohos_SetSurfaceId()
NativeBase.cpp: uid is 271746875785219      ← the numeric surfaceId is looked up as a uid
(nothing further: neither "Get NativeWindow" nor "player setView")
```

The SDK treats the argument string as an **XComponentId** and looks it up in its internal
`XcomponentMap`. A numeric surfaceId has no entry there, so the function **returns immediately** —
it neither creates a native window nor sets the view, **and throws nothing**. This matches the SDK's
own interface comment (`IPlayer.d.ets`: `@param surfaceId：实际上是XComponentId。`).

Control experiment (same device, same asset, same process):

| Route | `onRenderingStart` | Two frames during playback |
| --- | --- | --- |
| XComponent id string (PlatformView) | ✅ fires | ❌ differ (**picture is moving**) |
| Flutter texture producer surfaceId | ❌ 0 times | ✅ identical (**picture is frozen**) |

> **Do not conflate**: `XComponentType.TEXTURE` (the ArkUI XComponent type — this is what the official
> Alpha requirement refers to) and Flutter `Texture` / `TextureRegistry` (the Flutter engine's texture
> registry) **are two different things**.

Note: the SDK's ArkTS layer **exposes no entry point that accepts a nativeWindow pointer** (searching
`nativeWindow` in the HAR's `.d.ets` yields nothing), so bypassing `surfaceId` by passing a window
pointer would require a new official API — the plugin side cannot implement it.

## 4. Playback control behaviour

- **Local file playback**: `file://` and sandbox absolute paths are supported (the latter is normalized to `file://`). Natively supported since official SDK 6.21.0 — no fd conversion needed;
- **Same-instance source switching**: `stop()` → `setUrl(newUrl)` → `prepare()` takes effect synchronously; no more silent failures from an async chain;
- **Replay after completion**: `play()` in the completed state automatically `seek(0)`s and restarts, resetting the progress bar;
- **Volume**: supports 0.0–2.0 (matching Aliyun semantics; no longer clamped to 1.0);
- **Speed**: supports floating point 0.5–5.0 (no longer mapped to a discrete enum).

## 5. Other capability differences

Some interfaces remain safe no-ops on OHOS. The Dart side may throw `PlatformException`; catch and degrade:

| Interface | Status | Notes |
| --- | --- | --- |
| `setRotateMode` / `getRotateMode` | Silently ignored | Use an outer `Transform.rotate` widget |
| `setMirrorMode` / `getMirrorMode` | Silently ignored | Use an outer `Transform` widget |
| `setVideoBackgroundColor` | Silently ignored | Use a container widget's background color |
| `setOutputAudioChannel` | Silently ignored | — |
| VidSts / VidAuth / VidMps | Not forwarded | Available in the official SDK; to be wired up on demand |
| Downloader / MediaLoaderV2 / local cache | Not forwarded | Available in the official SDK; to be wired up on demand |

## 6. Build environment requirements

| Item | Value |
| --- | --- |
| Flutter | 3.41.10-ohos-1.0.0 or later |
| Device | **Physical device** (arm64-v8a); the HAR has no x86_64, so the emulator will not work |
| Verified device | HAD-W32, OpenHarmony 7.0.0.105 (API 26) |
