# OpenHarmony (HarmonyOS) Adaptation Notes

This document describes the capabilities of the `flutter_aliplayer` plugin on OpenHarmony / HarmonyOS. The OHOS-side player is implemented with MediaKit `AVPlayer` (see `ohos/`), instead of the AliyunPlayer SDK used on Android / iOS.

## Transparent Video (Alpha Rendering) — Supported

Alpha rendering is now implemented on OHOS (issue #3, Texture path): AVPlayer outputs to an offscreen surface consumed by `OH_NativeImage`, an OpenGL ES shader composites the RGB half and the Alpha half according to the mode, and the composited frames are exposed to Flutter as an external texture via `TextureRegistry`. Transparent areas correctly show underlying Flutter widgets.

> Why not XComponent + GLES: the XComponent's SURFACE is a native surface and, as verified on device, does not participate in Flutter's alpha compositing — transparent areas cannot reveal the underlying widget. Hence the Texture path.

Implementation files:

| File | Responsibility |
| --- | --- |
| `ohos/src/main/cpp/AlphaCompositeRenderer.cpp/.h` | Compositing core: half-frame split per mode, premultiplied-alpha shader, rotation calibration, scaling |
| `ohos/src/main/cpp/AlphaCompositorNapi.cpp` | NAPI exports: createRenderer / setMode / setVideoSize / setScalingMode / getComposedSize / getProducerSurfaceId / destroyRenderer |
| `ohos/types/libalpha_compositor/index.d.ts` | ArkTS type declarations |
| `ohos/src/main/ets/components/plugin/AliPlayerProxy.ets` | surfaceId replay, composited-size reporting, scaling forwarding |
| `ohos/src/main/ets/components/plugin/FlutterAliplayerPlugin.ets` | Method dispatch, textureId return, error return |

### Supported modes

| mode | Meaning |
| --- | --- |
| 0 | No alpha: AVPlayer renders directly to the XComponent surface (default path, zero overhead) |
| 1 | Alpha on the **right** (left half RGB + right half grayscale mask) |
| 2 | Alpha on the **left** |
| 3 | Alpha on the **top** |
| 4 | Alpha on the **bottom** |

### Usage (OHOS)

```dart
// mode 1-4: enable alpha compositing; returns textureId for the Texture widget
final ret = await player.setAlphaRenderMode(1);
final textureId = (ret as Map?)?['textureId'] as int?;
if (textureId != null && textureId > 0) {
  // Display the composited frames with a Texture widget (stackable over any widgets)
  Texture(textureId: textureId);
}

// mode 0: switch back to direct rendering (releases the compositing texture)
await player.setAlphaRenderMode(0);

// Query current mode
final mode = await player.getAlphaRenderMode(); // getAlPhaRenderMode legacy spelling also accepted
```

Notes:

- Call `setAlphaRenderMode(1-4)` after the render view is created (`onCreated`); it works both before and after `prepare` — if called after `prepared`, the surfaceId switch is replayed automatically once the state allows assignment, no manual retry needed;
- **In alpha mode you must hide `AliPlayerView` / `XComponent`**: the XComponent is a native SURFACE and does not participate in Flutter's alpha compositing. If shown together with the `Texture`, it covers the composited output and the transparent areas stop showing through. The usual pattern is to wrap `AliPlayerView` in `Visibility(visible: textureId == null)`;
- Switching modes during playback takes effect immediately (shader uniform hot update);
- The video source must be an RGB+Alpha side-by-side (or stacked) stream matching the mode;
- `getVideoWidth/Height` and `onVideoSizeChanged` report the **composited (visible-content) size**. In half-frame modes (1/2 = left/right half, 3/4 = top/bottom half) this is half the original side-by-side size, consistent with the Android SDK semantics;
- `setScalingMode` scales against the composited half-frame size, not the original side-by-side size (FIT letterboxes / FILL crops / TO_FILL stretches);
- Device rotation: display size is calibrated via the `OH_NativeImage` transform matrix — under a 90/270 rotation the display width/height are swapped with the buffer dimensions before the aspect ratio is computed.

### Verified on device (HAD-W32 / HarmonyOS 7.0.0.105 / API 26)

Method: a side-by-side asset of "left half = RGB quadrants of solid colors, right half = grayscale mask" was played, and device screenshots were judged pixel by pixel — opaque mask areas must show the corresponding RGB quadrant color, transparent areas must reveal the red underlay below (`rgb(244,66,54)`).

| Acceptance item | Result |
| --- | --- |
| mode=1/2/3/4 shows only RGB content; transparent areas reveal the underlying widget | Pass. With mode=1 the opaque mask area shows the corresponding RGB color while the rest reveals the red underlay; with mode=3 (alpha on the top half) the left half reveals the underlay and the right half shows opaque content — direction semantics correct |
| mode=0 keeps the previous behavior | Pass. `textureId` is released to null, the size returns to the full side-by-side size, and frames go straight out through the XComponent with no compositing cost |
| `getAlphaRenderMode()` returns the last value set | Pass. Read-back matched for every value selected (0/1/3) |
| Switching mode during playback, and setting mode before/after `prepare`, both work | Pass. Switching during playback takes effect immediately; setting before `prepare` also works; calling after `prepare` goes through the deferred surfaceId replay |
| Composited picture stays correctly oriented in portrait/landscape | Pass. In portrait (1320x2848) and landscape (2848x1320) the opaque area stays in the same position — no flip, stretch, or crop |

Other: stable playback without crashes; the texture keeps producing frames (`OHOSExternalTexture::MarkNewFrameAvailable` sequence increments).

### Known limitations

- The portrait/landscape verification above was done on a 2-in-1 form-factor device (HAD-W32) driven by window rotation; **physical rotation on phones/tablets is still worth re-verifying yourself** (a 2-in-1 desktop form factor is locked to landscape and the system may reject rotation requests);
- HLS (.m3u8) sources are not supported by AVPlayer on some devices (`CONTAINER_ERR` / 5400106) — a device media-kernel format limitation, unrelated to alpha rendering.

## Other Capability Differences

Some interfaces that rely on native AliyunPlayer SDK capabilities are not supported. Calling them throws `PlatformException(code: UNSUPPORTED)` on the Dart side; catch and degrade:

| Interface | Status | Notes |
| --- | --- | --- |
| `setRotateMode` / `getRotateMode` | Silently ignored | Use `Transform.rotate` on the wrapping Widget instead. |
| `setMirrorMode` / `getMirrorMode` | Silently ignored | Use `Transform` on the wrapping Widget instead. |
| `setVideoBackgroundColor` | Silently ignored | Set the background color of the container Widget instead. |
| `setOutputAudioChannel` | Silently ignored | — |

## Playback Control Behavior (aligned with Android/iOS)

- **Replay after stop**: `stop()` internally resets and re-sets the URL + prepares (AVPlayer disallows prepare right after stop), avoiding the 5400102 state error;
- **Replay after completion**: `play()` in the completed state automatically seeks to 0 and restarts, resetting the progress bar.
