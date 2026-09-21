# OpenHarmony（鸿蒙）适配说明

本文档描述 `flutter_aliplayer` 插件在 OpenHarmony / HarmonyOS 平台的能力与差异。

> **架构变更（2026-09）**：鸿蒙侧已从「基于 MediaKit `AVPlayer` 重新实现」改为**直接桥接阿里云官方 HarmonyOS 播放器 SDK**（`premierlibrary`），与 Android / iOS 侧一致。Dart 层 MethodChannel 协议未变，接入方无需改动。

## 一、必须配置 License（重要）

阿里云播放器 SDK 通过 License 授权，**License 与宿主应用的 `bundleName` 一一绑定**。

**插件是 HAR，无法替接入方携带 License** —— 每个使用本插件的鸿蒙应用都必须自行申请并配置，否则播放器无法工作。这与 Android / iOS 侧的 License 要求一致。

### 1. 申请

参考官方文档获取 `license.crt` 与 License Key：

- [管理 License](https://help.aliyun.com/zh/apsara-video-sdk/license-authorization-and-management)
- [获取播放器 SDK License](https://help.aliyun.com/zh/vod/developer-reference/obtain-the-player-sdk-license)

创建应用时填写的 **HarmonyOS BundleID** 必须与工程 `AppScope/app.json5` 的 `bundleName` 一致。

### 2. 配置

**a. 证书放到 `rawfile` 目录**：`entry/src/main/resources/rawfile/license.crt`

**b. 在宿主应用 `entry/src/main/module.json5` 添加 `metadata`**（key 必须全小写）：

```json5
"metadata": [
  {
    "name": "com.aliyun.alivc_license.licensekey",
    "value": "你的 License Key"
  },
  {
    "name": "com.aliyun.alivc_license.licensefile",
    "value": "license.crt"
  }
]
```

配置成功的日志特征：

```
(licenseManager) license init success
(alivc_license_certificate_validator.cpp) AppIdForLicense: <你的 bundleName>
```

> 注：日志中可能出现一行 `Cant not found LicenseKey ... with env`（在成功行之前），是首次按默认 env 探测失败后回退到显式 key，属正常流程。

### 3. 引入官方 SDK HAR

SDK 以 HAR 包分发，需放入工程并以 `file:` 引用：

```json5
// ohos/oh-package.json5
"dependencies": {
  "premierlibrary": "file:./libs/premierlibrary.har"
}
```

> **`ohos/libs/` 不入库**：该目录存放阿里云商业 SDK 二进制（约 4.7 MB），仓库中**不含**。
> 克隆本仓库后**必须按下方步骤自行下载放入**，否则构建会报找不到依赖。

#### 3.1 下载 HAR

下载地址：[HarmonyOS 播放器 SDK 发布日志](https://help.aliyun.com/zh/vod/developer-reference/harmonyos-player-sdk)

下载后**重命名**为 `premierlibrary.har`，放入 `ohos/libs/`：

```bash
mkdir -p ohos/libs
mv <下载的 HAR 文件> ohos/libs/premierlibrary.har
```

#### 3.2 补齐 `libc++_shared.so`（必需）

HAR 内的 `libalivcffmpeg.so` 依赖 `libc++_shared.so`，但该库**不在 HAR 内**（7.17.0 起由接入方提供）。
需从 DevEco Studio NDK 取一份，放入 `ohos/libs/arm64-v8a/`：

```bash
mkdir -p ohos/libs/arm64-v8a
cp "<DevEco-Studio>/sdk/default/openharmony/native/llvm/lib/aarch64-linux-ohos/libc++_shared.so" \
   ohos/libs/arm64-v8a/
```

缺少此文件时，运行时报 `Cannot read property JSBind of undefined`。

完成后目录结构应为：

```
ohos/libs/
├── premierlibrary.har
└── arm64-v8a/
    └── libc++_shared.so
```

#### 3.3 注意事项

- HAR 仅含 **`arm64-v8a`**（无 `x86_64`）→ **模拟器不可用，必须真机**；
- 官方 ohpm 仓库上的包版本落后于官网（官网已到 7.17.0，ohpm 上仍是 7.6.1），**建议直接下载官网 HAR 用 `file:` 引用**；
- `entry` 模块需**自行声明** `premierlibrary` 依赖（ohpm 不把依赖传递给消费方，直接在 `entry` 中 `import` 会报找不到模块）。

### 4. License 失效会怎样（真机实测）

**结论：License 校验失败会直接拦截播放**——`prepare()` 阶段即失败，播放器进入 error 状态。

实测（真机 HAD-W32 / API 26）：

| 场景 | 结果 |
| --- | --- |
| LicenseKey 无效 + **内置证书有效** | ✅ **仍能正常播放**（内置证书是实际生效的鉴权依据） |
| LicenseKey 无效 + **内置证书缺失/损坏** | ❌ **播放被拦截**，`onError code=1342242816`（Module=License，ModuleCode=4109） |

拦截时的错误信息：

```
license authorization failed, detail errorMsg: Both Basic or Premium License verify failed;
unknow file type ;LicenseFile Passed is invalid, maybe wrong filePath/fileContent or
licenseFile not match the licenseKey; Please update the LicenseFile.
```

播放器状态回调为 `onStateChanged=7`（ERROR）。

**内置证书自带有效期**（日志可查）：

```
Premium LICENSE INFO: SignedTime: 2026-09-20 12:54:13, ExpiredTime: 2036-09-20 12:00:00, Version: Trial
```

**SDK 的 License 策略开关**（日志可查，说明 SDK 不允许无证使用）：

```
allowExpired: 0
canUseWithoutLicense: 0
not allowed UseWithoutLicense
```

**实务建议**：

- **务必保留 `license.crt` 并打进包内**——实测内置证书有效时，即使 LicenseKey 校验不通过也能播放；反之证书缺失/损坏则直接停播；
- 续期后建议**同步更新 `license.crt`**（官方说明：可提高鉴权成功率；LicenseKey 不变）；
- 建议在 `setOnError` 中识别错误码 `1342242816`（Module=License），做降级提示而非白屏；
- 有效期以控制台为准：点播控制台 → SDK管理 → 我的授权 → License管理 → 有效日期。

> **说明**：上述「失效」用「无效/损坏证书」复现——它与「证书过期」在 SDK 内部走同一条拒绝路径（`LicenseExpired` / `CertExpired` 同属校验失败）。未实测真正过期的证书（无法自行签发）。

## 二、透明通道视频渲染（AlphaRenderMode）— 已支持

Alpha 透明合成**由官方 SDK 内部完成**（`setAlphaRenderMode`），无需自研合成器。

### 支持的模式

| mode | 含义 |
| --- | --- |
| 0 | 无 Alpha（默认） |
| 1 | Alpha 在画面**右侧**（左半 RGB + 右半灰度蒙版） |
| 2 | Alpha 在画面**左侧** |
| 3 | Alpha 在画面**上侧** |
| 4 | Alpha 在画面**下侧** |

### 用法（OHOS）

```dart
// mode=1-4: 开启 Alpha 透明合成
await player.setAlphaRenderMode(2);

// mode=0: 关闭
await player.setAlphaRenderMode(0);

// 查询当前模式
final mode = await player.getAlphaRenderMode(); // 兼容 getAlPhaRenderMode 历史拼写
```

**与旧实现的差异（接入方需注意）**：

| 项 | 旧实现（自研合成器） | 现在（官方 SDK） |
| --- | --- | --- |
| `setAlphaRenderMode` 返回值 | 返回 `{textureId}`，需用 `Texture` widget 显示 | **返回 `null`**，无需 `Texture` widget |
| 渲染面 | Alpha 模式切到 Flutter 纹理，需隐藏 `AliPlayerView` | **始终是同一个 XComponent**，无需隐藏任何视图 |
| 画面承载 | `Texture(textureId: ...)` | 直接用 `AliPlayerView`（即普通播放的写法） |

> **迁移要点**：如果你的代码里有 `Texture(textureId: ...)` 或 `Visibility(visible: textureId == null)` 这类适配，**应删除**——现在 Alpha 与非 Alpha 用同一套渲染代码。

注意事项：

- 透明区能正确透出下层 Flutter Widget（真机验证，见下）；
- 视频源需为对应模式的 RGB+Alpha 拼接格式；
- `getVideoWidth/Height` 与 `onVideoSizeChanged` 返回官方 SDK 的尺寸值，语义与 Android / iOS 一致。

### 已验证（真机 HAD-W32 / OpenHarmony 7.0.0.105 / API 26）

素材：`split_5989.mp4`（1440×960，左半灰度蒙版 + 右半彩色，对应 mode=2），下层铺纯红垫层。

| 验收项 | 结果 |
| --- | --- |
| mode=0 无透明 | 通过。视频区红色占比 0%，画面正常直出 |
| mode=1~4 透明生效且互不相同 | 通过。视频区红色（垫层）占比分别为 37% / 22% / 46% / 36% |
| Alpha 结果透出下层 Flutter Widget | 通过。PlatformView 内切换垫层颜色（品红 ↔ 青），区域颜色随之整体改变（64% ↔ 0%） |

## 三、渲染面实现说明（迁移要点）

鸿蒙侧渲染面是带 `libraryname: 'premierlibrary'` 的 `XComponent`，`setSurfaceId` 传的是**该 XComponent 的 id 字符串**。

经真机单变量对照实验确定（`setSurfaceId` 的入参选择）：

| 传入 | XComponent 带 `libraryname` | 是否同一实例 | 是否出画 |
| --- | --- | --- | --- |
| XComponent 的 **id 字符串** | ✅ | 是 | ✅ |
| XComponent 的**数字 surfaceId** | ✅ | 是 | ❌（只到 `state=3`，不出画） |
| 另一个 XComponent 的 id 字符串 | ✅ | 否 | ✅ |
| 另一个 XComponent 的 id 字符串 | ❌ | 否 | ❌ |

**结论**：必须传「带 `libraryname: 'premierlibrary'` 的 XComponent 的 id 字符串」；不要求是同一个 XComponent 实例，但 `libraryname` 是必需的（SDK 的 `.so` 需作为该 XComponent 的 native 模块加载，才会注册进内部 `XcomponentMap`）。

Alpha 场景额外要求渲染面为 `XComponentType.TEXTURE`（官方要求，`SURFACE` 型会有背景色）。

### 为什么不走 Flutter 纹理面（TextureRegistry）

一个常见设想是：把 Flutter `TextureRegistry` 纹理的 **producer surfaceId** 直接传给官方 `setSurfaceId`，
让 SDK 合成结果落进 Flutter 纹理，用 `Texture(textureId:)` 显示。

**这条路实测不通，SDK 会静默忽略**（真机验证，SDK 7.17.0）：

| 判据 | 结果 |
| --- | --- |
| 能否取到真实 producer surfaceId | ✅ 能（`getTextureId()` + `registerTexture()`，得到非 0 值） |
| 官方 SDK 是否接受该 surfaceId | ❌ **不接受，且不报错** |
| `onRenderingStart` 是否触发 | ❌ **0 次** |
| 播放期间画面像素 | ❌ 两帧 **md5 完全相同**（画面静止） |

SDK 内部日志可定位根因：

```
setSurfaceId(271746875785219)
NativeBase.cpp: ohos_SetSurfaceId()
NativeBase.cpp: uid is 271746875785219      ← 把数字 surfaceId 当 uid 去查
（到此为止：既无 "Get NativeWindow"，也无 "player setView"）
```

即 SDK 把入参字符串当作 **XComponentId** 去内部 `XcomponentMap` 查表；数字 surfaceId 查不到表项，
函数**直接返回**，既不创建 native window 也不设置 view——**且不抛错**。这与 SDK 接口注释一致
（`IPlayer.d.ets`：`@param surfaceId：实际上是XComponentId。`）。

对照实验（同设备、同素材、同一进程）：

| 路线 | `onRenderingStart` | 播放期间两帧 |
| --- | --- | --- |
| 传 XComponent id 字符串（PlatformView） | ✅ 触发 | ❌ 不同（**画面在动**） |
| 传 Flutter 纹理 producer surfaceId | ❌ 0 次 | ✅ 相同（**画面静止**） |

> **注意区分**：`XComponentType.TEXTURE`（ArkUI 的 XComponent 类型，官方 Alpha 要求的就是它）
> 与 Flutter `Texture` / `TextureRegistry`（Flutter 引擎的纹理注册表）**是两回事**。

补充：SDK 的 ArkTS 层**未暴露任何接收 nativeWindow 指针的入口**（HAR 的 `.d.ets` 中检索
`nativeWindow` 无结果），因此「绕过 surfaceId 直接传 window 指针」需要官方新增接口，插件侧无法自行实现。

## 四、播放控制行为说明

- **本地文件播放**：支持 `file://` 与沙箱绝对路径（后者会自动补 `file://` 前缀）。官方 SDK 6.21.0 起原生支持，无需转 fd；
- **同实例换源**：`stop()` → `setUrl(新地址)` → `prepare()` 同步生效，不再有异步链导致的静默失败；
- **播放完成后再次播放**：`play()` 在完成状态下自动 `seek(0)` 后重新起播，进度条归零；
- **音量**：支持 0.0~2.0（与阿里云语义一致，不再 clamp 到 1.0）；
- **倍速**：支持 0.5~5.0 浮点（不再映射到离散枚举）。

## 五、其他能力差异

部分接口在鸿蒙侧仍为安全空实现。调用时 Dart 侧可能抛出 `PlatformException`，请 catch 后降级：

| 接口 | 状态 | 说明 |
| --- | --- | --- |
| `setRotateMode` / `getRotateMode` | 静默忽略 | 可通过外层 Widget `Transform.rotate` 实现 |
| `setMirrorMode` / `getMirrorMode` | 静默忽略 | 可通过外层 Widget `Transform` 实现 |
| `setVideoBackgroundColor` | 静默忽略 | 可通过容器 Widget 背景色实现 |
| `setOutputAudioChannel` | 静默忽略 | — |
| VidSts / VidAuth / VidMps | 未转发 | 官方 SDK 已具备，待后续按需接入 |
| 下载器 / MediaLoaderV2 / 本地缓存 | 未转发 | 官方 SDK 已具备，待后续按需接入 |

## 六、构建环境要求

| 项 | 值 |
| --- | --- |
| Flutter | 3.41.10-ohos-1.0.0 及以上 |
| 设备 | **真机**（arm64-v8a）；HAR 无 x86_64，模拟器不可用 |
| 已验证设备 | HAD-W32，OpenHarmony 7.0.0.105（API 26） |
