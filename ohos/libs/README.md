# 阿里云播放器 HarmonyOS SDK

插件已通过本目录中的 `premierlibrary.har` 和
`aliyunPlayerSharedCpplibrary.har` 接入阿里云官方 HarmonyOS 播放器 SDK
7.14.0。`ohos/oh-package.json5` 已声明这两个本地依赖，无需宿主应用重复依赖
HAR 或复制其中的 native 库。

## 宿主应用配置

使用插件的 HarmonyOS 应用必须在 `entry/src/main/module.json5` 中配置与应用
`bundleName` 匹配的阿里云播放器 License：

```json5
"metadata": [
  {
    "name": "com.aliyun.alivc_license.licensekey",
    "value": "<license-key>"
  },
  {
    "name": "com.aliyun.alivc_license.licensefile",
    "value": "ohosLicense.crt"
  }
]
```

将对应的证书放到：

```text
entry/src/main/resources/rawfile/ohosLicense.crt
```

仓库中的 `example/ohos` 展示了宿主配置结构。实际应用必须替换为与自身
`bundleName` 匹配的 License，不能复用其他应用的证书和密钥。

## 构建

在 Flutter 示例目录解析依赖并构建：

```bash
cd example
flutter pub get
flutter build hap --debug
```

也可以用 DevEco Studio 打开 `example/ohos`，配置本机调试签名后运行 `entry`
模块。成功构建只能证明依赖和配置可解析；播放器功能仍需在 HarmonyOS 真机上
验证播放、渲染、切换轨道和生命周期行为。

## 官方文档

- [集成指南](https://help.aliyun.com/zh/vod/developer-reference/integrated-harmonyos-next-player-sdk)
- [快速开始](https://help.aliyun.com/zh/vod/developer-reference/quick-start-for-player-harmonyos-sdk)
- [SDK 下载](https://help.aliyun.com/zh/vod/developer-reference/sdk-download)