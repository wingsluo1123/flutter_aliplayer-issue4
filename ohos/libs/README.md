# 阿里云播放器 SDK 集成指南

本目录用于存放阿里云播放器鸿蒙 SDK（HAR 包）。

## 下载 SDK

1. 访问官方下载地址：
   ```
   https://alivc-demo-cms.alicdn.com/versionProduct/sdk/player/harmonyosnext/AliyunPlayer-7.14.0.har
   ```

2. 或访问官方文档获取最新版本：
   - [SDK 下载页面](https://help.aliyun.com/zh/vod/developer-reference/sdk-download)
   - [HarmonyOS SDK 发布日志](https://help.aliyun.com/zh/vod/developer-reference/harmonyos-player-sdk)

## 配置步骤

1. **下载 HAR 包**：
   - 下载 `AliyunPlayer-7.14.0.har`
   - 或选择其他版本（如 7.13.0、7.12.0 等）

2. **重命名并放入本目录**：
   ```bash
   # 下载后重命名为 premierlibrary.har
   mv AliyunPlayer-7.14.0.har premierlibrary.har
   
   # 放入 libs 目录
   mv premierlibrary.har ohos/libs/
   ```

3. **配置依赖**：
   
   在 `ohos/oh-package.json5` 中取消注释：
   ```json5
   "dependencies": {
     "premierlibrary": "file:./libs/premierlibrary.har"
   }
   ```

4. **更新导入语句**：
   
   在 ETS 文件中取消 `import` 语句的注释：
   ```typescript
   // 取消注释以启用阿里云 SDK
   import { AliPlayerFactory, AliPlayer, UrlSource, VidAuth, VidSts } from 'premierlibrary';
   ```

5. **更新 XComponent 配置**：
   
   在 `AliPlayerPlatformView.ets` 中取消 `libraryname` 的注释：
   ```typescript
   XComponent({
     type: XComponentType.SURFACE,
     controller: this.controller,
     libraryname: 'premierlibrary',  // 取消注释
     id: 'aliplayer_surface',
   })
   ```

## 版本说明

- **最新版本**: 7.15.0（2026-06-04）
- **与 Flutter 插件版本一致**: flutter_aliplayer 7.14.0（Flutter SDK 最新为 7.9.0）
- **支持功能**: 点播、直播、列表播放、时移播放、下载、预加载等

## 收费说明

⚠️ **重要提示**：播放器 SDK 7.0.0+ 已开启正式收费。

- **标准版**：基础播放功能
- **专业版**：增强功能（需购买 License）
- 新购买的移动端专业版 License 仅支持 7.0.0+ 版本
- 详细计费说明：https://help.aliyun.com/zh/vod/product-overview/billing-of-value-added-services#529f89bf7dkrv

## 官方文档

- [集成指南](https://help.aliyun.com/zh/vod/developer-reference/integrated-harmonyos-next-player-sdk)
- [快速开始](https://help.aliyun.com/zh/vod/developer-reference/quick-start-for-player-harmonyos-sdk)
- [API 参考](https://help.aliyun.com/zh/vod/developer-reference/harmonyos-player-sdk)
- [常见问题](https://help.aliyun.com/zh/vod/developer-reference/faq-about-apsaravideo-player-sdk-for-harmony)

## 验证集成

集成完成后，执行以下命令验证：

```bash
cd ohos
ohpm install
flutter build hap --debug
```

如果编译成功，说明 SDK 集成正确。