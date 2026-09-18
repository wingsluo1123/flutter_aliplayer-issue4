# OpenHarmony (HarmonyOS) Adaptation Notes

This document describes the capabilities of the `flutter_aliplayer` plugin on OpenHarmony / HarmonyOS. The OHOS-side player is implemented with MediaKit `AVPlayer` (see `ohos/`), instead of the AliyunPlayer SDK used on Android / iOS.

## Transparent Video (Alpha Rendering) — Supported

Alpha rendering is now implemented on OHOS (issue #3, Texture path): AVPlayer outputs to an offscreen surface consumed by `OH_NativeImage`, an OpenGL ES shader composites the RGB half and the Alpha half according to the mode, and the composited frames are exposed to Flutter as an external texture via `TextureRegistry`. Transparent areas correctly show underlying Flutter widgets.

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
- Switching modes during playback takes effect immediately (shader uniform hot update);
- The video source must be an RGB+Alpha side-by-side (or stacked) stream matching the mode;
- `getVideoWidth/Height` and `onVideoSizeChanged` report the **composited (visible-content) size**. In half-frame modes (1/2 = left/right half, 3/4 = top/bottom half) this is half the original side-by-side size, consistent with the Android SDK semantics;
- `setScalingMode` scales against the composited half-frame size, not the original side-by-side size (FIT letterboxes / FILL crops / TO_FILL stretches);
- Device rotation: display size is calibrated via the `OH_NativeImage` transform matrix — under a 90/270 rotation the display width/height are swapped with the buffer dimensions before the aspect ratio is computed.

### Verified on device

- Composited frames render correctly; transparent areas show underlying Flutter widgets (verified with colored underlay experiments showing the alpha gradient is honored);
- Stable playback without crashes; switching modes during playback works;
- `setAlphaRenderMode` called after `prepare` also takes effect (deferred surfaceId replay);
- The texture keeps producing frames (`OHOSExternalTexture::MarkNewFrameAvailable` sequence increments).

### Known limitations

- Rotation calibration is implemented in source via the transform matrix; a **device rotation regression is still worth re-verifying** on your side;
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
