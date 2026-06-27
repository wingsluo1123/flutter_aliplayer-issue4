import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  FlutterPlugin,
  FlutterPluginBinding,
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import EventChannel, {
  EventSink,
  StreamHandler,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import BasicMessageChannel from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import Any from '@ohos/flutter_ohos/src/main/ets/plugin/common/Any';
import {
  AliPlayerFactory, AliPlayer, UrlSource, VidSts, VidAuth, VidMps,
  ApsaraVideoPlayer,
  AliPlayerGlobalSettings, PlayerConfig,
  ScaleMode, TrackType, MediaInfo, TrackInfo,
  Logger
} from 'premierlibrary';
import { AliListPlayer } from 'premierlibrary/src/main/ets/com/aliyun/player/AliListPlayer';
import {
  EncryptType,
  VidPlayerConfigGen
} from 'premierlibrary/src/main/ets/com/aliyun/player/VidPlayerConfigGen';
import {
  MultiBitratesMode,
  SceneType,
  StrategyType
} from 'premierlibrary/src/main/ets/com/aliyun/player/IListPlayer';
import { PropertyKey } from 'premierlibrary/src/main/ets/com/aliyun/player/IPlayer';
import { StsInfo } from 'premierlibrary/src/main/ets/com/aliyun/player/source/StsInfo';
import { fileIo } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';
import Context from '@ohos.app.ability.common';
import { AliPlayerEntry } from './AliPlayerEntry';
import { AliPlayerViewFactory } from './AliPlayerPlatformView';
import { VideoViewRegistry } from './VideoViewRegistry';
import { AliPlayerGlobalSettingsHandler } from './AliPlayerGlobalSettingsHandler';
import { MediaLoaderHandler } from './MediaLoaderHandler';
import { AliDownloaderHandler } from './AliDownloaderHandler';
import { AliPlayerAVSession, AVSessionCommandCallback } from './AliPlayerAVSession';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';

// AVSession playback state constants
const AVSESSION_STATE_PAUSED = 2;
// Player state constants
const PLAYER_STATE_STARTED = 3;

/** FlutterAliplayerPlugin **/
export default class FlutterAliplayerPlugin implements FlutterPlugin, AbilityAware {
  private methodChannelFactory: MethodChannel | null = null;
  private methodChannelGlobalSetting: MethodChannel | null = null;
  private methodChannelMediaLoader: MethodChannel | null = null;
  private methodChannelLoaderV2: MethodChannel | null = null;
  private methodChannelDownload: MethodChannel | null = null;
  private eventChannelAliplayer: EventChannel | null = null;
  private eventChannelMediaLoader: EventChannel | null = null;
  private eventChannelLoaderV2: EventChannel | null = null;
  private eventChannelDownload: EventChannel | null = null;
  private eventSinkAliplayer: EventSink | null = null;
  private eventSinkDownload: EventSink | null = null;

  // BasicMessageChannels (dynamic per playerId)
  private basicMessageChannels: Map<string, BasicMessageChannel<Any>> = new Map();

  // Mapping: PlatformView viewId → playerId (string)
  private viewToPlayerMap: Map<number, string> = new Map();

  private context: common.Context | null = null;
  private abilityContext: common.UIAbilityContext | null = null;
  private playerEntries: Map<string, AliPlayerEntry> = new Map();
  private globalSettingsHandler: AliPlayerGlobalSettingsHandler | null = null;
  private mediaLoaderHandler: MediaLoaderHandler | null = null;
  private downloaderHandler: AliDownloaderHandler | null = null;
  private avSession: AliPlayerAVSession | null = null;
  private vidPlayerConfigGen: VidPlayerConfigGen | null = null;

  private binaryMessenger: BinaryMessenger | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return 'FlutterAliplayerPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext();
    this.binaryMessenger = binding.getBinaryMessenger();

    hilog.info(LOG_DOMAIN, LOG_TAG, 'onAttachedToEngine');

    // Register PlatformView factory
    binding.getPlatformViewRegistry()
      .registerViewFactory('flutter_aliplayer_render_view', new AliPlayerViewFactory());

    // Setup Factory MethodChannel (main plugin channel)
    this.methodChannelFactory = new MethodChannel(
      binding.getBinaryMessenger(), 'plugins.flutter_aliplayer_factory');
    this.methodChannelFactory.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handleFactoryMethod(call, result);
      }
    });

    // Setup Global Setting Channel
    this.methodChannelGlobalSetting = new MethodChannel(
      binding.getBinaryMessenger(), 'plugins.flutter_global_setting');
    this.methodChannelGlobalSetting.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        const method: string = call.method;
        if (this.globalSettingsHandler !== null) {
          this.globalSettingsHandler.handleMethod(call.method, call.args as Object | null, result);
        } else {
          result.notImplemented();
        }
      }
    });

    // Setup Media Loader V1 Channel
    this.methodChannelMediaLoader = new MethodChannel(
      binding.getBinaryMessenger(), 'plugins.flutter_aliplayer_media_loader');
    this.methodChannelMediaLoader.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        const method: string = call.method;
        if (this.mediaLoaderHandler !== null) {
          this.mediaLoaderHandler.handleMediaLoaderMethod(method, call.args as Map<string, Object>, result);
        } else {
          result.notImplemented();
        }
      }
    });

    // Setup Media Loader V2 Channel
    this.methodChannelLoaderV2 = new MethodChannel(
      binding.getBinaryMessenger(), 'plugins.flutter_aliplayer_loader_v2');
    this.methodChannelLoaderV2.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        const method: string = call.method;
        if (this.mediaLoaderHandler !== null) {
          this.mediaLoaderHandler.handleLoaderV2Method(method, call.args as Map<string, Object>, result);
        } else {
          result.notImplemented();
        }
      }
    });

    // Setup Download Channel
    this.methodChannelDownload = new MethodChannel(
      binding.getBinaryMessenger(), 'plugins.flutter_alidownload');
    this.methodChannelDownload.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        const method: string = call.method;
        if (this.downloaderHandler !== null) {
          this.downloaderHandler.handleMethod(method, call.args as Object | null, result);
        } else {
          result.notImplemented();
        }
      }
    });

    // Setup Event Channels
    this.eventChannelAliplayer = new EventChannel(
      binding.getBinaryMessenger(), 'flutter_aliplayer_event');
    this.eventChannelAliplayer.setStreamHandler({
      onListen: (args: Object, events: EventSink): void => {
        this.eventSinkAliplayer = events;
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'EventChannel aliplayer onListen');
      },
      onCancel: (): void => {
        this.eventSinkAliplayer = null;
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'EventChannel aliplayer onCancel');
      }
    });

    this.eventChannelMediaLoader = new EventChannel(
      binding.getBinaryMessenger(), 'flutter_aliplayer_media_loader_event');
    this.eventChannelMediaLoader.setStreamHandler({
      onListen: (args: Object, events: EventSink): void => {
        if (this.mediaLoaderHandler !== null) {
          this.mediaLoaderHandler.setMediaLoaderEventSink(events);
        }
      },
      onCancel: (): void => {
        if (this.mediaLoaderHandler !== null) {
          this.mediaLoaderHandler.setMediaLoaderEventSink(null);
        }
      }
    });

    this.eventChannelLoaderV2 = new EventChannel(
      binding.getBinaryMessenger(), 'flutter_aliplayer_loader_v2_event');
    this.eventChannelLoaderV2.setStreamHandler({
      onListen: (args: Object, events: EventSink): void => {
        if (this.mediaLoaderHandler !== null) {
          this.mediaLoaderHandler.setLoaderV2EventSink(events);
        }
      },
      onCancel: (): void => {
        if (this.mediaLoaderHandler !== null) {
          this.mediaLoaderHandler.setLoaderV2EventSink(null);
        }
      }
    });

    this.eventChannelDownload = new EventChannel(
      binding.getBinaryMessenger(), 'plugins.flutter_alidownload_event');
    this.eventChannelDownload.setStreamHandler({
      onListen: (args: Object, events: EventSink): void => {
        this.eventSinkDownload = events;
        if (this.downloaderHandler !== null) {
          this.downloaderHandler.setEventSink(events);
        }
      },
      onCancel: (): void => {
        this.eventSinkDownload = null;
        if (this.downloaderHandler !== null) {
          this.downloaderHandler.setEventSink(null);
        }
      }
    });

    // Initialize handlers
    this.globalSettingsHandler = new AliPlayerGlobalSettingsHandler(this.context);
    this.mediaLoaderHandler = new MediaLoaderHandler(this.context);
    this.downloaderHandler = new AliDownloaderHandler(this.context);

    // Setup surface ready callback
    VideoViewRegistry.setSurfaceCallback((playerId: number, surfaceId: string): void => {
      this.onSurfaceReady(playerId.toString(), surfaceId);
    });

    // Initialize AVSession
    this.avSession = new AliPlayerAVSession(null);

    hilog.info(LOG_DOMAIN, LOG_TAG, 'onAttachedToEngine complete');
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onDetachedFromEngine');

    // Destroy all players
    for (const entry of this.playerEntries) {
      const playerEntry: AliPlayerEntry = entry[1];
      playerEntry.destroy();
    }
    this.playerEntries.clear();

    // Release media loaders and downloaders
    if (this.mediaLoaderHandler !== null) {
      this.mediaLoaderHandler.releaseAll();
    }
    if (this.downloaderHandler !== null) {
      this.downloaderHandler.releaseAll();
    }

    // Destroy AVSession
    if (this.avSession !== null) {
      this.avSession.destroy();
      this.avSession = null;
    }

    // Clear registry
    VideoViewRegistry.clear();

    // Close basic message channels
    this.basicMessageChannels.forEach((channel: BasicMessageChannel<Any>, key: string): void => {
      channel.setMessageHandler(null);
    });
    this.basicMessageChannels.clear();

    // Clear channels
    this.methodChannelFactory?.setMethodCallHandler(null);
    this.methodChannelFactory = null;
    this.methodChannelGlobalSetting?.setMethodCallHandler(null);
    this.methodChannelGlobalSetting = null;
    this.methodChannelMediaLoader?.setMethodCallHandler(null);
    this.methodChannelMediaLoader = null;
    this.methodChannelLoaderV2?.setMethodCallHandler(null);
    this.methodChannelLoaderV2 = null;
    this.methodChannelDownload?.setMethodCallHandler(null);
    this.methodChannelDownload = null;
    this.eventChannelAliplayer?.setStreamHandler(null);
    this.eventChannelAliplayer = null;
    this.eventChannelMediaLoader?.setStreamHandler(null);
    this.eventChannelMediaLoader = null;
    this.eventChannelLoaderV2?.setStreamHandler(null);
    this.eventChannelLoaderV2 = null;
    this.eventChannelDownload?.setStreamHandler(null);
    this.eventChannelDownload = null;
    this.eventSinkAliplayer = null;
    this.eventSinkDownload = null;

    this.context = null;
    this.binaryMessenger = null;
    this.abilityContext = null;
    this.globalSettingsHandler = null;
    this.mediaLoaderHandler = null;
    this.downloaderHandler = null;

    hilog.info(LOG_DOMAIN, LOG_TAG, 'onDetachedFromEngine complete');
  }

  // AbilityAware - get UIAbilityContext for AVSession, PiP, etc.
  onAttachedToAbility(binding: AbilityPluginBinding): void {
    const ability = binding.getAbility();
    if (ability !== null && ability !== undefined) {
      this.abilityContext = ability.context as common.UIAbilityContext;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'onAttachedToAbility - got UIAbilityContext');

      // Initialize AVSession with proper context
      if (this.avSession !== null) {
        this.avSession.destroy();
      }
      this.avSession = new AliPlayerAVSession(this.abilityContext);
    }
  }

  onDetachedFromAbility(): void {
    this.abilityContext = null;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onDetachedFromAbility');
  }

  private handleFactoryMethod(call: MethodCall, result: MethodResult): void {
    const method: string = call.method;
    const rawArgs: Object | null = call.args as Object | null;

    // Handle static methods with primitive/direct args before Map cast to avoid crashes
    switch (method) {
      case 'enableConsoleLog':
        this.handleEnableConsoleLog(rawArgs, result);
        return;
      case 'setLogLevel':
        this.handleSetLogLevel(rawArgs, result);
        return;
      case 'getLogLevel':
        this.handleGetLogLevel(result);
        return;
      case 'setLogInfoBlock':
        this.handleSetLogInfoBlock(rawArgs, result);
        return;
      case 'setLogOption':
        this.handleSetLogOption(rawArgs, result);
        return;
      case 'setUseHttp2':
        this.handleSetUseHttp2(rawArgs, result);
        return;
      case 'enableHttpDns':
        this.handleEnableHttpDns(rawArgs, result);
        return;
      case 'setIpResolveType':
        this.handleSetIpResolveType(rawArgs, result);
        return;
      case 'enableNetworkBalance':
        this.handleEnableNetworkBalance(rawArgs, result);
        return;
      case 'isFeatureSupport':
        this.handleIsFeatureSupport(rawArgs, result);
        return;
      case 'createVidPlayerConfigGenerator':
        this.handleCreateVidPlayerConfigGenerator(result);
        return;
      case 'setPreviewTime':
        this.handleSetPreviewTime(rawArgs, result);
        return;
      case 'setHlsUriToken':
        this.handleSetHlsUriToken(rawArgs, result);
        return;
      case 'addVidPlayerConfigByStringValue':
        this.handleAddVidPlayerConfigByStringValue(rawArgs, result);
        return;
      case 'addVidPlayerConfigByIntValue':
        this.handleAddVidPlayerConfigByIntValue(rawArgs, result);
        return;
      case 'setEncryptType':
        this.handleSetEncryptType(rawArgs, result);
        return;
      case 'generatePlayerConfig':
        this.handleGeneratePlayerConfig(result);
        return;
      case 'setPrivateService':
        result.notImplemented();
        return;
      case 'getSDKVersion':
        this.handleGetSDKVersion(result);
        return;
      case 'getDeviceUUID':
        this.handleGetDeviceUUID(result);
        return;
    }

    // For player methods, args are wrapped by Dart's wrapWithPlayerId() as Map with "arg" and "playerId" keys
    const args: Map<string, Object> | null = call.args as Map<string, Object> | null;

    switch (method) {
      case 'createAliPlayer':
        this.handleCreateAliPlayer(args, result);
        break;
      case 'initService':
        result.success(null);
        break;
      case 'setDNSResolve':
        this.handleSetDNSResolve(args, result);
        break;
      case 'enableLocalCache':
        this.handleEnableLocalCache(args, result);
        break;
      case 'setCacheFileClearConfig':
        this.handleSetCacheFileClearConfig(args, result);
        break;
      case 'clearCaches':
        this.handleClearCaches(result);
        break;
      case 'setPlayerView':
        this.handleSetPlayerView(args, result);
        break;
      // Player control methods (require playerId)
      case 'setUrl':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'switchStream':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'prepare':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'play':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'pause':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'clearScreen':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'snapshot':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'clearScreenSync':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'stop':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'destroy':
        this.handlePlayerDestroy(args, result);
        break;
      case 'releaseAsync':
        this.handlePlayerReleaseAsync(args, result);
        break;
      case 'seekTo':
        this.handleSeekTo(args, result);
        break;
      case 'setStartTime':
        this.handleSetStartTime(args, result);
        break;
      case 'setOption':
        this.handleSetOption(args, result);
        break;
      case 'setMaxAccurateSeekDelta':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'isLoop':
        this.handlePlayerGetter('isLoop', args, result);
        break;
      case 'setLoop':
        this.handlePlayerSetter('setLoop', args, result);
        break;
      case 'isAutoPlay':
        this.handlePlayerGetter('isAutoPlay', args, result);
        break;
      case 'setAutoPlay':
        this.handlePlayerSetter('setAutoPlay', args, result);
        break;
      case 'setFastStart':
        this.handlePlayerSetter('setFastStart', args, result);
        break;
      case 'isMuted':
        this.handlePlayerGetter('isMuted', args, result);
        break;
      case 'setMuted':
        this.handlePlayerSetter('setMuted', args, result);
        break;
      case 'enableHardwareDecoder':
        this.handlePlayerGetter('enableHardwareDecoder', args, result);
        break;
      case 'setEnableHardwareDecoder':
        this.handlePlayerSetter('setEnableHardwareDecoder', args, result);
        break;
      case 'setRenderFrameCallbackConfig':
        result.success(null);
        break;
      case 'setVidSts':
        this.handleSetVidSts(args, result);
        break;
      case 'setVidAuth':
        this.handleSetVidAuth(args, result);
        break;
      case 'setVidMps':
        this.handleSetVidMps(args, result);
        break;
      case 'setLiveSts':
        this.handleSetLiveSts(args, result);
        break;
      case 'updateLiveStsInfo':
        this.handleUpdateLiveStsInfo(args, result);
        break;
      case 'getRotateMode':
        this.handlePlayerGetter('getRotateMode', args, result);
        break;
      case 'setRotateMode':
        this.handlePlayerSetter('setRotateMode', args, result);
        break;
      case 'getScalingMode':
        this.handlePlayerGetter('getScalingMode', args, result);
        break;
      case 'setScalingMode':
        this.handlePlayerSetter('setScalingMode', args, result);
        break;
      case 'setOutputAudioChannel':
        result.success(null);
        break;
      case 'getMirrorMode':
        this.handlePlayerGetter('getMirrorMode', args, result);
        break;
      case 'setMirrorMode':
        this.handlePlayerSetter('setMirrorMode', args, result);
        break;
      case 'getAlPhaRenderMode':
        this.handlePlayerGetter('getAlPhaRenderMode', args, result);
        break;
      case 'setAlphaRenderMode':
        this.handlePlayerSetter('setAlphaRenderMode', args, result);
        break;
      case 'getSpeed':
        this.handlePlayerGetter('getSpeed', args, result);
        break;
      case 'setSpeed':
        this.handlePlayerSetter('setSpeed', args, result);
        break;
      case 'setVideoBackgroundColor':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'getVideoWidth':
        this.handlePlayerGetter('getVideoWidth', args, result);
        break;
      case 'getVideoHeight':
        this.handlePlayerGetter('getVideoHeight', args, result);
        break;
      case 'getVideoRotation':
        this.handlePlayerGetter('getVideoRotation', args, result);
        break;
      case 'setVolume':
        this.handlePlayerSetter('setVolume', args, result);
        break;
      case 'getVolume':
        this.handlePlayerGetter('getVolume', args, result);
        break;
      case 'getDuration':
        this.handlePlayerGetter('getDuration', args, result);
        break;
      case 'getCurrentPosition':
        this.handlePlayerGetter('getCurrentPosition', args, result);
        break;
      case 'getCurrentUtcTime':
        result.success(0);
        break;
      case 'getLocalCacheLoadedSize':
        result.success(0);
        break;
      case 'getCurrentDownloadSpeed':
        result.success(0);
        break;
      case 'getBufferedPosition':
        this.handlePlayerGetter('getBufferedPosition', args, result);
        break;
      case 'getConfig':
        this.handlePlayerGetter('getConfig', args, result);
        break;
      case 'getPlayConfig':
        result.success(new Map<string, Object>());
        break;
      case 'getPlayedDuration':
        this.handlePlayerGetter('getPlayedDuration', args, result);
        break;
      case 'setConfig':
        result.success(null);
        break;
      case 'setPlayConfig':
        result.success(null);
        break;
      case 'enableDowngrade':
        result.success(null);
        break;
      case 'setFilterConfig':
        result.success(null);
        break;
      case 'updateFilterConfig':
        result.success(null);
        break;
      case 'setFilterInvalid':
        result.success(null);
        break;
      case 'getCacheFilePath':
        result.success('');
        break;
      case 'getCacheFilePathWithVid':
        result.success('');
        break;
      case 'getMediaInfo':
        this.handlePlayerGetter('getMediaInfo', args, result);
        break;
      case 'getSubMediaInfo':
        this.handlePlayerGetter('getSubMediaInfo', args, result);
        break;
      case 'getCurrentTrack':
        this.handleGetCurrentTrack(args, result);
        break;
      case 'createThumbnailHelper':
        this.handleCreateThumbnailHelper(args, result);
        break;
      case 'requestBitmapAtPosition':
        this.handleRequestBitmapAtPosition(args, result);
        break;
      case 'setTraceID':
        result.success(null);
        break;
      case 'addExtSubtitle':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'selectExtSubtitle':
        this.handleSelectExtSubtitle(args, result);
        break;
      case 'setDefaultBandWidth':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'setDefaultResolution':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'setDefaultAudioLanguage':
        result.success(null);
        break;
      case 'setPlayerScene':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'selectTrack':
        this.handleSelectTrack(args, result);
        break;
      case 'setPreferPlayerName':
        result.success(null);
        break;
      case 'getPlayerName':
        result.success('AliPlayer');
        break;
      case 'sendCustomEvent':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'setUserData':
        this.handleSetUserData(args, result);
        break;
      case 'getUserData':
        this.handlePlayerGetter('getUserData', args, result);
        break;
      case 'setStreamDelayTime':
        this.handleSetStreamDelayTime(args, result);
        break;
      case 'reload':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'getOption':
        this.handleGetOption(args, result);
        break;
      case 'getPropertyString':
        this.handleGetPropertyString(args, result);
        break;
      case 'setConvertURLCallback':
        this.handleSetConvertURLCallback(args, result);
        break;
      case 'setOnStreamSwitchedListener':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'setOnURLSourceExpiredListener':
        result.success(null);
        break;
      case 'setOnVidAuthExpiredListener':
        result.success(null);
        break;
      case 'setOnPrepare':
        this.handleSetupBasicMessageChannel('aliPlayer_onPrepare', args, result);
        break;
      case 'setOnRenderingStart':
        this.handleSetupBasicMessageChannel('aliPlayer_onRenderingStart', args, result);
        break;
      case 'setOnStateChanged':
        this.handleSetupBasicMessageChannel('aliPlayer_onStateChanged', args, result);
        break;
      case 'setOnPreRenderFrameCallback':
        this.handleSetupBasicMessageChannel('onPreRenderFrame', args, result);
        break;
      case 'setOnRenderFrameCallback':
        this.handleSetupBasicMessageChannel('onRenderFrame', args, result);
        break;
      case 'setDrmCallback':
        this.handleSetupDRMChannels(args, result);
        break;
      case 'setPreloadCount':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'addVidSource':
        this.handleAddVidSource(args, result);
        break;
      case 'addUrlSource':
        this.handleAddUrlSource(args, result);
        break;
      case 'removeSource':
        this.handleRemoveSource(args, result);
        break;
      case 'getCurrentUid':
        this.handlePlayerGetter('getCurrentUid', args, result);
        break;
      case 'clear':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'setMaxPreloadMemorySizeMB':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'setDefinition':
        this.handlePlayerMethod(method, args, result);
        break;
      case 'moveToNext':
        this.handleMoveTo(args, result);
        break;
      case 'moveToPre':
        this.handleMoveTo(args, result);
        break;
      case 'moveTo':
        this.handleMoveTo(args, result);
        break;
      case 'updatePreloadConfig':
        this.handleUpdatePreloadConfig(args, result);
        break;
      case 'setPreloadScene':
        this.handleSetPreloadScene(args, result);
        break;
      case 'setMultiBitratesMode':
        this.handleSetMultiBitratesMode(args, result);
        break;
      case 'enablePreloadStrategy':
        this.handleEnablePreloadStrategy(args, result);
        break;
      case 'setPreloadStrategy':
        this.handleSetPreloadStrategy(args, result);
        break;
      case 'getCurrentLiveTime':
        this.handlePlayerGetter('getCurrentLiveTime', args, result);
        break;
      case 'getCurrentTime':
        this.handlePlayerGetter('getCurrentTime', args, result);
        break;
      case 'seekToLiveTime':
        this.handlePlayerMethodWithArg(method, args, result);
        break;
      case 'setDataSource':
        this.handleSetDataSource(args, result);
        break;
      case 'loadRtsLibrary':
      case 'showFloatViewForAndroid':
      case 'hideFloatViewForAndroid':
      case 'checkFloatViewPermission':
      case 'requestFloatViewPermission':
      case 'setFloatViewIcon':
      case 'setFloatViewUI':
      case 'initLicenseServiceForIOS':
      case 'setAudioSessionTypeForIOS':
      case 'setFairPlayCertIDForIOS':
      case 'enableHWAduioTempo':
      case 'forceAudioRendingFormat':
      case 'netWorkReConnect':
      case 'getCacheFilePathWithVidAtPreviewTime':
      case 'createDeviceInfo':
      case 'addBlackDevice':
      case 'setEventReportParamsDelegate':
        // 仅 Dart 层调用，OHOS 端无需实现
        result.success(null);
        break;
      case 'setPictureInPictureShowMode':
      case 'setPictureInPictureEnableForIOS':
        // Platform-specific methods - return notImplemented on OHOS
        result.notImplemented();
        break;
      default:
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Unhandled method=%{public}s', method);
        result.notImplemented();
        break;
    }
  }

  // --- Helper methods to get playerId from args ---
  private getPlayerId(args: Map<string, Object> | null): string {
    if (args !== null && args !== undefined) {
      const pid: Object | undefined = args.get('playerId');
      if (pid !== null && pid !== undefined) {
        return pid as string;
      }
    }
    return '';
  }

  private getPlayerArg(args: Map<string, Object> | null): Object | null {
    if (args !== null && args !== undefined) {
      const val: Object | undefined = args.get('arg');
      return val !== undefined ? val : null;
    }
    return null;
  }

  private getEntry(playerId: string): AliPlayerEntry | undefined {
    return this.playerEntries.get(playerId);
  }

  private ensureVidPlayerConfigGen(): VidPlayerConfigGen {
    if (this.vidPlayerConfigGen === null) {
      this.vidPlayerConfigGen = new VidPlayerConfigGen();
    }
    return this.vidPlayerConfigGen;
  }

  private objectToNumber(value: Object | null): number {
    if (value === null || value === undefined) {
      return 0;
    }
    if (typeof value === 'string') {
      return Number.parseInt(value as string);
    }
    return value as number;
  }

  private objectToString(value: Object | null): string {
    if (value === null || value === undefined) {
      return '';
    }
    return value as string;
  }

  private writeSnapshotFile(path: string, arrayBuffer: ArrayBuffer): void {
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, arrayBuffer);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'snapshot saved path=%{public}s size=%{public}d', path, arrayBuffer.byteLength);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'snapshot save failed path=%{public}s error=%{public}s',
        path, (error as Error).message);
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          hilog.error(LOG_DOMAIN, LOG_TAG, 'snapshot close failed path=%{public}s error=%{public}s',
            path, (error as Error).message);
        }
      }
    }
  }

  private encryptTypeFromIndex(value: number): EncryptType {
    if (value === 1) {
      return EncryptType.AliyunVodEncryption;
    }
    if (value === 2) {
      return EncryptType.HLSEncryption;
    }
    return EncryptType.Unencrypted;
  }

  private handleCreateVidPlayerConfigGenerator(result: MethodResult): void {
    this.vidPlayerConfigGen = new VidPlayerConfigGen();
    result.success(null);
  }

  private handleSetPreviewTime(rawArgs: Object | null, result: MethodResult): void {
    const config: VidPlayerConfigGen = this.ensureVidPlayerConfigGen();
    config.setPreviewTime(this.objectToNumber(rawArgs));
    result.success(null);
  }

  private handleSetHlsUriToken(rawArgs: Object | null, result: MethodResult): void {
    const config: VidPlayerConfigGen = this.ensureVidPlayerConfigGen();
    config.setMtsHlsUriToken(this.objectToString(rawArgs));
    result.success(null);
  }

  private handleAddVidPlayerConfigByStringValue(rawArgs: Object | null, result: MethodResult): void {
    const configMap: Map<string, Object> | null = rawArgs as Map<string, Object> | null;
    if (configMap !== null) {
      const config: VidPlayerConfigGen = this.ensureVidPlayerConfigGen();
      for (const entry of configMap) {
        config.addPlayerConfigString(entry[0], this.objectToString(entry[1]));
      }
    }
    result.success(null);
  }

  private handleAddVidPlayerConfigByIntValue(rawArgs: Object | null, result: MethodResult): void {
    const configMap: Map<string, Object> | null = rawArgs as Map<string, Object> | null;
    if (configMap !== null) {
      const config: VidPlayerConfigGen = this.ensureVidPlayerConfigGen();
      for (const entry of configMap) {
        config.addPlayerConfigNumber(entry[0], this.objectToNumber(entry[1]));
      }
    }
    result.success(null);
  }

  private handleSetEncryptType(rawArgs: Object | null, result: MethodResult): void {
    const config: VidPlayerConfigGen = this.ensureVidPlayerConfigGen();
    config.setEncryptType(this.encryptTypeFromIndex(this.objectToNumber(rawArgs)));
    result.success(null);
  }

  private handleGeneratePlayerConfig(result: MethodResult): void {
    const config: VidPlayerConfigGen = this.ensureVidPlayerConfigGen();
    result.success(config.genConfig());
  }

  // --- Factory Methods ---
  private handleCreateAliPlayer(args: Map<string, Object> | null, result: MethodResult): void {
    let playerId: string = '';
    let playerType: number = 0;
    if (args !== null && args !== undefined) {
      playerId = args.get('playerId') as string;
      const arg: Object | undefined = args.get('arg');
      if (arg !== null && arg !== undefined) {
        playerType = arg as number;
      }
    }
    if (playerId === '' || playerId === null || playerId === undefined) {
      playerId = 'player_' + Date.now().toString();
    }

    if (this.context === null) {
      result.error('ERROR', 'Context not available', null);
      return;
    }

    const entry: AliPlayerEntry = new AliPlayerEntry(this.context, playerId);
    this.playerEntries.set(playerId, entry);

    // Set up event forwarding
    this.setupEventForwarding(entry, playerId);

    // Create the actual AliPlayer
    entry.createPlayer(playerType).then(() => {
      // Setup BasicMessageChannels for this player
      this.setupBasicMessageChannelsForPlayer(playerId, entry);

      // Create AVSession for this player
      if (this.avSession !== null) {
        this.avSession.createSession('Aliplayer_' + playerId);
        this.avSession.setCommandCallback({
          onPlay: (): void => {
            entry.play();
          },
          onPause: (): void => {
            entry.pause();
          },
          onStop: (): void => {
            entry.stop();
          },
          onSeek: (position: number): void => {
            entry.seekTo(position, 1);
          },
          onSetSpeed: (speed: number): void => {
            entry.setSpeed(speed);
          },
          onSetLoopMode: (loopMode: number): void => {
            entry.setLoop(loopMode === 1);
          }
        });
        this.avSession.activate();
      }

      hilog.debug(LOG_DOMAIN, LOG_TAG, 'createAliPlayer success playerId=%{public}s', playerId);
      result.success(null);
    }).catch((error: Error) => {
      const message: string = this.normalizeCreatePlayerError(error.message);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'createAliPlayer error=%{public}s', message);
      result.error('ERROR', message, null);
    });
  }

  private normalizeCreatePlayerError(message: string): string {
    if (message.indexOf('JSBind') >= 0) {
      return message +
        '; AliPlayer native module is not available. Check that XComponent uses libraryname "premierlibrary" ' +
        'and run on an arm64 device because the AliPlayer OHOS SDK package does not include x86_64 native libs.';
    }
    return message;
  }

  private setupEventForwarding(entry: AliPlayerEntry, playerId: string): void {
    entry.onPrepared = (): void => {
      this.sendEvent('onPrepared', new Map<string, Object>());
      const msg: Map<string, Object> = new Map();
      msg.set('playerId', playerId);
      msg.set('method', 'onPrepared');
      this.sendBasicMessage(`aliPlayer_onPrepare$${playerId}`, msg);
      // Update AVSession
      this.avSession?.setPlaybackState(1, 0); // 1 = PLAYBACK_STATE_PLAYING
    };

    entry.onRenderingStart = (): void => {
      this.sendEvent('onRenderingStart', new Map<string, Object>());
      const msg: Map<string, Object> = new Map();
      msg.set('playerId', playerId);
      msg.set('method', 'onRenderingStart');
      this.sendBasicMessage(`aliPlayer_onRenderingStart$${playerId}`, msg);
    };

    entry.onStateChanged = (state: number): void => {
      const event: Map<string, Object> = new Map();
      event.set('playing', state === PLAYER_STATE_STARTED);
      this.sendEvent('setPlaying', event);
      const msg: Map<string, Object> = new Map();
      msg.set('playerId', playerId);
      msg.set('method', 'onStateChanged');
      msg.set('newState', state);
      this.sendBasicMessage(`aliPlayer_onStateChanged$${playerId}`, msg);
    };

    entry.onCompletion = (): void => {
      this.sendEvent('onCompletion', new Map<string, Object>());
      this.avSession?.setPlaybackState(AVSESSION_STATE_PAUSED, 0);
    };

    entry.onErrorHandler = (errorCode: number, errorMsg: string, errorExtra: string): void => {
      const event: Map<string, Object> = new Map();
      event.set('errorCode', errorCode);
      event.set('errorExtra', errorExtra);
      event.set('errorMsg', errorMsg);
      this.sendEvent('onError', event);
    };

    entry.onVideoSizeChanged = (width: number, height: number): void => {
      const event: Map<string, Object> = new Map();
      event.set('width', width);
      event.set('height', height);
      this.sendEvent('onVideoSizeChanged', event);
    };

    entry.onSeekComplete = (): void => {
      this.sendEvent('onSeekComplete', new Map<string, Object>());
    };

    entry.onLoadingBegin = (): void => {
      this.sendEvent('onLoadingBegin', new Map<string, Object>());
    };

    entry.onLoadingProgress = (percent: number, netSpeed: number): void => {
      const event: Map<string, Object> = new Map();
      event.set('percent', percent);
      event.set('netSpeed', netSpeed);
      this.sendEvent('onLoadingProgress', event);
    };

    entry.onLoadingEnd = (): void => {
      this.sendEvent('onLoadingEnd', new Map<string, Object>());
    };

    entry.onInfo = (infoCode: number, extraValue: number, extraMsg: string): void => {
      const event: Map<string, Object> = new Map();
      event.set('infoCode', infoCode);
      event.set('extraValue', extraValue);
      event.set('extraMsg', extraMsg);
      this.sendEvent('onInfo', event);
    };

    entry.onSnapShot = (arrayBuffer: ArrayBuffer, width: number, height: number): void => {
      const event: Map<string, Object> = new Map();
      const path: string = entry.lastSnapshotPath;
      if (path.length > 0) {
        this.writeSnapshotFile(path, arrayBuffer);
      }
      event.set('snapShotPath', path);
      event.set('width', width);
      event.set('height', height);
      this.sendEvent('onSnapShot', event);
    };

    entry.onSeiData = (type: number, data: Uint8Array): void => {
      const event: Map<string, Object> = new Map();
      event.set('type', type);
      event.set('data', data);
      this.sendEvent('onSeiData', event);
    };

    entry.onStreamSwitchedSuccess = (url: string): void => {
      const event: Map<string, Object> = new Map();
      event.set('url', url);
      this.sendEvent('StreamSwitch_onSwitchedSuccess', event);
    };

    entry.onStreamSwitchedFail = (url: string, errorCode: number, errorMsg: string): void => {
      const event: Map<string, Object> = new Map();
      event.set('url', url);
      event.set('errorCode', errorCode);
      event.set('errorMsg', errorMsg);
      this.sendEvent('StreamSwitch_onSwitchedFail', event);
    };

    entry.onTrackChanged = (trackInfo: Object): void => {
      this.sendEvent('onTrackChanged', new Map<string, Object>());
    };

    entry.onTrackReady = (mediaInfo: MediaInfo | null): void => {
      this.sendEvent('onTrackReady', new Map<string, Object>());
    };

    entry.onSubTrackReady = (mediaInfo: MediaInfo | null): void => {
      this.sendEvent('onSubTrackReady', new Map<string, Object>());
    };

    entry.onVideoRendered = (timeMs: number, pts: number): void => {
      const event: Map<string, Object> = new Map();
      event.set('timeMs', timeMs);
      event.set('pts', pts);
      this.sendEvent('onVideoRendered', event);
    };

    entry.onSubtitleExtAdded = (trackIndex: number, url: string): void => {
      const event: Map<string, Object> = new Map();
      event.set('trackIndex', trackIndex);
      event.set('url', url);
      this.sendEvent('onSubtitleExtAdded', event);
    };

    entry.onSubtitleShow = (trackIndex: number, id: number, data: string): void => {
      const event: Map<string, Object> = new Map();
      event.set('trackIndex', trackIndex);
      event.set('subtitleID', id);
      event.set('subtitle', data);
      this.sendEvent('onSubtitleShow', event);
    };

    entry.onSubtitleHide = (trackIndex: number, id: number): void => {
      const event: Map<string, Object> = new Map();
      event.set('trackIndex', trackIndex);
      event.set('subtitleID', id);
      this.sendEvent('onSubtitleHide', event);
    };

    entry.onSubtitleHeader = (trackIndex: number, header: string): void => {
      const event: Map<string, Object> = new Map();
      event.set('trackIndex', trackIndex);
      event.set('header', header);
      this.sendEvent('onSubtitleHeader', event);
    };
  }

  private sendEvent(eventName: string, data: Map<string, Object>): void {
    if (this.eventSinkAliplayer !== null) {
      const event: Map<string, Object> = new Map();
      event.set(eventName, data);
      this.eventSinkAliplayer.success(event);
    }
  }

  private sendBasicMessage(channelName: string, data: Object): void {
    const channel: BasicMessageChannel<Any> | undefined = this.basicMessageChannels.get(channelName);
    if (channel !== undefined) {
      channel.send(data as Any);
    }
  }

  // --- Surface ready callback ---
  private onSurfaceReady(viewId: string, surfaceId: string): void {
    const viewIdNum: number = Number.parseInt(viewId);
    const realPlayerId: string | undefined = this.viewToPlayerMap.get(viewIdNum);
    const targetPlayerId: string = realPlayerId !== undefined ? realPlayerId : viewId;
    const entry: AliPlayerEntry | undefined = this.playerEntries.get(targetPlayerId);
    if (entry === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'onSurfaceReady entry not found viewId=%{public}s realPlayerId=%{public}s',
        viewId, targetPlayerId);
      return;
    }
    entry.setSurfaceId(surfaceId);
    if (entry.currentState === 0 || entry.currentState === 1) {
      entry.prepare();
    }
  }

  // --- Player Methods ---
  private handlePlayerMethod(method: string, args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    switch (method) {
      case 'prepare':
        if (!entry.isSurfaceReady) {
          entry.prepare();
        } else {
          entry.prepare();
        }
        result.success(null);
        break;
      case 'play':
        entry.play();
        result.success(null);
        break;
      case 'pause':
        entry.pause();
        result.success(null);
        break;
      case 'stop':
        entry.stop();
        result.success(null);
        break;
      case 'clearScreen':
      case 'clearScreenSync':
        entry.player?.clearScreen();
        result.success(null);
        break;
      case 'reload':
        entry.player?.reload();
        result.success(null);
        break;
      case 'clear':
        // List player clear
        result.success(null);
        break;
      case 'setPreloadCount':
      case 'setMaxPreloadMemorySizeMB':
      case 'setDefinition':
        result.success(null);
        break;
      case 'setOnStreamSwitchedListener':
        // listener registration - already handled via events
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private handlePlayerMethodWithArg(method: string, args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    switch (method) {
      case 'setUrl':
        entry.setUrlDataSource(arg as string);
        result.success(null);
        break;
      case 'switchStream':
        entry.player?.switchStream(arg as string);
        result.success(null);
        break;
      case 'snapshot':
        entry.requestSnapshot(this.objectToString(arg));
        result.success(null);
        break;
      case 'setVideoBackgroundColor':
        entry.player?.setVideoBackgroundColor(arg as number);
        result.success(null);
        break;
      case 'setMaxAccurateSeekDelta':
        entry.player?.setMaxAccurateSeekDelta(arg as number);
        result.success(null);
        break;
      case 'addExtSubtitle':
        entry.player?.addExtSubtitle(arg as string);
        result.success(null);
        break;
      case 'setDefaultBandWidth':
        entry.player?.setDefaultBandWidth(arg as number);
        result.success(null);
        break;
      case 'setDefaultResolution':
        entry.player?.setDefaultResolution(arg as number);
        result.success(null);
        break;
      case 'setPlayerScene':
        entry.player?.setPlayerScene(arg as number);
        result.success(null);
        break;
      case 'sendCustomEvent':
        entry.player?.sendCustomEvent(arg as string);
        result.success(null);
        break;
      case 'seekToLiveTime':
        entry.player?.seekTo(arg as number, 1);
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private getListPlayer(args: Map<string, Object> | null, result: MethodResult): AliListPlayer | null {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'List player not found: ' + playerId, null);
      return null;
    }
    if (entry.playerType !== 1) {
      result.error('ERROR', 'Player is not AliListPlayer: ' + playerId, null);
      return null;
    }
    return entry.player as AliListPlayer;
  }

  private sceneTypeFromIndex(index: number): SceneType {
    if (index === 1) {
      return SceneType.SCENE_VERY_SHORT;
    }
    if (index === 2) {
      return SceneType.SCENE_SHORT;
    }
    if (index === 3) {
      return SceneType.SCENE_MIDDLE;
    }
    if (index === 4) {
      return SceneType.SCENE_LONG;
    }
    return SceneType.SCENE_NONE;
  }

  private multiBitratesModeFromIndex(index: number): MultiBitratesMode {
    if (index === 1) {
      return MultiBitratesMode.MultiBitratesMode_FCPrio;
    }
    if (index === 2) {
      return MultiBitratesMode.MultiBitratesMode_FC_AND_SMOOTH;
    }
    if (index === 3) {
      return MultiBitratesMode.MultiBitratesMode_SmoothPrio;
    }
    return MultiBitratesMode.MultiBitratesMode_Default;
  }

  private handleUpdatePreloadConfig(args: Map<string, Object> | null, result: MethodResult): void {
    result.notImplemented();
  }

  private handleSetPreloadScene(args: Map<string, Object> | null, result: MethodResult): void {
    const player: AliListPlayer | null = this.getListPlayer(args, result);
    if (player === null) {
      return;
    }
    const arg: Object | null = this.getPlayerArg(args);
    player.setPreloadScene(this.sceneTypeFromIndex(this.objectToNumber(arg)));
    result.success(null);
  }

  private handleSetMultiBitratesMode(args: Map<string, Object> | null, result: MethodResult): void {
    const player: AliListPlayer | null = this.getListPlayer(args, result);
    if (player === null) {
      return;
    }
    const arg: Object | null = this.getPlayerArg(args);
    player.SetMultiBitratesMode(this.multiBitratesModeFromIndex(this.objectToNumber(arg)));
    result.success(null);
  }

  private handleEnablePreloadStrategy(args: Map<string, Object> | null, result: MethodResult): void {
    const player: AliListPlayer | null = this.getListPlayer(args, result);
    if (player === null) {
      return;
    }
    const arg: Object | null = this.getPlayerArg(args);
    player.enablePreloadStrategy(StrategyType.STRATEGY_DYNAMIC_PRELOAD_DURATION, arg as boolean);
    result.success(null);
  }

  private handleSetPreloadStrategy(args: Map<string, Object> | null, result: MethodResult): void {
    const player: AliListPlayer | null = this.getListPlayer(args, result);
    if (player === null) {
      return;
    }
    const arg: Object | null = this.getPlayerArg(args);
    player.setPreloadStrategy(StrategyType.STRATEGY_DYNAMIC_PRELOAD_DURATION, this.objectToString(arg));
    result.success(null);
  }

  private handlePlayerSetter(method: string, args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    switch (method) {
      case 'setLoop':
        entry.setLoop(arg as boolean);
        result.success(null);
        break;
      case 'setAutoPlay':
        entry.setAutoPlay(arg as boolean);
        result.success(null);
        break;
      case 'setFastStart':
        entry.player?.setFastStart(arg as boolean);
        result.success(null);
        break;
      case 'setMuted':
        entry.setMute(arg as boolean);
        result.success(null);
        break;
      case 'setEnableHardwareDecoder':
        entry.enableHardwareDecoder(arg as boolean);
        result.success(null);
        break;
      case 'setRotateMode':
        entry.player?.setRotateMode(arg as number);
        result.success(null);
        break;
      case 'setScalingMode':
        entry.player?.setScaleMode(arg as ScaleMode);
        result.success(null);
        break;
      case 'setMirrorMode':
        entry.player?.setMirrorMode(arg as number);
        result.success(null);
        break;
      case 'setAlphaRenderMode':
        entry.player?.setAlphaRenderMode(arg as number);
        result.success(null);
        break;
      case 'setSpeed':
        entry.setSpeed(arg as number);
        result.success(null);
        break;
      case 'setVolume':
        entry.setVolume(arg as number);
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private handlePlayerGetter(method: string, args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    const player: AliPlayer = entry.player;

    switch (method) {
      case 'isLoop':
        result.success(player.isLoop());
        break;
      case 'isAutoPlay':
        result.success(player.isAutoPlay());
        break;
      case 'isMuted':
        result.success(player.isMuted());
        break;
      case 'enableHardwareDecoder':
        result.success(true);
        break;
      case 'getRotateMode':
        result.success(player.getRotateMode());
        break;
      case 'getScalingMode':
        result.success(player.getScaleMode());
        break;
      case 'getMirrorMode':
        result.success(player.getMirrorMode());
        break;
      case 'getAlPhaRenderMode':
        result.success(player.getAlphaRenderMode());
        break;
      case 'getSpeed':
        result.success(entry.pendingSpeed);
        break;
      case 'getVideoWidth':
        result.success(player.getVideoWidth());
        break;
      case 'getVideoHeight':
        result.success(player.getVideoHeight());
        break;
      case 'getVideoRotation':
        result.success(player.getVideoRotation());
        break;
      case 'getVolume':
        result.success(entry.pendingVolume);
        break;
      case 'getDuration':
        result.success(player.getDuration());
        break;
      case 'getCurrentPosition':
        result.success(player.getCurrentPosition());
        break;
      case 'getPlayedDuration':
        result.success(player.getPlayedDuration());
        break;
      case 'getBufferedPosition':
        result.success(player.getBufferedPosition());
        break;
      case 'getConfig':
        result.success({});
        break;
      case 'getMediaInfo':
        const mediaInfo: MediaInfo | null = player.getMediaInfo();
        if (mediaInfo !== null) {
          result.success({});
        } else {
          result.success(null);
        }
        break;
      case 'getSubMediaInfo':
        const subMediaInfo: MediaInfo | null = player.getSubMediaInfo();
        if (subMediaInfo !== null) {
          result.success({});
        } else {
          result.success(null);
        }
        break;
      case 'getUserData':
        result.success(player.getUserData());
        break;
      case 'getCurrentUid':
        result.success('');
        break;
      case 'getCurrentLiveTime':
        result.success(0);
        break;
      case 'getCurrentTime':
        result.success(player.getCurrentPosition());
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private handleSeekTo(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const seekArgs: Map<string, Object> = arg as Map<string, Object>;
      const position: number = seekArgs.get('position') as number;
      const seekMode: number = seekArgs.get('seekMode') as number;
      entry.seekTo(position, seekMode);
    }
    result.success(null);
  }

  private handleSetStartTime(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const startArgs: Map<string, Object> = arg as Map<string, Object>;
      const time: number = startArgs.get('time') as number;
      const seekMode: number = startArgs.get('seekMode') as number;
      entry.player.setStartTime(time, seekMode);
    }
    result.success(null);
  }

  private handleSetOption(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found', null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const optionArgs: Map<string, Object> = arg as Map<string, Object>;
      const opt1: number = optionArgs.get('opt1') as number;
      const opt2: Object = optionArgs.get('opt2') as Object;
      if (typeof opt2 === 'number') {
        entry.player.setOptionNum(opt1, opt2 as number);
      } else if (typeof opt2 === 'string') {
        entry.player.setOption(opt1.toString(), opt2 as string);
      }
    }
    result.success(null);
  }

  private handlePlayerDestroy(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    if (entry !== undefined) {
      entry.destroy();
      this.playerEntries.delete(playerId);
      // Clean up basic message channels
      this.cleanupBasicChannelsForPlayer(playerId);
    }
    result.success(null);
  }

  private handlePlayerReleaseAsync(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    if (entry !== undefined) {
      entry.releaseAsync();
      this.playerEntries.delete(playerId);
      this.cleanupBasicChannelsForPlayer(playerId);
    }
    result.success(null);
  }

  // --- VidSource Methods ---
  private handleSetVidSts(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const stsArgs: Map<string, Object> = arg as Map<string, Object>;
      entry.setVidStsDataSource(
        stsArgs.get('vid') as string,
        stsArgs.get('region') as string | null,
        stsArgs.get('accessKeyId') as string | null,
        stsArgs.get('accessKeySecret') as string | null,
        stsArgs.get('securityToken') as string | null,
        stsArgs.get('playConfig') as string | null,
        stsArgs.get('quality') as string,
        stsArgs.get('forceQuality') as boolean
      );
    }
    result.success(null);
  }

  private handleSetVidAuth(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const authArgs: Map<string, Object> = arg as Map<string, Object>;
      entry.setVidAuthDataSource(
        authArgs.get('vid') as string,
        authArgs.get('region') as string | null,
        authArgs.get('playAuth') as string | null,
        authArgs.get('playConfig') as string | null,
        authArgs.get('quality') as string,
        authArgs.get('forceQuality') as boolean
      );
    }
    result.success(null);
  }

  private handleSetVidMps(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const mpsArgs: Map<string, Object> = arg as Map<string, Object>;
      entry.setVidMpsDataSource(mpsArgs);
    }
    result.success(null);
  }

  private handleSetLiveSts(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const liveArgs: Map<string, Object> = arg as Map<string, Object>;
      entry.setLiveStsDataSource(
        liveArgs.get('url') as string | null,
        liveArgs.get('accessKeyId') as string | null,
        liveArgs.get('accessKeySecret') as string | null,
        liveArgs.get('securityToken') as string | null,
        liveArgs.get('region') as string | null,
        liveArgs.get('domain') as string | null,
        liveArgs.get('app') as string | null,
        liveArgs.get('stream') as string | null
      );
    }
    result.success(null);
  }

  private handleUpdateLiveStsInfo(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const stsInfoArgs: Map<string, Object> = arg as Map<string, Object>;
      const stsInfo: StsInfo = new StsInfo();
      stsInfo.setAccessKeyId(stsInfoArgs.get('accId') as string);
      stsInfo.setAccessKeySecret(stsInfoArgs.get('accKey') as string);
      stsInfo.setSecurityToken(stsInfoArgs.get('token') as string);
      stsInfo.setRegion(stsInfoArgs.get('region') as string);
      (entry.player as AliPlayer).updateStsInfo(stsInfo);
    }
    result.success(null);
  }

  // --- Other methods ---
  private handleGetSDKVersion(result: MethodResult): void {
    result.success(AliPlayerGlobalSettings.getSdkVersion());
  }

  private handleGetDeviceUUID(result: MethodResult): void {
    result.error('UNSUPPORTED', 'AliPlayer OHOS SDK does not expose a public getDeviceUUID API.', null);
  }

  private handleIsFeatureSupport(args: Object | null, result: MethodResult): void {
    result.success(true);
  }

  private handleEnableConsoleLog(args: Object | null, result: MethodResult): void {
    try {
      const logger: Logger = Logger.getInstance(this.context as Context);
      logger.enableConsoleLog(args === true);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'enableConsoleLog error=%{public}s', (error as Error).message);
    }
    result.success(null);
  }

  private handleSetLogLevel(args: Object | null, result: MethodResult): void {
    try {
      const logger: Logger = Logger.getInstance(this.context as Context);
      if (typeof args === 'number') {
        logger.setLogLevel(args);
      }
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setLogLevel error=%{public}s', (error as Error).message);
    }
    result.success(null);
  }

  private handleGetLogLevel(result: MethodResult): void {
    try {
      const logger: Logger = Logger.getInstance(this.context as Context);
      result.success(logger.getLogLevel());
    } catch (error) {
      result.success(0);
    }
  }

  private handleSetLogInfoBlock(args: Object | null, result: MethodResult): void {
    result.success(null);
  }

  private handleSetLogOption(args: Object | null, result: MethodResult): void {
    result.success(null);
  }

  private handleSetUseHttp2(args: Object | null, result: MethodResult): void {
    if (typeof args === 'boolean') {
      AliPlayerGlobalSettings.setUseHttp2(args);
    }
    result.success(null);
  }

  private handleEnableHttpDns(args: Object | null, result: MethodResult): void {
    if (typeof args === 'boolean') {
      AliPlayerGlobalSettings.enableHttpDns(args);
    }
    result.success(null);
  }

  private handleSetDNSResolve(args: Object | null, result: MethodResult): void {
    if (args !== null) {
      const dnsArgs: Map<string, Object> = args as Map<string, Object>;
      const host: string = dnsArgs.get('host') as string;
      const ip: string = dnsArgs.get('ip') as string;
      AliPlayerGlobalSettings.setDNSResolve(host, ip);
    }
    result.success(null);
  }

  private handleSetIpResolveType(args: Object | null, result: MethodResult): void {
    if (typeof args === 'number') {
      AliPlayerGlobalSettings.setIPResolveType(args);
    } else if (typeof args === 'string') {
      AliPlayerGlobalSettings.setIPResolveType(Number.parseInt(args));
    }
    result.success(null);
  }

  private handleEnableNetworkBalance(args: Object | null, result: MethodResult): void {
    if (typeof args === 'boolean') {
      AliPlayerGlobalSettings.enableNetworkBalance(args);
    }
    result.success(null);
  }

  private handleEnableLocalCache(args: Map<string, Object> | null, result: MethodResult): void {
    if (args !== null) {
      const enable: boolean = args.get('enable') as boolean;
      const maxBufferMemoryKB: string = args.get('maxBufferMemoryKB') as string;
      const localCacheDir: string = args.get('localCacheDir') as string;
      AliPlayerGlobalSettings.enableLocalCache(enable,
        Number.parseInt(maxBufferMemoryKB), localCacheDir);
    }
    result.success(null);
  }

  private handleSetCacheFileClearConfig(args: Map<string, Object> | null, result: MethodResult): void {
    if (args !== null) {
      const expireMin: string = args.get('expireMin') as string;
      const maxCapacityMB: string = args.get('maxCapacityMB') as string;
      const freeStorageMB: string = args.get('freeStorageMB') as string;
      AliPlayerGlobalSettings.setCacheFileClearConfig(
        Number.parseInt(expireMin), Number.parseInt(maxCapacityMB), Number.parseInt(freeStorageMB));
    }
    result.success(null);
  }

  private handleClearCaches(result: MethodResult): void {
    AliPlayerGlobalSettings.clearCaches();
    result.success(null);
  }

  private handleSetPlayerView(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const arg: Object | null = this.getPlayerArg(args);
    if (arg !== null) {
      const viewId: number = arg as number;
      this.viewToPlayerMap.set(viewId, playerId);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'setPlayerView mapping viewId=%{public}d -> playerId=%{public}s', viewId, playerId);
      // 检查是否有待绑定的 surface（XComponent onLoad 可能在 player 创建前已完成）
      const pendingSurfaceId: string | undefined = VideoViewRegistry.getPendingSurfaceId(viewId);
      if (pendingSurfaceId !== undefined) {
        const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
        if (entry !== undefined && entry.player !== null) {
          entry.setSurfaceId(pendingSurfaceId);
          VideoViewRegistry.removePendingSurfaceId(viewId);
          hilog.info(LOG_DOMAIN, LOG_TAG, 'setPlayerView bound pending surface for playerId=%{public}s', playerId);
          if (entry.currentState === 0 || entry.currentState === 1) {
            entry.prepare();
          }
        }
      }
    }
    result.success(null);
  }

  private handleGetCurrentTrack(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    if (entry !== undefined && entry.player !== null) {
      const arg: Object | null = this.getPlayerArg(args);
      if (arg !== null && arg !== undefined) {
        const trackIdx: number = arg as number;
        const trackInfo: TrackInfo | null = entry.player.currentTrack(trackIdx as TrackType);
        if (trackInfo !== null) {
          result.success({});
        } else {
          result.success(null);
        }
      } else {
        result.success(null);
      }
    } else {
      result.error('ERROR', 'Player not found', null);
    }
  }

  private handleCreateThumbnailHelper(args: Map<string, Object> | null, result: MethodResult): void {
    result.success({});
  }

  private handleRequestBitmapAtPosition(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(0);
  }

  private handleSelectExtSubtitle(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found', null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const subArgs: Map<string, Object> = arg as Map<string, Object>;
      const trackIndex: number = subArgs.get('trackIndex') as number;
      const enable: boolean = subArgs.get('enable') as boolean;
      entry.player.selectExtSubtitle(trackIndex, enable);
    }
    result.success(null);
  }

  private handleSelectTrack(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found', null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const trackArgs: Map<string, Object> = arg as Map<string, Object>;
      const trackIdx: number = trackArgs.get('trackIdx') as number;
      entry.player.selectTrack(trackIdx);
    }
    result.success(null);
  }

  private handleSetUserData(args: Map<string, Object> | null, result: MethodResult): void {
    const entry: AliPlayerEntry | undefined = this.getEntry(this.getPlayerId(args));
    if (entry !== null && entry !== undefined && entry.player !== null) {
      entry.player.setUserData(args?.get('arg') as string);
    }
    result.success(null);
  }

  private handleSetStreamDelayTime(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found', null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const delayArgs: Map<string, Object> = arg as Map<string, Object>;
      const index: number = delayArgs.get('index') as number;
      const time: number = delayArgs.get('time') as number;
      entry.player.setStreamDelay(index, time);
    }
    result.success(null);
  }

  private handleGetOption(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found', null);
      return;
    }
    const key: string = arg as string;
    const optionValue: string | number | undefined = entry.player.getOption(key);
    if (optionValue !== undefined) {
      result.success(optionValue);
    } else {
      result.success('');
    }
  }

  private handleGetPropertyString(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined || entry.player === null) {
      result.error('ERROR', 'Player not found', null);
      return;
    }
    const key: string = arg as string;
    result.success(entry.player.getPropertyString(Number.parseInt(key) as PropertyKey));
  }

  // --- BasicMessageChannel Setup ---
  private setupBasicMessageChannelsForPlayer(playerId: string, entry: AliPlayerEntry): void {
    // These channels are created per-player for bidirectional communication
    const channelNames: string[] = [
      `aliPlayer_onPrepare$${playerId}`,
      `aliPlayer_onRenderingStart$${playerId}`,
      `aliPlayer_onStateChanged$${playerId}`,
      `aliPlayer_onURLSourceExpiredListener$${playerId}`,
      `aliPlayer_OnVidAuthExpiredListener$${playerId}`,
      `listPlayer_onPrepare$${playerId}`,
      `listPlayer_onRenderingStart$${playerId}`,
      `listPlayer_onStateChanged$${playerId}`
    ];

    for (const name of channelNames) {
      const channel: BasicMessageChannel<Any> = new BasicMessageChannel<Any>(
        this.binaryMessenger!, name, new StandardMessageCodec());
      this.basicMessageChannels.set(name, channel);
    }
  }

  private handleSetupBasicMessageChannel(channelPrefix: string, args: Map<string, Object> | null, result: MethodResult): void {
    // Setup is done in setupBasicMessageChannelsForPlayer
    result.success(null);
  }

  private handleSetupDRMChannels(args: Map<string, Object> | null, result: MethodResult): void {
    if (this.binaryMessenger !== null) {
      const requestProvisionChannel: BasicMessageChannel<Any> = new BasicMessageChannel<Any>(
        this.binaryMessenger, 'requestProvision', new StandardMessageCodec());
      this.basicMessageChannels.set('requestProvision', requestProvisionChannel);

      const requestKeyChannel: BasicMessageChannel<Any> = new BasicMessageChannel<Any>(
        this.binaryMessenger, 'requestKey', new StandardMessageCodec());
      this.basicMessageChannels.set('requestKey', requestKeyChannel);
    }
    result.success(null);
  }

  private handleSetConvertURLCallback(args: Map<string, Object> | null, result: MethodResult): void {
    if (this.binaryMessenger !== null) {
      const channel: BasicMessageChannel<Any> = new BasicMessageChannel<Any>(
        this.binaryMessenger, 'convertURL', new StandardMessageCodec());
      this.basicMessageChannels.set('convertURL', channel);
    }
    result.success(null);
  }

  private cleanupBasicChannelsForPlayer(playerId: string): void {
    const prefixes: string[] = [
      `aliPlayer_onPrepare$${playerId}`,
      `aliPlayer_onRenderingStart$${playerId}`,
      `aliPlayer_onStateChanged$${playerId}`,
      `aliPlayer_onURLSourceExpiredListener$${playerId}`,
      `aliPlayer_OnVidAuthExpiredListener$${playerId}`,
      `listPlayer_onPrepare$${playerId}`,
      `listPlayer_onRenderingStart$${playerId}`,
      `listPlayer_onStateChanged$${playerId}`
    ];

    for (const name of prefixes) {
      const channel: BasicMessageChannel<Any> | undefined = this.basicMessageChannels.get(name);
      if (channel !== undefined) {
        channel.setMessageHandler(null);
        this.basicMessageChannels.delete(name);
      }
    }
  }

  // --- Handle set data source for live shift ---
  private handleSetDataSource(args: Map<string, Object> | null, result: MethodResult): void {
    const playerId: string = this.getPlayerId(args);
    const entry: AliPlayerEntry | undefined = this.getEntry(playerId);
    const arg: Object | null = this.getPlayerArg(args);

    if (entry === undefined) {
      result.error('ERROR', 'Player not found: ' + playerId, null);
      return;
    }

    if (arg !== null && arg !== undefined) {
      const dataSourceArgs: Map<string, Object> = arg as Map<string, Object>;
      const url: string = dataSourceArgs.get('url') as string;
      entry.setUrlDataSource(url);
    }
    result.success(null);
  }

  // --- List Player Methods ---
  private handleAddVidSource(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }

  private handleAddUrlSource(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }

  private handleRemoveSource(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }

  private handleMoveTo(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }
}
