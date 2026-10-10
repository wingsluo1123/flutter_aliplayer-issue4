/**
 * flutter_aliplayer 鸿蒙适配主入口
 * 
 * 本插件基于阿里云播放器鸿蒙 SDK 实现，支持：
 * - 多播放器实例管理（单播放器、列表播放器、直播时移播放器）
 * - 视频渲染（PlatformView + XComponent）
 * - MethodChannel/EventChannel/BasicMessageChannel 多通信模式
 * - 视频下载、媒体预加载、全局设置
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
  BinaryMessenger,
  AbilityAware,
  AbilityPluginBinding,
} from '@ohos/flutter_ohos';

import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AliPlayerViewFactory } from './AliPlayerViewFactory';
import { AliPlayerInstanceManager } from './AliPlayerInstanceManager';
import { AliDownloaderPlugin } from './AliDownloaderPlugin';
import { AliMediaLoaderPlugin } from './AliMediaLoaderPlugin';
import { AliMediaLoaderV2Plugin } from './AliMediaLoaderV2Plugin';
import { AliGlobalSettingsPlugin } from './AliGlobalSettingsPlugin';
import { AliLiveShiftPlayerInstance } from './AliLiveShiftPlayerInstance';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';

/**
 * 主插件入口 - 注册所有 Channel 和 PlatformView
 */
export default class FlutterAliplayerPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  // MethodChannel: 播放器工厂通道
  private factoryChannel: MethodChannel | null = null;
  
  // EventChannel: 播放事件流
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  
  // UIAbilityContext（用于权限申请、画中画等）
  private abilityContext: common.UIAbilityContext | null = null;
  
  // BinaryMessenger（用于创建子 Channel）
  private messenger: BinaryMessenger | null = null;
  
  // ApplicationContext
  private applicationContext: common.Context | null = null;
  
  // 播放器实例管理器
  private instanceManager: AliPlayerInstanceManager | null = null;
  
  // 子插件
  private downloaderPlugin: AliDownloaderPlugin | null = null;
  private mediaLoaderPlugin: AliMediaLoaderPlugin | null = null;
  private mediaLoaderV2Plugin: AliMediaLoaderV2Plugin | null = null;
  private globalSettingsPlugin: AliGlobalSettingsPlugin | null = null;

  getUniqueClassName(): string {
    return 'FlutterAliplayerPlugin';
  }

  /**
   * FlutterPlugin 生命周期 - 插件挂载到引擎
   */
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onAttachedToEngine');
    console.info('[FlutterAliplayer] onAttachedToEngine');
    
    // native 库由 XComponent(libraryname: 'premierlibrary') 自动加载
    
    this.applicationContext = binding.getApplicationContext();
    this.messenger = binding.getBinaryMessenger();
    
    // 初始化播放器实例管理器
    this.instanceManager = new AliPlayerInstanceManager(this.messenger!, this.applicationContext!);
    
    // 注册 PlatformView Factory（Android viewType）
    binding.getPlatformViewRegistry()
      .registerViewFactory('flutter_aliplayer_render_view', new AliPlayerViewFactory(this.instanceManager!));
    
    // 注册 iOS viewType（与 Android viewType 共用同一个 Factory）
    binding.getPlatformViewRegistry()
      .registerViewFactory('plugins.flutter_aliplayer', new AliPlayerViewFactory(this.instanceManager!));
    
    // 注册播放器工厂 MethodChannel
    this.factoryChannel = new MethodChannel(this.messenger!, 'plugins.flutter_aliplayer_factory');
    this.factoryChannel.setMethodCallHandler(this);
    
    // 注册播放事件 EventChannel
    this.eventChannel = new EventChannel(this.messenger!, 'flutter_aliplayer_event');
    this.eventChannel.setStreamHandler(this);
    
    // 初始化子插件
    this.downloaderPlugin = new AliDownloaderPlugin(this.messenger!, this.applicationContext!);
    this.mediaLoaderPlugin = new AliMediaLoaderPlugin(this.messenger!, this.applicationContext!);
    this.mediaLoaderV2Plugin = new AliMediaLoaderV2Plugin(this.messenger!, this.applicationContext!);
    this.globalSettingsPlugin = new AliGlobalSettingsPlugin(this.messenger!, this.applicationContext!);
  }

  /**
   * FlutterPlugin 生命周期 - 插件从引擎卸载
   */
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onDetachedFromEngine');
    
    // 清理播放器实例
    if (this.instanceManager !== null) {
      this.instanceManager.releaseAll();
      this.instanceManager = null;
    }
    
    // 清理 Channel
    if (this.factoryChannel !== null) {
      this.factoryChannel.setMethodCallHandler(null);
      this.factoryChannel = null;
    }
    
    if (this.eventChannel !== null) {
      this.eventChannel.setStreamHandler(null);
      this.eventChannel = null;
      this.eventSink = null;
    }
    
    // 清理子插件
    if (this.downloaderPlugin !== null) {
      this.downloaderPlugin.release();
      this.downloaderPlugin = null;
    }
    
    if (this.mediaLoaderPlugin !== null) {
      this.mediaLoaderPlugin.release();
      this.mediaLoaderPlugin = null;
    }
    
    if (this.mediaLoaderV2Plugin !== null) {
      this.mediaLoaderV2Plugin.release();
      this.mediaLoaderV2Plugin = null;
    }
    
    if (this.globalSettingsPlugin !== null) {
      this.globalSettingsPlugin.release();
      this.globalSettingsPlugin = null;
    }
    
    this.messenger = null;
    this.applicationContext = null;
  }

  /**
   * AbilityAware 生命周期 - 获取 UIAbilityContext
   */
  onAttachedToAbility(binding: AbilityPluginBinding): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onAttachedToAbility');
    const ability = binding.getAbility();
    if (ability !== null && ability !== undefined) {
      this.abilityContext = ability.context as common.UIAbilityContext;
    }
  }

  /**
   * AbilityAware 生命周期 - 释放 UIAbilityContext
   */
  onDetachedFromAbility(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onDetachedFromAbility');
    this.abilityContext = null;
  }

  /**
   * EventChannel StreamHandler - 开始监听事件流
   */
  onListen(args: Object, events: EventSink): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'EventChannel onListen');
    this.eventSink = events;
    if (this.instanceManager !== null) {
      this.instanceManager.setEventSink(events);
    }
  }

  /**
   * EventChannel StreamHandler - 取消监听事件流
   */
  onCancel(args: Object): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'EventChannel onCancel');
    this.eventSink = null;
    if (this.instanceManager !== null) {
      this.instanceManager.setEventSink(null);
    }
  }

  /**
   * MethodChannel 处理器 - 处理播放器工厂方法
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    console.info('[FlutterAliplayer] onMethodCall method=' + call.method);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'onMethodCall method=%{public}s', call.method);
    
    const args = call.args as Map<string, Object> | null;
    
    switch (call.method) {
      case 'createAliPlayer':
        this.createAliPlayer(args, result);
        break;
      case 'createAliListPlayer':
        this.createAliListPlayer(args, result);
        break;
      case 'createAliLiveShiftPlayer':
        this.createAliLiveShiftPlayer(args, result);
        break;
      case 'destroy':
        this.destroyPlayer(args, result);
        break;
      case 'releaseAsync':
        this.releaseAsyncPlayer(args, result);
        break;
        
      case 'prepare':
        this.preparePlayer(args, result);
        break;
      case 'play':
        this.playPlayer(args, result);
        break;
      case 'pause':
        this.pausePlayer(args, result);
        break;
      case 'stop':
        this.stopPlayer(args, result);
        break;
      case 'reload':
        this.reloadPlayer(args, result);
        break;
      case 'seekTo':
        this.seekToPlayer(args, result);
        break;
      case 'setStartTime':
        this.setStartTime(args, result);
        break;
      case 'setMaxAccurateSeekDelta':
        this.setMaxAccurateSeekDelta(args, result);
        break;
      case 'setSpeed':
        this.setSpeed(args, result);
        break;
      case 'setLoop':
        this.setLoop(args, result);
        break;
      case 'setAutoPlay':
        this.setAutoPlay(args, result);
        break;
      case 'setFastStart':
        this.setFastStart(args, result);
        break;
      case 'setEnableHardwareDecoder':
        this.setEnableHardwareDecoder(args, result);
        break;
        
      // === 播放源设置 ===
      case 'setUrl':
        this.setUrl(args, result);
        break;
      case 'setVidSts':
        this.setVidSts(args, result);
        break;
      case 'setVidAuth':
        this.setVidAuth(args, result);
        break;
      case 'setVidMps':
        this.setVidMps(args, result);
        break;
      case 'setLiveSts':
        this.setLiveSts(args, result);
        break;
      case 'setDataSource':
        this.setDataSource(args, result);
        break;
        
      // === 音量控制 ===
      case 'setVolume':
        this.setVolume(args, result);
        break;
      case 'getVolume':
        this.getVolume(args, result);
        break;
      case 'setMuted':
        this.setMuted(args, result);
        break;
      case 'isMuted':
        this.isMuted(args, result);
        break;
        
      // === 视频信息获取 ===
      case 'getVideoWidth':
        this.getVideoWidth(args, result);
        break;
      case 'getVideoHeight':
        this.getVideoHeight(args, result);
        break;
      case 'getDuration':
        this.getDuration(args, result);
        break;
      case 'getCurrentPosition':
        this.getCurrentPosition(args, result);
        break;
      case 'getMediaInfo':
        this.getMediaInfo(args, result);
        break;
        
      // === 视频渲染 ===
      case 'setPlayerView':
        this.setPlayerView(args, result);
        break;
      case 'setScalingMode':
        this.setScalingMode(args, result);
        break;
      case 'getScalingMode':
        this.getScalingMode(args, result);
        break;
      case 'setRotateMode':
        this.setRotateMode(args, result);
        break;
      case 'setMirrorMode':
        this.setMirrorMode(args, result);
        break;
      case 'getAlPhaRenderMode':
        this.getAlphaRenderMode(args, result);
        break;
      case 'setAlphaRenderMode':
        this.setAlphaRenderMode(args, result);
        break;
      case 'setVideoBackgroundColor':
        this.setVideoBackgroundColor(args, result);
        break;

      // === 清晰度切换 ===
      case 'selectTrack':
        this.selectTrack(args, result);
        break;
      case 'switchStream':
        this.switchStream(args, result);
        break;
      case 'setDefaultBandWidth':
        this.setDefaultBandWidth(args, result);
        break;
      case 'setDefaultResolution':
        this.setDefaultResolution(args, result);
        break;
        
      // === 全局设置 ===
      case 'getSDKVersion':
        result.success('7.14.0');
        break;
      case 'setLogLevel':
        this.setLogLevel(call.args, result);
        break;
      case 'enableConsoleLog':
        this.enableConsoleLog(call.args, result);
        break;
      case 'netWorkReConnect':
        this.netWorkReConnect(result);
        break;

      // === 全局缓存 / 网络设置: Dart 经 factory channel 下发, 原生实现在 AliGlobalSettingsPlugin;
      //     factory 持有其实例, 转发过去 (issue #5: 缺少转发导致 MissingPluginException)。
      //     setUseHttp2 与前 6 个同源 (issue 未列出但同款缺陷), 一并转发。 ===
      case 'enableLocalCache':
      case 'setCacheFileClearConfig':
      case 'clearCaches':
      case 'enableHttpDns':
      case 'setDNSResolve':
      case 'enableNetworkBalance':
      case 'setUseHttp2':
        if (this.globalSettingsPlugin !== null) {
          this.globalSettingsPlugin.onMethodCall(call, result);
        } else {
          result.error('GLOBAL_SETTINGS_UNAVAILABLE', 'AliGlobalSettingsPlugin not initialized', null);
        }
        break;
        
      // === Android 专属功能（OHOS 不支持） ===
      case 'showFloatViewForAndroid':
      case 'hideFloatViewForAndroid':
      case 'checkFloatViewPermission':
      case 'requestFloatViewPermission':
      case 'setFloatViewIcon':
      case 'setFloatViewUI':
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Android-only method: %{public}s', call.method);
        result.success(false);
        break;
        
      // === RTS/ARTC SDK 加载 ===
      case 'loadRtsLibrary':
        this.loadRtsLibrary(args, result);
        break;
        
      // === 其他功能 ===
      case 'snapshot':
        this.snapshot(args, result);
        break;
      case 'addExtSubtitle':
        this.addExtSubtitle(args, result);
        break;
      case 'selectExtSubtitle':
        this.selectExtSubtitle(args, result);
        break;
      case 'setConfig':
        this.setPlayerConfig(args, result);
        break;
      case 'setPlayConfig':
        this.setPlayerConfig(args, result);
        break;
      case 'getConfig':
        this.getPlayerConfig(args, result);
        break;
      case 'getPlayConfig':
        this.getPlayConfig(args, result);
        break;
        
      // === 缩略图功能 ===
      case 'createThumbnailHelper':
        this.createThumbnailHelper(args, result);
        break;
      case 'requestBitmapAtPosition':
        this.requestBitmapAtPosition(args, result);
        break;
        
      // === 鉴权过期回调 ===
      case 'setOnURLSourceExpiredListener':
        this.setOnURLSourceExpiredListener(args, result);
        break;
      case 'setOnVidAuthExpiredListener':
        this.setOnVidAuthExpiredListener(args, result);
        break;
      case 'setOnPrepare':
      case 'setOnRenderingStart':
      case 'setOnStateChanged':
      case 'setOnStreamSwitchedListener':
        result.success(null);
        break;
        
      // === 列表播放器方法 ===
      case 'addUrlSource':
        this.addUrlSource(args, result);
        break;
      case 'moveTo':
        this.moveTo(args, result);
        break;
      case 'moveToNext':
        this.moveToNext(args, result);
        break;
      case 'moveToPre':
        this.moveToPre(args, result);
        break;
      case 'getCurrentUid':
        this.getCurrentUid(args, result);
        break;
      case 'clear':
        this.clearPlaylist(args, result);
        break;
      case 'removeSource':
        this.removeSource(args, result);
        break;
        
      // === 直播时移播放器方法 ===
      case 'setLiveShiftDataSource':
        this.setLiveShiftDataSource(args, result);
        break;
      case 'seekToLiveTime':
        this.seekToLiveTime(args, result);
        break;
      case 'getCurrentLiveTime':
        this.getCurrentLiveTime(args, result);
        break;
      case 'getCurrentTime':
        this.getCurrentTime(args, result);
        break;
        
      // === 未实现功能 ===
      default:
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Method not implemented: %{public}s', call.method);
        result.notImplemented();
        break;
    }
  }

  // === 播放器创建方法 ===

  private createAliPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    const playerType = args?.get('arg') as number ?? 0;
    console.info('[FlutterAliplayer] createAliPlayer playerId=' + playerId + ', type=' + playerType);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'createAliPlayer playerId=%{public}s, type=%{public}d', playerId, playerType);
    
    if (this.instanceManager === null) {
      console.error('[FlutterAliplayer] Instance manager not initialized');
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    try {
      let typeStr: string = 'single';
      if (playerType === 1) {
        typeStr = 'list';
      } else if (playerType === 2) {
        typeStr = 'liveShift';
      }
      this.instanceManager.createPlayer(playerId, typeStr);
      const response = new Map<string, Object>();
      response.set('playerId', playerId);
      result.success(response);
      console.info('[FlutterAliplayer] createAliPlayer success, type=' + typeStr);
    } catch (err) {
      const error = err as Error;
      console.error('[FlutterAliplayer] createAliPlayer failed: ' + error.message);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'createAliPlayer failed: %{public}s', error.message);
      result.error('CREATE_FAILED', error.message, null);
    }
  }

  private createAliListPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'createAliListPlayer playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    try {
      this.instanceManager.createPlayer(playerId, 'list');
      const response = new Map<string, Object>();
      response.set('playerId', playerId);
      result.success(response);
    } catch (err) {
      const error = err as Error;
      result.error('CREATE_FAILED', error.message, null);
    }
  }

  private createAliLiveShiftPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'createAliLiveShiftPlayer playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    try {
      this.instanceManager.createPlayer(playerId, 'liveShift');
      const response = new Map<string, Object>();
      response.set('playerId', playerId);
      result.success(response);
    } catch (err) {
      const error = err as Error;
      result.error('CREATE_FAILED', error.message, null);
    }
  }

  private destroyPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'destroyPlayer playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    try {
      this.instanceManager.destroyPlayer(playerId);
      result.success(null);
    } catch (err) {
      const error = err as Error;
      result.error('DESTROY_FAILED', error.message, null);
    }
  }

  /**
   * 异步释放播放器。释放后该实例不能再用于起播，所以和 destroy 一样从管理器中摘掉。
   */
  private releaseAsyncPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'releaseAsyncPlayer playerId=%{public}s', playerId);

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    try {
      this.instanceManager.destroyPlayerAsync(playerId);
      result.success(null);
    } catch (err) {
      const error = err as Error;
      result.error('RELEASE_ASYNC_FAILED', error.message, null);
    }
  }

  // === 播放控制方法 ===

  private preparePlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'prepare playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.prepare();
    result.success(null);
  }

  private playPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'play playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.play();
    result.success(null);
  }

  private pausePlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'pause playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.pause();
    result.success(null);
  }

  private stopPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'stop playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.stop();
    result.success(null);
  }

  private reloadPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    player.reload();
    result.success(null);
  }

  private seekToPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const position = arg !== null && arg !== undefined ? (arg.get('position') as Object) as number : 0;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'seekTo playerId=%{public}s position=%{public}d', playerId, position);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.seekTo(position);
    result.success(null);
  }

  private setStartTime(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }

    const playerId = this.extractPlayerId(args);
    const argMap = this.extractArg(args) as Map<string, Object>;
    const timeValue = argMap.get('time');
    const seekModeValue = argMap.get('seekMode');
    const time = timeValue !== null && timeValue !== undefined ? (timeValue as number) : 0;
    const seekMode = seekModeValue !== null && seekModeValue !== undefined ? (seekModeValue as number) : 1;

    hilog.info(LOG_DOMAIN, LOG_TAG, 'setStartTime playerId=%{public}s time=%{public}d mode=%{public}d',
      playerId, time, seekMode);

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    player.setStartTime(time, seekMode);
    result.success(null);
  }

  private setMaxAccurateSeekDelta(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }

    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const delta = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as number) : 0;

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    player.setMaxAccurateSeekDelta(delta);
    result.success(null);
  }

  private setFastStart(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }

    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const enable = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as boolean) : false;

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    player.setFastStart(enable);
    result.success(null);
  }

  private setEnableHardwareDecoder(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }

    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const enable = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as boolean) : false;

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    player.setEnableHardwareDecoder(enable);
    result.success(null);
  }

  private setSpeed(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const speed = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as number) : 1.0;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setSpeed playerId=%{public}s speed=%{public}s', playerId, String(speed));
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setSpeed(speed);
    result.success(null);
  }

  private setLoop(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const loop = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as boolean) : false;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setLoop(loop);
    result.success(null);
  }

  private setAutoPlay(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const autoPlay = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as boolean) : false;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setAutoPlay(autoPlay);
    result.success(null);
  }

  // === 播放源设置方法 ===

  private setUrl(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const url = this.extractArg(args) as string;
    
    console.info('[FlutterAliplayer] setUrl playerId=' + playerId + ' url=' + url);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setUrl playerId=%{public}s url=%{public}s', playerId, url);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    // 使用 getPlayerInstance 代替 getPlayer，支持所有类型的播放器
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setUrl(url);
    result.success(null);
  }

  private setDataSource(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const url = arg !== null && arg !== undefined ? (arg.get('url') as Object) as string : '';
    const timeLineUrl = arg !== null && arg !== undefined ? (arg.get('timeLineUrl') as Object) as string : '';
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setDataSource playerId=%{public}s url=%{public}s timeLineUrl=%{public}s', playerId, url, timeLineUrl);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    const liveShiftPlayer = player as AliLiveShiftPlayerInstance;
    liveShiftPlayer.setLiveShiftDataSource(url, timeLineUrl);
    result.success(null);
  }

  private setVidSts(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const vid = arg !== null && arg !== undefined ? (arg.get('vid') as Object) as string : '';
    const accessKeyId = arg !== null && arg !== undefined ? (arg.get('accessKeyId') as Object) as string : '';
    const accessKeySecret = arg !== null && arg !== undefined ? (arg.get('accessKeySecret') as Object) as string : '';
    const securityToken = arg !== null && arg !== undefined ? (arg.get('securityToken') as Object) as string : '';
    const region = arg !== null && arg !== undefined ? (arg.get('region') as Object) as string : '';
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayer(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setVidSts(vid, accessKeyId, accessKeySecret, securityToken, region);
    result.success(null);
  }

  private setVidAuth(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const vid = arg !== null && arg !== undefined ? (arg.get('vid') as Object) as string : '';
    const playAuth = arg !== null && arg !== undefined ? (arg.get('playAuth') as Object) as string : '';
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayer(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setVidAuth(vid, playAuth);
    result.success(null);
  }

  private setVidMps(args: Map<string, Object> | null, result: MethodResult): void {
    result.notImplemented();
  }

  private setLiveSts(args: Map<string, Object> | null, result: MethodResult): void {
    result.notImplemented();
  }

  // === 音量控制方法 ===

  private setVolume(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const volume = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as number) : 1.0;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setVolume(volume);
    result.success(null);
  }

  private getVolume(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    result.success(player.getVolume());
  }

  private setMuted(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const muted = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as boolean) : false;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setMuted(muted);
    result.success(null);
  }

  private isMuted(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    result.success(player.isMuted());
  }

  // === 视频信息获取方法 ===

  private getVideoWidth(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    result.success(player.getVideoWidth());
  }

  private getVideoHeight(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    result.success(player.getVideoHeight());
  }

  private getDuration(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    result.success(player.getDuration());
  }

  private getCurrentPosition(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    result.success(player.getCurrentPosition());
  }

  private getMediaInfo(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'getMediaInfo playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'getMediaInfo: NO_MANAGER');
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'getMediaInfo: PLAYER_NOT_FOUND %{public}s', playerId);
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    const info = player.getMediaInfo();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'getMediaInfo result: duration=%{public}d', info.get('duration') as number);
    result.success(info);
  }

  // === 视频渲染方法 ===

  private setPlayerView(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const viewId = this.extractArg(args) as number;
    
    console.info('[FlutterAliplayer] setPlayerView playerId=' + playerId + ' viewId=' + viewId);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setPlayerView playerId=%{public}s viewId=%{public}d', playerId, viewId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    this.instanceManager.bindPlayerView(playerId, viewId);
    result.success(null);
  }

  private setScalingMode(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const mode = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as number) : 0;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setScalingMode(mode);
    result.success(null);
  }

  private getScalingMode(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    result.success(player.getScalingMode());
  }

  private setRotateMode(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const mode = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as number) : 0;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setRotateMode(mode);
    result.success(null);
  }

  private setMirrorMode(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const argValue = this.extractArg(args);
    const mode = argValue !== null && argValue !== undefined && argValue !== '' ? (argValue as number) : 0;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setMirrorMode(mode);
    result.success(null);
  }

  private getAlphaRenderMode(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    result.success(player.getAlphaRenderMode());
  }

  private setAlphaRenderMode(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    const argValue = this.extractArg(args);
    const mode = argValue !== null && argValue !== undefined ? argValue as number : 0;
    player.setAlphaRenderMode(mode);
    result.success(null);
  }

  private setVideoBackgroundColor(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    const color = this.extractArg(args) as number;

    hilog.info(LOG_DOMAIN, LOG_TAG, 'setVideoBackgroundColor playerId=%{public}s color=0x%{public}x', playerId, color);

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    player.setBackgroundColor(color);
    result.success(null);
  }

  // === 清晰度切换方法 ===

  private selectTrack(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const trackIndex = arg !== null && arg !== undefined
      ? ((arg.get('trackIdx') ?? arg.get('trackIndex')) as number)
      : -1;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.selectTrack(trackIndex);
    result.success(null);
  }

  private switchStream(args: Map<string, Object> | null, result: MethodResult): void {
    result.notImplemented();
  }

  private setDefaultBandWidth(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const bandWidth = (this.extractArg(args) as Object) as number;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setDefaultBandWidth(bandWidth);
    result.success(null);
  }

  private setDefaultResolution(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const resolution = (this.extractArg(args) as Object) as number;
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setDefaultResolution(resolution);
    result.success(null);
  }

  // === 全局设置方法 ===

  private setLogLevel(args: Object | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }

    const level = args as number;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setLogLevel level=%{public}d', level);
    
    if (this.globalSettingsPlugin !== null) {
      this.globalSettingsPlugin.setLogLevel(level);
    }
    result.success(null);
  }

  private enableConsoleLog(args: Object | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }

    const enable = args as boolean;
    
    if (this.globalSettingsPlugin !== null) {
      this.globalSettingsPlugin.enableConsoleLog(enable);
    }
    result.success(null);
  }

  private netWorkReConnect(result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'netWorkReConnect');
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    this.instanceManager.reloadAll();
    result.success(null);
  }

  // === RTS/ARTC SDK 加载 ===

  private loadRtsLibrary(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const isAliPlayerSDK = (args.get('isAliPlayerSDK') as Object) as boolean;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'loadRtsLibrary isAliPlayerSDK=%{public}s', String(isAliPlayerSDK));
    
    // TODO: 需要手动集成 artclibrary + RtsSDK HAR 包
    result.success(null);
  }

  // === 其他功能 ===

  private snapshot(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const path = this.extractArg(args) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'snapshot playerId=%{public}s path=%{public}s', playerId, path);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.snapShot(path);
    result.success(null);
  }

  private addExtSubtitle(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const url = (this.extractArg(args) as Object) as string;
    
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'addExtSubtitle playerId=%{public}s url=%{public}s', playerId, url);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.addExtSubtitle(url);
    result.success(null);
  }

  private selectExtSubtitle(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const trackIndex = arg.get('trackIndex') as number;
    const enable = arg.get('enable') as boolean;
    
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'selectExtSubtitle playerId=%{public}s trackIndex=%{public}d enable=%{public}s', 
      playerId, trackIndex, String(enable));
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.selectExtSubtitle(trackIndex, enable);
    result.success(null);
  }
  
  // === 鉴权过期监听 ===
  
  private setOnURLSourceExpiredListener(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const enable = (args.get('arg') as Object) as boolean;
    
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnURLSourceExpiredListener playerId=%{public}s enable=%{public}s', 
      playerId, String(enable));
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setOnURLSourceExpiredListener(enable);
    result.success(null);
  }
  
  private setOnVidAuthExpiredListener(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const enable = (args.get('arg') as Object) as boolean;
    
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnVidAuthExpiredListener playerId=%{public}s enable=%{public}s', 
      playerId, String(enable));
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setOnVidAuthExpiredListener(enable);
    result.success(null);
  }

  // === 缩略图方法 ===

  private createThumbnailHelper(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const thumbnail = (this.extractArg(args) as Object) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'createThumbnailHelper playerId=%{public}s thumbnail=%{public}s', playerId, thumbnail);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.createThumbnailHelper(thumbnail);
    result.success(null);
  }

  private requestBitmapAtPosition(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const position = (this.extractArg(args) as Object) as number;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'requestBitmapAtPosition playerId=%{public}s position=%{public}d', playerId, position);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.requestBitmapAtPosition(position);
    result.success(null);
  }

  // === 列表播放器方法 ===

  private addUrlSource(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const url = arg !== null && arg !== undefined ? (arg.get('url') as Object) as string : '';
    const uid = arg !== null && arg !== undefined ? (arg.get('uid') as Object) as string : '';
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'addUrlSource playerId=%{public}s url=%{public}s uid=%{public}s', playerId, url, uid);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const listPlayer = this.instanceManager.getListPlayer(playerId);
    if (listPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'List player not found: ' + playerId, null);
      return;
    }
    
    listPlayer.addUrl(url, uid);
    result.success(null);
  }

  private moveTo(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const uid = this.extractArg(args) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'moveTo playerId=%{public}s uid=%{public}s', playerId, uid);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const listPlayer = this.instanceManager.getListPlayer(playerId);
    if (listPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'List player not found: ' + playerId, null);
      return;
    }
    
    const success = listPlayer.moveTo(uid);
    result.success(success);
  }

  private moveToNext(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'moveToNext playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const listPlayer = this.instanceManager.getListPlayer(playerId);
    if (listPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'List player not found: ' + playerId, null);
      return;
    }
    
    const success = listPlayer.moveToNext();
    result.success(success);
  }

  private moveToPre(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'moveToPre playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const listPlayer = this.instanceManager.getListPlayer(playerId);
    if (listPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'List player not found: ' + playerId, null);
      return;
    }
    
    const success = listPlayer.moveToPrev();
    result.success(success);
  }

  private getCurrentUid(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const listPlayer = this.instanceManager.getListPlayer(playerId);
    if (listPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'List player not found: ' + playerId, null);
      return;
    }
    
    const uid = listPlayer.getCurrentUid();
    result.success(uid);
  }

  private clearPlaylist(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'clearPlaylist playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const listPlayer = this.instanceManager.getListPlayer(playerId);
    if (listPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'List player not found: ' + playerId, null);
      return;
    }
    
    listPlayer.clear();
    result.success(null);
  }

  private removeSource(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const uid = this.extractArg(args) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'removeSource playerId=%{public}s uid=%{public}s', playerId, uid);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const listPlayer = this.instanceManager.getListPlayer(playerId);
    if (listPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'List player not found: ' + playerId, null);
      return;
    }
    
    listPlayer.removeSource(uid);
    result.success(null);
  }

  // === 直播时移播放器方法 ===

  private setLiveShiftDataSource(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const arg = this.extractArg(args) as Map<string, Object>;
    const url = arg !== null && arg !== undefined ? (arg.get('url') as Object) as string : '';
    const timeLineUrl = arg !== null && arg !== undefined ? (arg.get('timeLineUrl') as Object) as string : '';
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setLiveShiftDataSource playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const liveShiftPlayer = this.instanceManager.getLiveShiftPlayer(playerId);
    if (liveShiftPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'Live shift player not found: ' + playerId, null);
      return;
    }
    
    liveShiftPlayer.setLiveShiftDataSource(url, timeLineUrl);
    result.success(null);
  }

  private seekToLiveTime(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const liveTime = this.extractArg(args) as number;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'seekToLiveTime playerId=%{public}s liveTime=%{public}d', playerId, liveTime);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const liveShiftPlayer = this.instanceManager.getLiveShiftPlayer(playerId);
    if (liveShiftPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'Live shift player not found: ' + playerId, null);
      return;
    }
    
    liveShiftPlayer.seekToLiveTime(liveTime);
    result.success(null);
  }

  private getCurrentLiveTime(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const liveShiftPlayer = this.instanceManager.getLiveShiftPlayer(playerId);
    if (liveShiftPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'Live shift player not found: ' + playerId, null);
      return;
    }
    
    const liveTime = liveShiftPlayer.getCurrentLiveTime();
    result.success(liveTime);
  }

  private getCurrentTime(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const liveShiftPlayer = this.instanceManager.getLiveShiftPlayer(playerId);
    if (liveShiftPlayer === null) {
      result.error('PLAYER_NOT_FOUND', 'Live shift player not found: ' + playerId, null);
      return;
    }
    
    const currentTime = liveShiftPlayer.getCurrentTime();
    result.success(currentTime);
  }

  // === 辅助方法 ===

  private extractPlayerId(args: Map<string, Object> | null): string {
    if (args === null || args === undefined) {
      return 'default';
    }
    const id = args.get('playerId');
    if (id === null || id === undefined) {
      return 'default';
    }
    return (id as Object) as string;
  }
  
  private extractArg(args: Map<string, Object> | null): Object {
    if (args === null || args === undefined) {
      return '';
    }
    const argValue = args.get('arg');
    if (argValue === null || argValue === undefined) {
      return '';
    }
    return argValue as Object;
  }

  // === 播放器配置方法 ===

  private setPlayerConfig(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const playerId = this.extractPlayerId(args);
    const configMap = this.extractArg(args) as Map<string, Object>;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setPlayerConfig playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    player.setConfig(configMap);
    result.success(null);
  }

  private getPlayerConfig(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'getPlayerConfig playerId=%{public}s', playerId);
    
    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }
    
    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    const config = player.getConfig();
    result.success(config);
  }

  /**
   * getConfig 返回 PlayerConfig 的原始字段名（m 前缀），
   * getPlayConfig 返回 Dart AVPConfig 的字段名（驼峰），两者不能互相替代。
   */
  private getPlayConfig(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.extractPlayerId(args);

    hilog.info(LOG_DOMAIN, LOG_TAG, 'getPlayConfig playerId=%{public}s', playerId);

    if (this.instanceManager === null) {
      result.error('NO_MANAGER', 'Instance manager not initialized', null);
      return;
    }

    const player = this.instanceManager.getPlayerInstance(playerId);
    if (player === null) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }

    result.success(player.getPlayConfig());
  }
}