/**
 * FlutterAliplayerPlugin
 *
 * 鸿蒙侧插件主入口, 实现:
 * - 5 个 MethodChannel: plugins.flutter_aliplayer_factory / flutter_alidownload /
 *   flutter_aliplayer_media_loader / flutter_aliplayer_loader_v2 / flutter_global_setting
 * - 4 个 EventChannel: flutter_aliplayer_event (主事件) + 3 个辅助事件流
 * - PlatformView: flutter_aliplayer_render_view (XComponent 渲染面)
 * - 多实例管理: 按 playerId 维护 AliPlayerProxy Map
 * - viewId ↔ surfaceId ↔ playerId 三向桥接
 *
 * 适配策略:
 * - P0 (已实现): 播放器生命周期/URL播放/播控/XComponent渲染/基础事件/缩放/音量/倍速/静音/循环
 * - P1 (部分实现): 轨道管理 getTrackDescription/selectTrack
 * - P3 (安全空实现): VidSts/VidAuth/VidMps/ARTC/DRM/FairPlay/HttpDNS/悬浮窗/下载/预加载等
 */
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  EventChannel,
  EventSink,
  StreamHandler,
  AbilityAware,
  AbilityPluginBinding,
  BinaryMessenger,
  TextureRegistry,
  SurfaceTextureEntry,
} from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AliPlayerProxy } from './AliPlayerProxy';
import { AliPlayerViewFactory, AliPlayerSurfaceRegistry, SurfaceIdCallback } from './AliPlayerViewFactory';

/** 实现类暴露的 NativeWindow 指针获取方法 (旧版接口未声明, 本地接口中转) */
interface NativeWindowPtrProvider {
  getNativeWindowPtr: () => bigint;
}

const LOG_DOMAIN: number = 0x0001;
const LOG_TAG: string = 'FlutterAliplayerPlugin';

// Channel 名称 (与 Dart 侧严格一致)
const CHANNEL_FACTORY: string = 'plugins.flutter_aliplayer_factory';
const CHANNEL_DOWNLOAD: string = 'plugins.flutter_alidownload';
const CHANNEL_MEDIA_LOADER: string = 'plugins.flutter_aliplayer_media_loader';
const CHANNEL_LOADER_V2: string = 'plugins.flutter_aliplayer_loader_v2';
const CHANNEL_GLOBAL_SETTING: string = 'plugins.flutter_global_setting';

const EVENT_PLAYER: string = 'flutter_aliplayer_event';
const EVENT_DOWNLOAD: string = 'plugins.flutter_alidownload_event';
const EVENT_MEDIA_LOADER: string = 'flutter_aliplayer_media_loader_event';
const EVENT_LOADER_V2: string = 'flutter_aliplayer_loader_v2_event';

const VIEW_TYPE: string = 'flutter_aliplayer_render_view';

/** 辅助 EventChannel 的空 StreamHandler */
class NoopStreamHandler implements StreamHandler {
  onListen(_args: Object, _events: EventSink): void {
    // 下载/预加载事件流在鸿蒙侧暂不支持, 仅保持监听不崩溃
  }
  onCancel(_args: Object): void {
    // no-op
  }
}

/** 下载/预加载 MethodChannel 的空 handler (P3 安全空实现)。
 *  这些通道的方法名 (prepare/start/stop/selectItem/setSaveDir 等) 与播放器方法名重叠,
 *  必须用独立 handler 处理, 否则会被主 switch 误路由到播放器逻辑。 */
class NoopMethodCallHandler implements MethodCallHandler {
  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s not supported on OHOS (P3 noop)', call.method);
    result.success(null);
  }
}

export default class FlutterAliplayerPlugin implements FlutterPlugin, MethodCallHandler, StreamHandler, AbilityAware {
  private messenger: BinaryMessenger | null = null;
  private context: common.Context | null = null;
  // Texture 路径 (Alpha 合成): mode≠0 时创建 Flutter 纹理, 合成画面经纹理透出下层 Widget
  private textureRegistry: TextureRegistry | null = null;
  private alphaTextureEntries: Map<string, SurfaceTextureEntry> = new Map();
  private alphaTextureIds: Map<string, number> = new Map();
  private uiContext: common.UIAbilityContext | null = null;

  // 主通道
  private factoryChannel: MethodChannel | null = null;
  private downloadChannel: MethodChannel | null = null;
  private mediaLoaderChannel: MethodChannel | null = null;
  private loaderV2Channel: MethodChannel | null = null;
  private globalSettingChannel: MethodChannel | null = null;

  // 事件通道
  private playerEventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;

  // 多实例管理
  private players: Map<string, AliPlayerProxy> = new Map();
  // viewId -> surfaceId (来自 XComponent onLoad)
  private viewIdToSurfaceId: Map<number, string> = new Map();
  // viewId -> playerId (来自 setPlayerView, 待 surfaceId 到达后桥接)
  private viewIdToPlayerId: Map<number, string> = new Map();

  getUniqueClassName(): string {
    return 'FlutterAliplayerPlugin';
  }

  /**
   * 获取引擎纹理的 OHNativeWindow* 指针字符串 (bigint 无损)。
   * getNativeWindowPtr 未在旧版 SurfaceTextureEntry 接口暴露, 经本地接口中转调用实现类方法。
   */
  private getNativeWindowPtrString(entry: SurfaceTextureEntry): string {
    const impl = entry as object as NativeWindowPtrProvider;
    return impl.getNativeWindowPtr().toString();
  }

  /**
   * 释放 playerId 关联的 Alpha 合成纹理。
   * 必须经 textureRegistry.unregisterTexture 注销 — 该引擎版本的
   * SurfaceTextureRegistryEntry.release() 是 `throw new Error('Method not implemented.')`,
   * 调用它会抛异常并中断后续清理 (mode 0 切不回直出)。
   * 纹理自身的 OHNativeWindow* 归引擎所有, unregisterTexture 即可, 无需手动释放。
   */
  private releaseAlphaTexture(playerId: string): void {
    const textureId = this.alphaTextureIds.get(playerId);
    this.alphaTextureEntries.delete(playerId);
    this.alphaTextureIds.delete(playerId);
    if (textureId === undefined || this.textureRegistry === null) {
      return;
    }
    try {
      this.textureRegistry.unregisterTexture(textureId);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'alpha texture released: textureId=%{public}d', textureId);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'unregister alpha texture %{public}d failed: %{public}s',
        textureId, (e as Error).message);
    }
  }

  /** 释放所有 Alpha 合成纹理 (engine detach / 批量清理) */
  private releaseAllAlphaTextures(): void {
    const playerIds: string[] = Array.from(this.alphaTextureIds.keys());
    for (const pid of playerIds) {
      this.releaseAlphaTexture(pid);
    }
  }

  // ============== FlutterPlugin 生命周期 ==============

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.messenger = binding.getBinaryMessenger();
    this.context = binding.getApplicationContext();
    // Texture 路径 (Alpha 合成)
    this.textureRegistry = binding.getTextureRegistry();

    // 注册 PlatformView Factory
    const surfaceCallback: SurfaceIdCallback = (viewId: number, surfaceId: string): void => {
      this.onSurfaceReady(viewId, surfaceId);
    };
    binding.getPlatformViewRegistry().registerViewFactory(VIEW_TYPE, new AliPlayerViewFactory(surfaceCallback));

    // 主 MethodChannel
    this.factoryChannel = new MethodChannel(this.messenger, CHANNEL_FACTORY);
    this.factoryChannel.setMethodCallHandler(this);

    // 辅助 MethodChannel: 下载/预加载使用独立 no-op handler (方法名与播放器重叠, 不能复用主 handler)
    const noopHandler = new NoopMethodCallHandler();
    this.downloadChannel = new MethodChannel(this.messenger, CHANNEL_DOWNLOAD);
    this.downloadChannel.setMethodCallHandler(noopHandler);
    this.mediaLoaderChannel = new MethodChannel(this.messenger, CHANNEL_MEDIA_LOADER);
    this.mediaLoaderChannel.setMethodCallHandler(noopHandler);
    this.loaderV2Channel = new MethodChannel(this.messenger, CHANNEL_LOADER_V2);
    this.loaderV2Channel.setMethodCallHandler(noopHandler);
    // 全局设置通道方法名不与播放器重叠, 可复用主 handler (均为 no-op)
    this.globalSettingChannel = new MethodChannel(this.messenger, CHANNEL_GLOBAL_SETTING);
    this.globalSettingChannel.setMethodCallHandler(this);

    // 主 EventChannel (共享 EventSink)
    this.playerEventChannel = new EventChannel(this.messenger, EVENT_PLAYER);
    this.playerEventChannel.setStreamHandler(this);

    // 辅助 EventChannel (空 StreamHandler)
    new EventChannel(this.messenger, EVENT_DOWNLOAD).setStreamHandler(new NoopStreamHandler());
    new EventChannel(this.messenger, EVENT_MEDIA_LOADER).setStreamHandler(new NoopStreamHandler());
    new EventChannel(this.messenger, EVENT_LOADER_V2).setStreamHandler(new NoopStreamHandler());

    hilog.info(LOG_DOMAIN, LOG_TAG, 'onAttachedToEngine ok');
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.factoryChannel?.setMethodCallHandler(null);
    this.factoryChannel = null;
    this.downloadChannel?.setMethodCallHandler(null);
    this.downloadChannel = null;
    this.mediaLoaderChannel?.setMethodCallHandler(null);
    this.mediaLoaderChannel = null;
    this.loaderV2Channel?.setMethodCallHandler(null);
    this.loaderV2Channel = null;
    this.globalSettingChannel?.setMethodCallHandler(null);
    this.globalSettingChannel = null;    this.playerEventChannel?.setStreamHandler(null);
    this.playerEventChannel = null;
    this.eventSink = null;

    // 释放所有播放器
    this.players.forEach((proxy: AliPlayerProxy, _key: string) => {
      proxy.release();
    });
    this.players.clear();
    // 释放所有 Alpha 合成纹理 (先于 textureRegistry 置空)
    this.releaseAllAlphaTextures();
    this.textureRegistry = null;
    this.viewIdToSurfaceId.clear();
    this.viewIdToPlayerId.clear();
    this.messenger = null;
    this.context = null;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onDetachedFromEngine ok');
  }

  // ============== AbilityAware 生命周期 ==============

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    const ability = binding.getAbility();
    if (ability !== null && ability !== undefined) {
      this.uiContext = ability.context as common.UIAbilityContext;
    }
  }

  onDetachedFromAbility(): void {
    this.uiContext = null;
  }

  // ============== StreamHandler (主 EventChannel) ==============

  onListen(_args: Object, events: EventSink): void {
    this.eventSink = events;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'EventChannel onListen');
  }

  onCancel(_args: Object): void {
    this.eventSink = null;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'EventChannel onCancel');
  }

  // ============== surface 桥接 ==============

  /** XComponent onLoad 回调: surfaceId 已就绪 */
  private onSurfaceReady(viewId: number, surfaceId: string): void {
    this.viewIdToSurfaceId.set(viewId, surfaceId);
    // 检查是否有 pending setPlayerView
    const playerId = this.viewIdToPlayerId.get(viewId);
    if (playerId !== undefined) {
      const proxy = this.players.get(playerId);
      if (proxy !== undefined) {
        proxy.setSurfaceId(surfaceId);
      }
    }
  }

  /** setPlayerView 调用: 绑定 viewId 到 playerId */
  private handleSetPlayerView(viewId: number, playerId: string): void {
    this.viewIdToPlayerId.set(viewId, playerId);
    const surfaceId = this.viewIdToSurfaceId.get(viewId);
    if (surfaceId !== undefined) {
      const proxy = this.players.get(playerId);
      if (proxy !== undefined) {
        proxy.setSurfaceId(surfaceId);
      }
    }
  }

  // ============== 事件下发 ==============

  /** 发送事件到共享 EventSink (供 AliPlayerProxy 回调) */
  sendEvent(data: Map<string, Object>): void {
    if (this.eventSink !== null) {
      this.eventSink.success(data);
    }
  }

  // ============== MethodCallHandler ==============

  onMethodCall(call: MethodCall, result: MethodResult): void {
    // 无参方法快速处理
    if (call.method === 'getSDKVersion') {
      result.success('flutter_aliplayer-ohos-1.0.0');
      return;
    }

    // 提取参数 (wrapWithPlayerId 模式: {arg, playerId})
    const args = call.args as Map<string, Object> | null;
    let playerId: string = '';
    let arg: Object | null = null;
    if (args !== null && args !== undefined) {
      const pid = args.get('playerId');
      if (pid !== undefined && pid !== null) {
        playerId = (pid as Object) as string;
      }
      const a = args.get('arg');
      if (a !== undefined) {
        arg = a as Object;
      }
    }

    switch (call.method) {
      // ====== 播放器创建/生命周期 ======
      case 'createAliPlayer':
        this.handleCreatePlayer(playerId, arg, result);
        break;
      case 'createAliListPlayer':
        this.handleCreatePlayer(playerId, arg, result);
        break;
      case 'createAliLiveShiftPlayer':
        this.handleCreatePlayer(playerId, arg, result);
        break;
      case 'destroy':
      case 'releaseAsync':
        this.handleRelease(playerId, result);
        break;

      // ====== 回调注册 (返回 success, 事件通过 BasicMessageChannel/EventChannel 下发) ======
      case 'setOnPrepare':
      case 'setOnRenderingStart':
      case 'setOnStateChanged':
      case 'setOnStreamSwitchedListener':
        result.success(null);
        break;

      // ====== 数据源 ======
      case 'setUrl':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setUrl(arg as string);
          result.success(null);
        });
        break;
      case 'switchStream':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setUrl(arg as string);
          result.success(null);
        });
        break;
      case 'setVidSts':
      case 'setVidAuth':
      case 'setVidMps':
      case 'setLiveSts':
      case 'updateLiveStsInfo':
        // Aliyun VOD 生态数据源需应用层解析为 URL, 鸿蒙侧 AVPlayer 不支持 vid 直接播放
        hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s not supported on OHOS (Aliyun VOD private)', call.method);
        result.success(null);
        break;

      // ====== 播控 ======
      case 'prepare':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.prepare();
          result.success(null);
        });
        break;
      case 'play':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.play();
          result.success(null);
        });
        break;
      case 'pause':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.pause();
          result.success(null);
        });
        break;
      case 'stop':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.stop();
          result.success(null);
        });
        break;
      case 'seekTo':
        this.handleSeekTo(playerId, arg, result);
        break;
      case 'setStartTime':
        // 起播位置, 鸿蒙侧近似为 seek (在 prepare 后执行)
        this.handleSetStartTime(playerId, arg, result);
        break;
      case 'clearScreen':
      case 'clearScreenSync':
        result.success(null);
        break;
      case 'snapshot':
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'snapshot not supported on OHOS (use AVImageGenerator separately)');
        result.success(null);
        break;
      case 'reload':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.reload();
          result.success(null);
        });
        break;

      // ====== 音量/倍速/静音/循环/自动播放 ======
      case 'setVolume':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setVolume((arg as Object) as number);
          result.success(null);
        });
        break;
      case 'getVolume':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getVolume());
        });
        break;
      case 'setSpeed':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setSpeed((arg as Object) as number);
          result.success(null);
        });
        break;
      case 'getSpeed':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getSpeed());
        });
        break;
      case 'setMuted':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setMuted((arg as Object) as boolean);
          result.success(null);
        });
        break;
      case 'isMuted':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.isMuted());
        });
        break;
      case 'setLoop':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setLoop((arg as Object) as boolean);
          result.success(null);
        });
        break;
      case 'isLoop':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.isLoop());
        });
        break;
      case 'setAutoPlay':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setAutoPlay((arg as Object) as boolean);
          result.success(null);
        });
        break;
      case 'isAutoPlay':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.isAutoPlay());
        });
        break;

      // ====== 渲染模式 ======
      case 'setScalingMode':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          proxy.setScalingMode((arg as Object) as number);
          result.success(null);
        });
        break;
      case 'getScalingMode':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getScalingMode());
        });
        break;
      case 'setPlayerView':
        this.handleSetPlayerView((arg as Object) as number, playerId);
        result.success(null);
        break;
      case 'setRotateMode':
      case 'getRotateMode':
      case 'setMirrorMode':
      case 'getMirrorMode':
      case 'setVideoBackgroundColor':
      case 'setOutputAudioChannel':
        // 旋转/镜像/背景色: AVPlayer 不支持, ArkUI transform 层可后续扩展
        result.success(null);
        break;
      case 'setAlphaRenderMode':
        // Alpha 渲染 (issue #3 问题一, Texture 路径):
        // mode=1-4 时创建 Flutter 纹理, 纹理 surface 作为合成目标,
        // 合成画面经纹理参与 Flutter 合成 — 透明区可透出下层 Widget。
        // 成功返回 textureId (Map: {textureId}), Dart 侧用 Texture widget 显示。
        // 失败返回 error 让 Dart 侧降级。
        // 注: 不用 notImplemented — 该响应在此引擎版本下会使 Dart 侧 await 挂起。
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          const mode = (arg as Object) as number;
          if (mode === 0) {
            // 切回直出: 先释放合成渲染器与纹理, 再把 AVPlayer 指回 XComponent surface
            if (proxy.setAlphaRenderMode(0)) {
              this.releaseAlphaTexture(playerId);
              result.success(null);
            } else {
              result.error('ALPHA_ERROR', 'setAlphaRenderMode(0) failed', null);
            }
            return;
          }
          if (this.textureRegistry === null) {
            result.error('ALPHA_ERROR', 'TextureRegistry unavailable', null);
            return;
          }
          try {
            let entry = this.alphaTextureEntries.get(playerId);
            let textureId = this.alphaTextureIds.get(playerId);
            if (entry === undefined || textureId === undefined) {
              textureId = this.textureRegistry.getTextureId();
              entry = this.textureRegistry.registerTexture(textureId);
              this.alphaTextureEntries.set(playerId, entry);
              this.alphaTextureIds.set(playerId, textureId);
              hilog.info(LOG_DOMAIN, LOG_TAG, 'alpha texture created: textureId=%{public}d', textureId);
            }
            const textureSurfaceId = entry.getSurfaceId().toString();
            // Texture 路径: 传引擎的 OHNativeWindow* 指针 (bigint 无损转字符串,
            // 避免 number 精度截断导致 EGL_BAD_NATIVE_WINDOW)。
            // 注: getNativeWindowPtr 未在旧版 SurfaceTextureEntry 接口暴露, 经反射式调用获取
            const nativeWindowPtr = this.getNativeWindowPtrString(entry);
            if (proxy.setAlphaRenderMode(mode, textureSurfaceId, nativeWindowPtr)) {
              const resultMap = new Map<string, Object>();
              resultMap.set('textureId', textureId);
              result.success(resultMap);
            } else {
              result.error('UNSUPPORTED',
                `AlphaRenderMode ${mode} is not supported on OHOS now`, null);
            }
          } catch (e) {
            result.error('ALPHA_ERROR', (e as Error).message, null);
          }
        },
        // player 不存在时报错, 避免 withProxy 静默 success(null) 掩盖问题
        (r: MethodResult): void => {
          r.error('PLAYER_NOT_FOUND', `player not found: ${playerId}`, null);
        });
        break;
      case 'getAlPhaRenderMode':
      case 'getAlphaRenderMode':
        // 返回当前生效的 Alpha 模式 (默认 0)。
        // 注: Dart 侧历史拼写为 getAlPhaRenderMode, 此处兼容两种拼写。
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getAlphaRenderMode());
        });
        break;

      // ====== 查询 ======
      case 'getVideoWidth':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getVideoWidth());
        });
        break;
      case 'getVideoHeight':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getVideoHeight());
        });
        break;
      case 'getVideoRotation':
        result.success(0);
        break;
      case 'getDuration':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getDuration());
        });
        break;
      case 'getCurrentPosition':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getCurrentPosition());
        });
        break;
      case 'getPlayedDuration':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getCurrentPosition());
        });
        break;
      case 'getCurrentUtcTime':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getCurrentPosition());
        });
        break;
      case 'getBufferedPosition':
        this.withProxy(playerId, result, (proxy: AliPlayerProxy): void => {
          result.success(proxy.getDuration());
        });
        break;
      case 'getCurrentDownloadSpeed':
        result.success(0);
        break;
      case 'getLocalCacheLoadedSize':
        result.success(0);
        break;

      // ====== 配置 ======
      case 'setConfig':
      case 'setPlayConfig':
      case 'setOption':
      case 'setMaxAccurateSeekDelta':
      case 'setFastStart':
      case 'enableHardwareDecoder':
      case 'setEnableHardwareDecoder':
      case 'enableDowngrade':
      case 'setFilterConfig':
      case 'updateFilterConfig':
      case 'setFilterInvalid':
      case 'setRenderFrameCallbackConfig':
        // AVPConfig 字段大多无鸿蒙对等, 静默忽略
        result.success(null);
        break;
      case 'getConfig':
      case 'getPlayConfig':
        result.success(new Map<string, Object>());
        break;

      // ====== 轨道管理 (P1) ======
      case 'getMediaInfo':
        this.handleGetMediaInfo(playerId, result);
        break;
      case 'getTrackDescription':
      case 'getCurrentTrack':
        this.handleGetTrackDescription(playerId, result);
        break;
      case 'selectTrack':
        this.handleSelectTrack(playerId, arg, result);
        break;
      case 'selectTrackByTrackType':
      case 'setDefaultBandWidth':
      case 'setDefaultResolution':
      case 'setDefaultAudioLanguage':
        result.success(null);
        break;

      // ====== 缓存/文件 ======
      case 'getCacheFilePath':
      case 'getCacheFilePathWithVid':
        result.success(null);
        break;

      // ====== 字幕 ======
      case 'addExtSubtitle':
      case 'selectExtSubtitle':
        result.success(null);
        break;

      // ====== 全局设置 / 下载 / 预加载 (P3 安全空实现) ======
      case 'initService':
      case 'initLicenseServiceForIOS':
      case 'showFloatViewForAndroid':
      case 'hideFloatViewForAndroid':
      case 'checkFloatViewPermission':
      case 'requestFloatViewPermission':
      case 'setFloatViewIcon':
      case 'setFloatViewUI':
      case 'loadRtsLibrary':
      case 'setGlobalEnvironment':
      case 'setOption_global':
      case 'disableCrashUpload':
      case 'enableEnhancedHttpDns':
      case 'setCacheUrlHashCallback':
      case 'setNetworkCallback':
      case 'setAdaptiveDecoderGetBackupURLCallback':
      case 'setSystemBrightness':
      case 'getSystemBrightness':
      case 'enableConsoleLog':
      case 'setLogLevel':
      case 'setLogOption':
      case 'getLogLevel':
      case 'setUseHttp2':
      case 'enableHttpDns':
      case 'setDNSResolve':
      case 'setIpResolveType':
      case 'setFairPlayCertIDForIOS':
      case 'enableHWAduioTempo':
      case 'forceAudioRendingFormat':
      case 'netWorkReConnect':
      case 'enableLocalCache':
      case 'setCacheFileClearConfig':
      case 'clearCaches':
      case 'enableNetworkBalance':
      case 'createDeviceInfo':
      case 'addBlackDevice':
      case 'createVidPlayerConfigGenerator':
      case 'setPreviewTime':
      case 'setHlsUriToken':
      case 'addVidPlayerConfigBy':
      case 'addVidPlayerConfigByStringValue':
      case 'addVidPlayerConfigByIntValue':
      case 'setEncryptType':
      case 'generatePlayerConfig':
      case 'setAudioSessionTypeForIOS':
      case 'setLogInfoCallBack':
      case 'setLogInfoBlock':
      case 'isFeatureSupport':
      case 'getDeviceUUID':
      case 'setPictureInPictureShowMode':
      case 'setPictureInPictureEnableForIOS':
      case 'setPreferPlayerName':
      case 'getPlayerName':
      case 'setPlayerScene':
      case 'setUserData':
      case 'getUserData':
      case 'setTraceID':
      case 'sendCustomEvent':
      case 'setStreamDelayTime':
      case 'getOption':
      case 'getPropertyString':
      case 'setEventReportParamsDelegate':
      case 'setPrivateService':
      case 'setDrmCallback':
      case 'setOnPreRenderFrameCallback':
      case 'setOnRenderFrameCallback':
      case 'setConvertURLCallback':
      case 'setOnURLSourceExpiredListener':
      case 'setOnVidAuthExpiredListener':
      case 'getCacheFilePathWithVidAtPreviewTime':
      case 'getSubMediaInfo':
      case 'createThumbnailHelper':
      case 'requestBitmapAtPosition':
        // 下载/预加载/全局设置/DRM/FairPlay/HttpDNS/双向回调/缩略图等为 Aliyun 私有能力或 iOS 专有, 鸿蒙侧安全空实现
        result.success(null);
        break;

      // ====== 下载器方法 ======
      case 'prepare_download':
      case 'start_download':
      case 'selectItem_download':
      case 'setSaveDir_download':
      case 'getFullSaveDir_download':
      case 'stop_download':
      case 'delete_download':
      case 'getFilePath_download':
      case 'release_download':
      case 'updateSource_download':
      case 'setDownloaderConfig_download':
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'download not supported on OHOS: %{public}s', call.method);
        result.success(null);
        break;

      // ====== 预加载方法 ======
      case 'load':
      case 'loadWithBandWidth':
      case 'resume':
      case 'pause':
      case 'cancel':
      case 'addTask':
      case 'addUrlTask':
      case 'addVidAuthTask':
      case 'addVidStsTask':
      case 'resumeTask':
      case 'pauseTask':
      case 'cancelTask':
      case 'getPreloadConfig':
      case 'setPreloadConfig':
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'media preload not supported on OHOS: %{public}s', call.method);
        result.success(null);
        break;

      default:
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'notImplemented: %{public}s', call.method);
        result.notImplemented();
        break;
    }
  }

  // ============== 方法处理辅助 ==============

  /** 安全获取 proxy 并执行操作 */
  private withProxy(
    playerId: string,
    result: MethodResult,
    action: (proxy: AliPlayerProxy) => void,
    onMissing?: (result: MethodResult) => void,
  ): void {
    const proxy = this.players.get(playerId);
    if (proxy === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'player not found: %{public}s', playerId);
      if (onMissing !== undefined) {
        onMissing(result);
        return;
      }
      result.success(null);
      return;
    }
    action(proxy);
  }

  /** 创建播放器 */
  private handleCreatePlayer(playerId: string, _arg: Object | null, result: MethodResult): void {
    if (playerId === null || playerId === undefined || playerId.length === 0) {
      result.error('INVALID_PLAYER_ID', 'playerId is empty', null);
      return;
    }
    if (this.messenger === null) {
      result.error('NO_MESSENGER', 'BinaryMessenger not available', null);
      return;
    }
    // 已存在则先释放
    const existing = this.players.get(playerId);
    if (existing !== undefined) {
      existing.release();
      this.players.delete(playerId);
    }
    // 复用同一 playerId 时清理旧纹理, 避免泄漏
    this.releaseAlphaTexture(playerId);
    const proxy = new AliPlayerProxy(playerId, this.messenger, (data: Map<string, Object>): void => {
      this.sendEvent(data);
    });
    this.players.set(playerId, proxy);
    proxy.create().then(() => {
      result.success(null);
    }).catch((e: Error) => {
      result.error('CREATE_FAILED', e.message, null);
    });
  }

  /** 释放播放器 */
  private handleRelease(playerId: string, result: MethodResult): void {
    const proxy = this.players.get(playerId);
    // 纹理清理与播放器是否存在无关, 避免残留纹理
    this.releaseAlphaTexture(playerId);
    if (proxy !== undefined) {
      proxy.release().then(() => {
        this.players.delete(playerId);
        result.success(null);
      }).catch(() => {
        this.players.delete(playerId);
        result.success(null);
      });
    } else {
      result.success(null);
    }
  }

  /** seekTo: arg 为 Map {position, seekMode} */
  private handleSeekTo(playerId: string, arg: Object | null, result: MethodResult): void {
    const proxy = this.players.get(playerId);
    if (proxy === undefined) {
      result.success(null);
      return;
    }
    let position: number = 0;
    let seekMode: number = 1;
    if (arg !== null && arg !== undefined) {
      const map = arg as Map<string, Object>;
      const pos = map.get('position');
      if (pos !== undefined && pos !== null) {
        position = (pos as Object) as number;
      }
      const mode = map.get('seekMode');
      if (mode !== undefined && mode !== null) {
        seekMode = (mode as Object) as number;
      }
    }
    proxy.seekTo(position, seekMode);
    result.success(null);
  }

  /** setStartTime: arg 为 Map {time, seekMode} */
  private handleSetStartTime(playerId: string, arg: Object | null, result: MethodResult): void {
    const proxy = this.players.get(playerId);
    if (proxy === undefined) {
      result.success(null);
      return;
    }
    let time: number = 0;
    let seekMode: number = 1;
    if (arg !== null && arg !== undefined) {
      const map = arg as Map<string, Object>;
      const t = map.get('time');
      if (t !== undefined && t !== null) {
        time = (t as Object) as number;
      }
      const mode = map.get('seekMode');
      if (mode !== undefined && mode !== null) {
        seekMode = (mode as Object) as number;
      }
    }
    // 起播位置: 在 prepare 后 seek
    proxy.seekTo(time, seekMode);
    result.success(null);
  }

  /** getMediaInfo: 返回简化媒体信息 */
  private handleGetMediaInfo(playerId: string, result: MethodResult): void {
    const proxy = this.players.get(playerId);
    if (proxy === undefined) {
      result.success(null);
      return;
    }
    proxy.getTrackDescription().then((tracks: Array<Object>) => {
      const info = new Map<string, Object>();
      info.set('duration', proxy.getDuration());
      info.set('tracks', tracks);
      info.set('title', '');
      info.set('coverURL', '');
      info.set('status', '');
      info.set('mediaType', '');
      info.set('transcodeMode', '');
      result.success(info);
    }).catch(() => {
      result.success(null);
    });
  }

  /** getTrackDescription */
  private handleGetTrackDescription(playerId: string, result: MethodResult): void {
    const proxy = this.players.get(playerId);
    if (proxy === undefined) {
      result.success(new Array<Object>());
      return;
    }
    proxy.getTrackDescription().then((tracks: Array<Object>) => {
      result.success(tracks);
    }).catch(() => {
      result.success(new Array<Object>());
    });
  }

  /** selectTrack */
  private handleSelectTrack(playerId: string, arg: Object | null, result: MethodResult): void {
    const proxy = this.players.get(playerId);
    if (proxy === undefined) {
      result.success(null);
      return;
    }
    let trackIndex: number = -1;
    if (arg !== null && arg !== undefined) {
      const map = arg as Map<string, Object>;
      // Dart 侧 selectTrack 传 {'trackIdx': trackIdx, 'accurate': accurate}
      const idx = map.get('trackIdx');
      if (idx !== undefined && idx !== null) {
        trackIndex = (idx as Object) as number;
      } else {
        // 兼容直接传 int 的情况
        trackIndex = (arg as Object) as number;
      }
    }
    proxy.selectTrack(trackIndex).then(() => {
      result.success(null);
    }).catch(() => {
      result.success(null);
    });
  }
}
