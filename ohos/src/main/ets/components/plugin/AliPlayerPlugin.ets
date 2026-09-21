/**
 * 阿里云播放器插件主入口
 * 
 * 负责:
 * - 注册 PlatformView Factory
 * - 注册 MethodChannel (plugins.flutter_aliplayer_factory)
 * - 注册 EventChannel (flutter_aliplayer_event)
 * - 管理播放器实例 Map
 * - 处理 MethodChannel 方法调用
 * - 实现 SurfaceCallback (surfaceId 回绑)
 */

import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCallHandler,
  MethodCall,
  MethodResult,
  MethodChannel,
  EventChannel,
  EventSink,
  StreamHandler,
} from '@ohos/flutter_ohos';
import { AliPlayerViewFactory } from './AliPlayerViewFactory';
import { AliPlayerInstance } from './AliPlayerInstance';
import { SurfaceCallback } from './AliPlayerPlatformView';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AliPlayerGlobalSettings } from 'premierlibrary';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliPlayerPlugin';

function extractArg(args: Map<string, Object> | null): Map<string, Object> | null {
  if (args === null) return null;
  const arg = args.get('arg');
  if (arg !== undefined && arg !== null) {
    return arg as Map<string, Object>;
  }
  return args;
}

export default class AliPlayerPlugin implements FlutterPlugin, MethodCallHandler, SurfaceCallback {
  private methodChannel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  
  // 播放器实例管理 Map
  private playerInstances: Map<string, AliPlayerInstance> = new Map();
  
  // surfaceId Map: playerId -> surfaceId
  private surfaceIds: Map<string, string> = new Map();
  
  /**
   * 插件挂载到 Flutter Engine
   */
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onAttachedToEngine');
    
    // 注册 PlatformView Factory
    const viewFactory = new AliPlayerViewFactory(this);
    binding.getPlatformViewRegistry()
      .registerViewFactory('flutter_aliplayer_render_view', viewFactory);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'PlatformView Factory registered: flutter_aliplayer_render_view');
    
    // 注册 MethodChannel
    this.methodChannel = new MethodChannel(
      binding.getBinaryMessenger(),
      'plugins.flutter_aliplayer_factory'
    );
    this.methodChannel.setMethodCallHandler(this);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'MethodChannel registered: plugins.flutter_aliplayer_factory');
    
    // 注册 EventChannel
    this.eventChannel = new EventChannel(
      binding.getBinaryMessenger(),
      'flutter_aliplayer_event'
    );
    this.eventChannel.setStreamHandler(new AliPlayerEventStreamHandler(this));
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'EventChannel registered: flutter_aliplayer_event');
  }
  
  /**
   * 插件从 Flutter Engine 分离
   */
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onDetachedFromEngine');
    
    // 清理所有播放器实例
    this.releaseAllPlayers();
    
    // 清理 Channel
    if (this.methodChannel !== null) {
      this.methodChannel.setMethodCallHandler(null);
      this.methodChannel = null;
    }
    
    if (this.eventChannel !== null) {
      this.eventChannel.setStreamHandler(null);
      this.eventChannel = null;
    }
    
    this.eventSink = null;
  }
  
  /**
   * SurfaceCallback 实现: surface 创建
   */
  onSurfaceReady(viewId: number, surfaceId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onSurfaceReady: viewId=%{public}d surfaceId=%{public}s', 
      viewId, surfaceId);
  }
  
  onSurfaceDestroyed(viewId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onSurfaceDestroyed: viewId=%{public}d', viewId);
  }
  
  /**
   * EventSink 设置
   */
  setEventSink(sink: EventSink): void {
    this.eventSink = sink;
    
    // 为所有播放器实例设置 eventSink
    this.playerInstances.forEach((player: AliPlayerInstance) => {
      player.setEventSink(sink);
    });
  }
  
  /**
   * MethodChannel 方法处理
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'onMethodCall: %{public}s', call.method);
    
    // 解析参数
    const args = call.args as Map<string, Object> | null;
    
    switch (call.method) {
      case 'createAliPlayer':
        this.handleCreateAliPlayer(args, result);
        break;
      
      case 'destroy':
        this.handleDestroy(args, result);
        break;
      
      case 'setUrl':
        this.handleSetUrl(args, result);
        break;
      
      case 'setVidSts':
        this.handleSetVidSts(args, result);
        break;
      
      case 'setVidAuth':
        this.handleSetVidAuth(args, result);
        break;
      
      case 'prepare':
        this.handlePrepare(args, result);
        break;
      
      case 'play':
        this.handlePlay(args, result);
        break;
      
      case 'pause':
        this.handlePause(args, result);
        break;
      
      case 'stop':
        this.handleStop(args, result);
        break;
      
      case 'seekTo':
        this.handleSeekTo(args, result);
        break;
      
      case 'setSpeed':
        this.handleSetSpeed(args, result);
        break;
      
      case 'setVolume':
        this.handleSetVolume(args, result);
        break;
      
      case 'setLoop':
        this.handleSetLoop(args, result);
        break;
      
      case 'setMuted':
        this.handleSetMuted(args, result);
        break;
      
      case 'getCurrentPosition':
        this.handleGetCurrentPosition(args, result);
        break;
      
      case 'getDuration':
        this.handleGetDuration(args, result);
        break;
      
      case 'getVideoWidth':
        this.handleGetVideoWidth(args, result);
        break;
      
      case 'getVideoHeight':
        this.handleGetVideoHeight(args, result);
        break;
      
      case 'getSDKVersion':
        this.handleGetSDKVersion(result);
        break;
      
      case 'loadRtsLibrary':
        // ARTC 超低延迟直播 - 需集成额外 HAR 包
        hilog.info(LOG_DOMAIN, LOG_TAG, 'loadRtsLibrary called (requires ARTC HAR package)');
        result.success(null);
        break;
      
      case 'showFloatViewForAndroid':
        // 悬浮窗 - Android 专属,OHOS 不支持
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'showFloatViewForAndroid not supported on OHOS');
        result.success(null);
        break;
      
      case 'hideFloatViewForAndroid':
        // 悬浮窗 - Android 专属
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'hideFloatViewForAndroid not supported on OHOS');
        result.success(null);
        break;
      
      case 'checkFloatViewPermission':
        // 悬浮窗权限检查 - OHOS 不支持,返回 true 表示无需权限
        result.success(true);
        break;
      
      case 'requestFloatViewPermission':
        // 悬浮窗权限请求 - OHOS 不支持,返回 true 表示请求成功(无需请求)
        result.success(true);
        break;
      
      case 'setFloatViewIcon':
        // 悬浮窗图标 - Android 专属
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'setFloatViewIcon not supported on OHOS');
        result.success(null);
        break;
      
      case 'setFloatViewUI':
        // 悬浮窗 UI - Android 专属
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'setFloatViewUI not supported on OHOS');
        result.success(null);
        break;
      
      // 其他方法... (150+ 方法,这里只列出核心方法)
      default:
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Method not implemented: %{public}s', call.method);
        result.notImplemented();
        break;
    }
  }
  
  /**
   * 创建播放器实例
   */
  private async handleCreateAliPlayer(args: Map<string, Object> | null, result: MethodResult): Promise<void> {
    // 解析 playerId
    let playerId: string = 'default';
    if (args !== null) {
      const idValue = args.get('playerId');
      if (idValue !== undefined) {
        playerId = idValue as string;
      }
    }
    
    // 创建播放器实例
    const playerInstance = new AliPlayerInstance(playerId);
    
    // 初始化播放器
    try {
      await playerInstance.init();
      
      // 设置 eventSink
      if (this.eventSink !== null) {
        playerInstance.setEventSink(this.eventSink);
      }
      
      // 保存到实例 Map
      this.playerInstances.set(playerId, playerInstance);
      
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Player created: %{public}s', playerId);
      result.success(playerId);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to create player: %{public}s', (error as Error).message);
      result.error('CREATE_FAILED', 'Failed to create AliPlayer', null);
    }
  }
  
  /**
   * 销毁播放器实例
   */
  private async handleDestroy(args: Map<string, Object> | null, result: MethodResult): Promise<void> {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found: ' + playerId, null);
      return;
    }
    
    // 释放播放器
    await playerInstance.release();
    
    // 从 Map 中移除
    this.playerInstances.delete(playerId);
    this.surfaceIds.delete(playerId);
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Player destroyed: %{public}s', playerId);
    result.success(null);
  }
  
  /**
   * 设置 URL 播放源
   */
private handleSetUrl(args: Map<string, Object> | null, result: MethodResult): void {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined) {
        result.error('PLAYER_NOT_FOUND', 'Player not found', null);
        return;
      }
      
      if (args === null) {
        result.error('INVALID_ARGS', 'URL is required', null);
        return;
      }
      
      const arg = extractArg(args);
      const urlValue = arg !== null ? arg.get('url') : undefined;
    if (urlValue === undefined) {
      result.error('INVALID_ARGS', 'URL is required', null);
      return;
    }
    
    const url = urlValue as string;
    playerInstance.setUrl(url);
    result.success(null);
  }
  
  /**
   * 设置 VidSts 播放源
   */
private handleSetVidSts(args: Map<string, Object> | null, result: MethodResult): void {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined || args === null) {
        result.error('PLAYER_NOT_FOUND', 'Player not found or invalid args', null);
        return;
      }
      
      const arg = extractArg(args);
      if (arg === null) {
        result.error('INVALID_ARGS', 'Invalid args', null);
        return;
      }
      
      const vid = arg.get('vid') as string;
      const accessKeyId = arg.get('accessKeyId') as string;
      const accessKeySecret = arg.get('accessKeySecret') as string;
      const securityToken = arg.get('securityToken') as string;
      const region = arg.get('region') as string;
      
      playerInstance.setVidSts(vid, accessKeyId, accessKeySecret, securityToken, region);
      result.success(null);
    }
  
  /**
   * 设置 VidAuth 播放源
   */
private handleSetVidAuth(args: Map<string, Object> | null, result: MethodResult): void {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined || args === null) {
        result.error('PLAYER_NOT_FOUND', 'Player not found or invalid args', null);
        return;
      }
      
      const arg = extractArg(args);
      if (arg === null) {
        result.error('INVALID_ARGS', 'Invalid args', null);
        return;
      }
      
      const vid = arg.get('vid') as string;
      const playAuth = arg.get('playAuth') as string;
      
      playerInstance.setVidAuth(vid, playAuth);
      result.success(null);
    }
  
  /**
   * 准备播放
   */
  private async handlePrepare(args: Map<string, Object> | null, result: MethodResult): Promise<void> {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    await playerInstance.prepare();
    result.success(null);
  }
  
  /**
   * 开始播放
   */
  private async handlePlay(args: Map<string, Object> | null, result: MethodResult): Promise<void> {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    await playerInstance.play();
    result.success(null);
  }
  
  /**
   * 暂停播放
   */
  private async handlePause(args: Map<string, Object> | null, result: MethodResult): Promise<void> {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    await playerInstance.pause();
    result.success(null);
  }
  
  /**
   * 停止播放
   */
  private async handleStop(args: Map<string, Object> | null, result: MethodResult): Promise<void> {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    await playerInstance.stop();
    result.success(null);
  }
  
  /**
   * Seek 到指定位置
   */
private async handleSeekTo(args: Map<string, Object> | null, result: MethodResult): Promise<void> {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined || args === null) {
        result.error('PLAYER_NOT_FOUND', 'Player not found or invalid args', null);
        return;
      }
      
      const arg = extractArg(args);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'handleSeekTo: arg is %{public}s', arg !== null ? 'valid' : 'null');
      
      if (arg !== null) {
        const positionValue = arg.get('position');
        const seekModeValue = arg.get('seekMode');
        hilog.info(LOG_DOMAIN, LOG_TAG, 'handleSeekTo: position=%{public}d seekMode=%{public}d', 
          positionValue !== undefined ? (positionValue as number) : -1,
          seekModeValue !== undefined ? (seekModeValue as number) : -1);
        const positionMs = positionValue !== undefined ? (positionValue as number) : 0;
        await playerInstance.seekTo(positionMs);
      } else {
        await playerInstance.seekTo(0);
      }
      result.success(null);
    }
  
  /**
   * 设置倍速
   */
private handleSetSpeed(args: Map<string, Object> | null, result: MethodResult): void {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined || args === null) {
        result.error('PLAYER_NOT_FOUND', 'Player not found or invalid args', null);
        return;
      }
      
      const arg = extractArg(args);
      const speed = arg !== null ? (arg.get('speed') as number) : 1.0;
      playerInstance.setSpeed(speed);
      result.success(null);
    }
  
  /**
   * 设置音量
   */
private handleSetVolume(args: Map<string, Object> | null, result: MethodResult): void {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined || args === null) {
        result.error('PLAYER_NOT_FOUND', 'Player not found or invalid args', null);
        return;
      }
      
      const arg = extractArg(args);
      const volume = arg !== null ? (arg.get('volume') as number) : 1.0;
      playerInstance.setVolume(volume);
      result.success(null);
    }
  
  /**
   * 设置循环播放
   */
private handleSetLoop(args: Map<string, Object> | null, result: MethodResult): void {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined || args === null) {
        result.error('PLAYER_NOT_FOUND', 'Player not found or invalid args', null);
        return;
      }
      
      const arg = extractArg(args);
      const loop = arg !== null ? (arg.get('loop') as boolean) : false;
      playerInstance.setLoop(loop);
      result.success(null);
    }
  
  /**
   * 设置静音
   */
private handleSetMuted(args: Map<string, Object> | null, result: MethodResult): void {
      const playerId = this.getPlayerIdFromArgs(args);
      const playerInstance = this.playerInstances.get(playerId);
      
      if (playerInstance === undefined || args === null) {
        result.error('PLAYER_NOT_FOUND', 'Player not found or invalid args', null);
        return;
      }
      
      const arg = extractArg(args);
      const muted = arg !== null ? (arg.get('muted') as boolean) : false;
      playerInstance.setMuted(muted);
      result.success(null);
    }
  
  /**
   * 获取当前播放位置
   */
  private handleGetCurrentPosition(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    const position = playerInstance.getCurrentPosition();
    result.success(position);
  }
  
  /**
   * 获取视频时长
   */
  private handleGetDuration(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    const duration = playerInstance.getDuration();
    result.success(duration);
  }
  
  /**
   * 获取视频宽度
   */
  private handleGetVideoWidth(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    const width = playerInstance.getVideoWidth();
    result.success(width);
  }
  
  /**
   * 获取视频高度
   */
  private handleGetVideoHeight(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId = this.getPlayerIdFromArgs(args);
    const playerInstance = this.playerInstances.get(playerId);
    
    if (playerInstance === undefined) {
      result.error('PLAYER_NOT_FOUND', 'Player not found', null);
      return;
    }
    
    const height = playerInstance.getVideoHeight();
    result.success(height);
  }
  
  /**
   * 获取 SDK 版本
   */
  private handleGetSDKVersion(result: MethodResult): void {
    const version = AliPlayerGlobalSettings.getSdkVersion();
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'SDK version: %{public}s', version);
    result.success(version);
  }
  
  /**
   * 从参数中获取 playerId
   */
  private getPlayerIdFromArgs(args: Map<string, Object> | null): string {
    if (args === null) {
      return 'default';
    }
    
    const playerIdValue = args.get('playerId');
    if (playerIdValue !== undefined) {
      return playerIdValue as string;
    }
    
    return 'default';
  }
  
  /**
   * 释放所有播放器实例
   */
  private async releaseAllPlayers(): Promise<void> {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Releasing all players');
    
    const entries = Array.from(this.playerInstances.entries());
    for (let i = 0; i < entries.length; i++) {
      const playerId = entries[i][0];
      const playerInstance = entries[i][1];
      await playerInstance.release();
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'Player released: %{public}s', playerId);
    }
    
    this.playerInstances.clear();
    this.surfaceIds.clear();
  }
}

/**
 * EventChannel StreamHandler
 */
class AliPlayerEventStreamHandler implements StreamHandler {
  private plugin: AliPlayerPlugin;
  
  constructor(plugin: AliPlayerPlugin) {
    this.plugin = plugin;
  }
  
  onListen(args: Object, sink: EventSink): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'EventChannel onListen');
    this.plugin.setEventSink(sink);
  }
  
  onCancel(args: Object): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'EventChannel onCancel');
    this.plugin.setEventSink(null);
  }
}