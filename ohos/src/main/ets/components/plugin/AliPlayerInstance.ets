/**
 * 阿里云播放器实例封装
 * 
 * 负责单个播放器实例的生命周期管理、状态机控制、事件分发
 * 使用 premierlibrary SDK 实现真实播放功能
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import {
  AliPlayerFactory,
  AliPlayer,
  UrlSource,
  VidAuth,
  VidSts,
  IPlayer,
  ErrorInfo,
  InfoBean,
  InfoCode,
  MediaInfo,
  TrackInfo,
  TrackType,
  PlayerConfig,
} from 'premierlibrary';
import {
  ScaleMode,
  RotateMode,
  MirrorMode,
  AlphaRenderMode
} from 'premierlibrary/src/main/ets/com/aliyun/player/IPlayer';
import { IPlayerInstance } from './IPlayerInstance';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliPlayerInstance';

export class AliPlayerInstance implements IPlayerInstance {
  private playerId: string;
  private context: common.Context | null = null;
  private player: AliPlayer | null = null;
  private eventSink: EventSink | null = null;
  
  private surfaceId: string = '';
  private isSurfaceReady: boolean = false;
  private isPrepared: boolean = false;
  private url: string = '';
  private videoWidth: number = 0;
  private videoHeight: number = 0;
  
  constructor(playerId: string) {
    this.playerId = playerId;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'AliPlayerInstance created: %{public}s', playerId);
  }
  
  setContext(context: common.Context): void {
    this.context = context;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Context set for player: %{public}s', this.playerId);
  }
  
  init(): void {
    console.info('[AliPlayerInstance] Initializing player: ' + this.playerId);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Initializing player: %{public}s', this.playerId);
    
    if (this.context === null) {
      console.error('[AliPlayerInstance] Context is null, cannot create player');
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Context is null, cannot create player');
      return;
    }
    
    try {
      console.info('[AliPlayerInstance] Creating AliPlayer with context...');
      this.player = AliPlayerFactory.createAliPlayer(this.context);
      console.info('[AliPlayerInstance] AliPlayer created, setting up listeners...');
      this.setupListeners();
      console.info('[AliPlayerInstance] Player created successfully: ' + this.playerId);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Player created successfully: %{public}s', this.playerId);
    } catch (err) {
      const error = err as Error;
      console.error('[AliPlayerInstance] Failed to create player: ' + error.message);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to create player: %{public}s', error.message);
    }
  }
  
  private setupListeners(): void {
    if (this.player === null) {
      console.error('[AliPlayerInstance] setupListeners: player is null');
      return;
    }
    
    console.info('[AliPlayerInstance] Setting up listeners for: ' + this.playerId);
    
    this.player.setOnPreparedListener({
      onPrepared: () => {
        console.info('[AliPlayerInstance] onPrepared callback: ' + this.playerId);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onPrepared: %{public}s', this.playerId);
        this.isPrepared = true;
        this.sendEvent('onPrepared');
      }
    });
    
    this.player.setOnRenderingStartListener({
      onRenderingStart: () => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onRenderingStart: %{public}s', this.playerId);
        this.sendEvent('onRenderingStart');
      }
    });
    
    this.player.setOnStateChangedListener({
      onStateChanged: (newState: number) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onStateChanged: %{public}s state=%{public}d', this.playerId, newState);
        this.sendEventWithArg('onStateChanged', 'newState', newState);
      }
    });
    
    this.player.setOnCompletionListener({
      onCompletion: () => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onCompletion: %{public}s', this.playerId);
        this.sendEvent('onCompletion');
      }
    });
    
    this.player.setOnErrorListener({
      onError: (errorInfo: ErrorInfo) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'onError: %{public}s code=%{public}d msg=%{public}s', 
          this.playerId, errorInfo.getCode(), errorInfo.getMsg());
        const event = new Map<string, Object>();
        event.set('method', 'onError');
        event.set('playerId', this.playerId);
        event.set('errorCode', errorInfo.getCode());
        event.set('errorMsg', errorInfo.getMsg());
        event.set('errorExtra', errorInfo.getExtra());
        if (this.eventSink !== null) {
          this.eventSink.success(event);
        }
      }
    });
    
    this.player.setOnInfoListener({
      onInfo: (infoBean: InfoBean) => {
        const code = infoBean.getCode();
        if (code === InfoCode.CurrentPosition) {
          this.sendEventWithArgs('onInfo', [
            ['infoCode', code],
            ['extraValue', infoBean.getExtraValue()]
          ]);
        } else if (code === InfoCode.BufferedPosition) {
          this.sendEventWithArgs('onInfo', [
            ['infoCode', code],
            ['extraValue', infoBean.getExtraValue()]
          ]);
        } else if (code === InfoCode.CurrentDownloadSpeed) {
          this.sendEventWithArgs('onInfo', [
            ['infoCode', code],
            ['extraValue', infoBean.getExtraValue()]
          ]);
        }
      }
    });
    
    this.player.setOnVideoSizeChangedListener({
      onVideoSizeChanged: (width: number, height: number) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onVideoSizeChanged: %{public}s %{public}dx%{public}d', 
          this.playerId, width, height);
        // 缓存视频尺寸
        this.videoWidth = width;
        this.videoHeight = height;
        const event = new Map<string, Object>();
        event.set('method', 'onVideoSizeChanged');
        event.set('playerId', this.playerId);
        event.set('width', width);
        event.set('height', height);
        if (this.eventSink !== null) {
          this.eventSink.success(event);
        }
      }
    });
    
    this.player.setOnSeekCompleteListener({
      onSeekComplete: () => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onSeekComplete: %{public}s', this.playerId);
        this.sendEvent('onSeekComplete');
      }
    });
    
    this.player.setOnLoadingStatusListener({
      onLoadingBegin: () => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onLoadingBegin: %{public}s', this.playerId);
        this.sendEvent('onLoadingBegin');
      },
      onLoadingProgress: (percent: number, netSpeed: number) => {
        const event = new Map<string, Object>();
        event.set('method', 'onLoadingProgress');
        event.set('playerId', this.playerId);
        event.set('percent', percent);
        event.set('netSpeed', netSpeed);
        if (this.eventSink !== null) {
          this.eventSink.success(event);
        }
      },
      onLoadingEnd: () => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onLoadingEnd: %{public}s', this.playerId);
        this.sendEvent('onLoadingEnd');
      }
    });
    
    this.player.setOnTrackReadyListener({
      onTrackReady: (mediaInfo: MediaInfo) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onTrackReady: %{public}s', this.playerId);
        this.sendEvent('onTrackReady');
      }
    });
    
        this.player.setOnSnapShotListener({
      onSnapShot: async (data: ArrayBuffer, width: number, height: number) => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onSnapShot: %{public}s %{public}dx%{public}d size=%{public}d', 
          this.playerId, width, height, data.byteLength);
        let savedPath: string = '';
        if (data.byteLength > 0 && this.context !== null) {
          try {
            const filesDir = this.context.filesDir;
            const fileName = 'snapshot_' + Date.now() + '.jpg';
            savedPath = filesDir + '/' + fileName;
            
            const pixelMap = await image.createPixelMap(data, {
              size: { width: width, height: height },
              pixelFormat: image.PixelMapFormat.RGBA_8888,
              editable: true
            });
            
            const packingOption: image.PackingOption = {
              format: 'image/jpeg',
              quality: 90
            };
            const imagePacker = image.createImagePacker();
            const packData = await imagePacker.packing(pixelMap, packingOption);
            
            const fd = fs.openSync(savedPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
            fs.writeSync(fd.fd, packData);
            fs.closeSync(fd);
            
            imagePacker.release();
            pixelMap.release();
            
            hilog.info(LOG_DOMAIN, LOG_TAG, 'Snapshot saved: %{public}s', savedPath);
          } catch (err) {
            hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to save snapshot: %{public}s', (err as Error).message);
          }
        }
        this.sendEventWithArgs('onSnapShot', [
          ['width', width],
          ['height', height],
          ['snapShotPath', savedPath]
        ]);
      }
    });
    
    this.player.setOnSubtitleDisplayListener({
      onSubtitleExtAdded: (trackIndex: number, url: string) => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onSubtitleExtAdded: %{public}s trackIndex=%{public}d url=%{public}s', 
          this.playerId, trackIndex, url);
        this.sendEventWithArgs('onSubtitleExtAdded', [
          ['trackIndex', trackIndex],
          ['url', url]
        ]);
      },
      onSubtitleShow: (trackIndex: number, subtitleID: number, subtitle: string) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onSubtitleShow: %{public}s trackIndex=%{public}d subtitleID=%{public}d', 
          this.playerId, trackIndex, subtitleID);
        this.sendEventWithArgs('onSubtitleShow', [
          ['trackIndex', trackIndex],
          ['subtitleID', subtitleID],
          ['subtitle', subtitle]
        ]);
      },
      onSubtitleHide: (trackIndex: number, subtitleID: number) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onSubtitleHide: %{public}s trackIndex=%{public}d subtitleID=%{public}d', 
          this.playerId, trackIndex, subtitleID);
        this.sendEventWithArgs('onSubtitleHide', [
          ['trackIndex', trackIndex],
          ['subtitleID', subtitleID]
        ]);
      },
      onSubtitleHeader: (trackIndex: number, header: string) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onSubtitleHeader: %{public}s trackIndex=%{public}d', 
          this.playerId, trackIndex);
        this.sendEventWithArgs('onSubtitleHeader', [
          ['trackIndex', trackIndex],
          ['header', header]
        ]);
      }
    });
  }
  
  setEventSink(sink: EventSink | null): void {
    this.eventSink = sink;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setEventSink: %{public}s sink=%{public}s', this.playerId, sink !== null ? 'valid' : 'null');
    
    if (sink !== null && this.isSurfaceReady) {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Sending delayed onSurfaceReady event for %{public}s', this.playerId);
      this.sendEvent('onSurfaceReady');
    }
  }
  
  setSurfaceId(surfaceId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setSurfaceId: %{public}s surfaceId=%{public}s', this.playerId, surfaceId);
    this.surfaceId = surfaceId;
    this.isSurfaceReady = true;
    
    if (this.player !== null) {
      try {
        this.player.setSurfaceId(surfaceId);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'SurfaceId set successfully: %{public}s', surfaceId);
        this.sendEvent('onSurfaceReady');
      } catch (err) {
        const error = err as Error;
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set surfaceId: %{public}s', error.message);
      }
    }
  }
  
  clearSurfaceId(): void {
    this.surfaceId = '';
    this.isSurfaceReady = false;
  }
  
  setViewId(viewId: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setViewId: %{public}d', viewId);
  }
  
  clearViewId(): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'clearViewId');
  }
  
  setUrl(url: string): void {
    console.info('[AliPlayerInstance] setUrl: ' + this.playerId + ' url=' + url);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setUrl: %{public}s url=%{public}s', this.playerId, url);
    this.url = url;
    
    if (this.player === null) {
      console.error('[AliPlayerInstance] Player is null, cannot set URL');
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Player is null, cannot set URL');
      return;
    }
    
    try {
      console.info('[AliPlayerInstance] Creating UrlSource...');
      const urlSource = new UrlSource();
      urlSource.setUri(url);
      console.info('[AliPlayerInstance] Setting URL data source...');
      this.player.setUrlDataSource(urlSource);
      console.info('[AliPlayerInstance] URL set successfully: ' + url);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'URL set successfully: %{public}s', url);
    } catch (err) {
      const error = err as Error;
      console.error('[AliPlayerInstance] Failed to set URL: ' + error.message);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set URL: %{public}s', error.message);
    }
  }
  
  setVidAuth(vid: string, playAuth: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setVidAuth: %{public}s vid=%{public}s', this.playerId, vid);
    
    if (this.player === null) return;
    
    try {
      const vidAuth = new VidAuth();
      vidAuth.setVid(vid);
      vidAuth.setPlayAuth(playAuth);
      (this.player as AliPlayer).setVidAuthDataSource(vidAuth);
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set VidAuth: %{public}s', (err as Error).message);
    }
  }
  
  setVidSts(vid: string, accessKeyId: string, accessKeySecret: string, securityToken: string, region: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setVidSts: %{public}s vid=%{public}s', this.playerId, vid);
    
    if (this.player === null) return;
    
    try {
      const vidSts = new VidSts();
      vidSts.setVid(vid);
      vidSts.setAccessKeyId(accessKeyId);
      vidSts.setAccessKeySecret(accessKeySecret);
      vidSts.setSecurityToken(securityToken);
      vidSts.setRegion(region);
      (this.player as AliPlayer).setVidStsDataSource(vidSts);
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set VidSts: %{public}s', (err as Error).message);
    }
  }
  
  prepare(): void {
    console.info('[AliPlayerInstance] prepare: ' + this.playerId);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'prepare: %{public}s', this.playerId);
    
    if (this.player === null) {
      console.error('[AliPlayerInstance] Player is null, cannot prepare');
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Player is null, cannot prepare');
      return;
    }
    
    try {
      console.info('[AliPlayerInstance] Calling player.prepare()...');
      this.player.prepare();
      console.info('[AliPlayerInstance] prepare() called successfully');
      hilog.info(LOG_DOMAIN, LOG_TAG, 'prepare() called successfully');
    } catch (err) {
      const error = err as Error;
      console.error('[AliPlayerInstance] Failed to prepare: ' + error.message);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to prepare: %{public}s', error.message);
    }
  }
  
  play(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'play: %{public}s', this.playerId);
    
    if (this.player === null) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Player is null, cannot play');
      return;
    }
    
    try {
      this.player.start();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'play() called successfully');
    } catch (err) {
      const error = err as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to play: %{public}s', error.message);
    }
  }
  
  pause(): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'pause: %{public}s', this.playerId);
    
    if (this.player !== null) {
      try {
        this.player.pause();
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to pause: %{public}s', (err as Error).message);
      }
    }
  }
  
  stop(): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'stop: %{public}s', this.playerId);
    
    if (this.player !== null) {
      try {
        this.player.stop();
        this.isPrepared = false;
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to stop: %{public}s', (err as Error).message);
      }
    }
  }
  
  seekTo(positionMs: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'seekTo: %{public}s position=%{public}d', this.playerId, positionMs);
    
    if (this.player !== null) {
      try {
        this.player.seekTo(positionMs, 1);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to seek: %{public}s', (err as Error).message);
      }
    }
  }
  
  setVolume(volume: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setVolume: %{public}s volume=%{public}f', this.playerId, volume);
    
    if (this.player !== null) {
      try {
        this.player.setVolume(volume);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set volume: %{public}s', (err as Error).message);
      }
    }
  }
  
  getVolume(): number {
    if (this.player !== null) {
      try {
        return this.player.getVolume();
      } catch (err) {
        return 1.0;
      }
    }
    return 1.0;
  }
  
  setStartTime(position: number, seekMode: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setStartTime: %{public}s position=%{public}d mode=%{public}d',
      this.playerId, position, seekMode);
    
    if (this.player !== null) {
      try {
        this.player.setStartTime(position, seekMode);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set start time: %{public}s', (err as Error).message);
      }
    }
  }
  
  setMaxAccurateSeekDelta(delta: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setMaxAccurateSeekDelta: %{public}s delta=%{public}d', this.playerId, delta);
    
    if (this.player !== null) {
      try {
        this.player.setMaxAccurateSeekDelta(delta);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG,
          'Failed to set max accurate seek delta: %{public}s', (err as Error).message);
      }
    }
  }
  
  setSpeed(speed: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setSpeed: %{public}s speed=%{public}f', this.playerId, speed);
    
    if (this.player !== null) {
      try {
        this.player.setSpeed(speed);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set speed: %{public}s', (err as Error).message);
      }
    }
  }
  
  setLoop(loop: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setLoop: %{public}s loop=%{public}d', this.playerId, loop ? 1 : 0);
    
    if (this.player !== null) {
      try {
        this.player.setLoop(loop);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set loop: %{public}s', (err as Error).message);
      }
    }
  }
  
  setAutoPlay(autoPlay: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setAutoPlay: %{public}s autoPlay=%{public}d', this.playerId, autoPlay ? 1 : 0);
    
    if (this.player !== null) {
      try {
        this.player.setAutoPlay(autoPlay);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set autoPlay: %{public}s', (err as Error).message);
      }
    }
  }
  
  setFastStart(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setFastStart: %{public}s enable=%{public}d', this.playerId, enable ? 1 : 0);
    
    if (this.player !== null) {
      try {
        this.player.setFastStart(enable);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set fast start: %{public}s', (err as Error).message);
      }
    }
  }
  
  setEnableHardwareDecoder(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG,
      'setEnableHardwareDecoder: %{public}s enable=%{public}d', this.playerId, enable ? 1 : 0);
    
    if (this.player !== null) {
      try {
        this.player.enableHardwareDecoder(enable);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG,
          'Failed to set hardware decoder: %{public}s', (err as Error).message);
      }
    }
  }
  
  setMuted(muted: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setMuted: %{public}s muted=%{public}d', this.playerId, muted ? 1 : 0);
    
    if (this.player !== null) {
      try {
        this.player.setMute(muted);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set muted: %{public}s', (err as Error).message);
      }
    }
  }
  
  isMuted(): boolean {
    if (this.player !== null) {
      try {
        return this.player.isMuted();
      } catch (err) {
        return false;
      }
    }
    return false;
  }
  
  setScalingMode(mode: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setScalingMode: %{public}s mode=%{public}d', this.playerId, mode);
    
    if (this.player !== null) {
      try {
        this.player.setScaleMode(this.toScaleMode(mode));
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set scaling mode: %{public}s', (err as Error).message);
      }
    }
  }
  
  getScalingMode(): number {
    if (this.player !== null) {
      try {
        return this.player.getScaleMode() as number;
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to get scaling mode: %{public}s', (err as Error).message);
      }
    }
    return ScaleMode.SCALE_ASPECT_FIT as number;
  }
  
  setRotateMode(mode: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setRotateMode: %{public}s mode=%{public}d', this.playerId, mode);
    
    if (this.player !== null) {
      try {
        this.player.setRotateMode(this.toRotateMode(mode));
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set rotate mode: %{public}s', (err as Error).message);
      }
    }
  }
  
  setMirrorMode(mode: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setMirrorMode: %{public}s mode=%{public}d', this.playerId, mode);
    
    if (this.player !== null) {
      try {
        this.player.setMirrorMode(this.toMirrorMode(mode));
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set mirror mode: %{public}s', (err as Error).message);
      }
    }
  }

  getAlphaRenderMode(): number {
    return this.player !== null
      ? this.player.getAlphaRenderMode() as number
      : AlphaRenderMode.RENDER_MODE_ALPHA_NONE;
  }

  setAlphaRenderMode(mode: number): void {
    if (this.player !== null) {
      this.player.setAlphaRenderMode(this.toAlphaRenderMode(mode));
    }
  }

  private toScaleMode(mode: number): ScaleMode {
    switch (mode) {
      case 1:
        return ScaleMode.SCALE_ASPECT_FILL;
      case 2:
        return ScaleMode.SCALE_TO_FILL;
      default:
        return ScaleMode.SCALE_ASPECT_FIT;
    }
  }

  private toRotateMode(mode: number): RotateMode {
    switch (mode) {
      case 90:
        return RotateMode.ROTATE_90;
      case 180:
        return RotateMode.ROTATE_180;
      case 270:
        return RotateMode.ROTATE_270;
      default:
        return RotateMode.ROTATE_0;
    }
  }

  private toMirrorMode(mode: number): MirrorMode {
    switch (mode) {
      case 1:
        return MirrorMode.MIRROR_MODE_HORIZONTAL;
      case 2:
        return MirrorMode.MIRROR_MODE_VERTICAL;
      default:
        return MirrorMode.MIRROR_MODE_NONE;
    }
  }

  private toAlphaRenderMode(mode: number): AlphaRenderMode {
    switch (mode) {
      case 1:
        return AlphaRenderMode.RENDER_MODE_ALPHA_AT_RIGHT;
      case 2:
        return AlphaRenderMode.RENDER_MODE_ALPHA_AT_LEFT;
      case 3:
        return AlphaRenderMode.RENDER_MODE_ALPHA_AT_TOP;
      case 4:
        return AlphaRenderMode.RENDER_MODE_ALPHA_AT_BOTTOM;
      default:
        return AlphaRenderMode.RENDER_MODE_ALPHA_NONE;
    }
  }

  setBackgroundColor(color: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setBackgroundColor: %{public}s color=0x%{public}x', this.playerId, color);
    
    if (this.player !== null) {
      try {
        this.player.setVideoBackgroundColor(color);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set background color: %{public}s', (err as Error).message);
      }
    }
  }

  selectTrack(trackIndex: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'selectTrack: %{public}s trackIndex=%{public}d', this.playerId, trackIndex);
    
    if (this.player !== null) {
      try {
        this.player.selectTrack(trackIndex);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to select track: %{public}s', (err as Error).message);
      }
    }
  }
  
  setDefaultBandWidth(bandWidth: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setDefaultBandWidth: %{public}s bandWidth=%{public}d', this.playerId, bandWidth);
    
    if (this.player !== null) {
      try {
        this.player.setDefaultBandWidth(bandWidth);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set default bandwidth: %{public}s', (err as Error).message);
      }
    }
  }
  
  setDefaultResolution(resolution: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setDefaultResolution: %{public}s resolution=%{public}d', this.playerId, resolution);
    
    if (this.player !== null) {
      try {
        this.player.setDefaultResolution(resolution);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set default resolution: %{public}s', (err as Error).message);
      }
    }
  }
  
  getCurrentPosition(): number {
    if (this.player !== null) {
      try {
        return this.player.getCurrentPosition();
      } catch (err) {
        return 0;
      }
    }
    return 0;
  }
  
  getDuration(): number {
    if (this.player !== null) {
      try {
        return this.player.getDuration();
      } catch (err) {
        return 0;
      }
    }
    return 0;
  }
  
  getVideoWidth(): number {
    // 优先返回缓存的尺寸（来自 onVideoSizeChanged 回调）
    if (this.videoWidth > 0) {
      return this.videoWidth;
    }
    if (this.player !== null) {
      try {
        return this.player.getVideoWidth();
      } catch (err) {
        return 0;
      }
    }
    return 0;
  }
  
  getVideoHeight(): number {
    // 优先返回缓存的尺寸（来自 onVideoSizeChanged 回调）
    if (this.videoHeight > 0) {
      return this.videoHeight;
    }
    if (this.player !== null) {
      try {
        return this.player.getVideoHeight();
      } catch (err) {
        return 0;
      }
    }
    return 0;
  }
  
  getMediaInfo(): Map<string, Object> {
    const info = new Map<string, Object>();
    info.set('duration', this.getDuration());
    
    let width = this.getVideoWidth();
    let height = this.getVideoHeight();
    
    if (this.player !== null) {
      try {
        const mediaInfo = this.player.getMediaInfo();
        if (mediaInfo !== null) {
          info.set('title', mediaInfo.getTitle());
          info.set('videoId', mediaInfo.getVideoId());
          info.set('coverUrl', mediaInfo.getCoverUrl());
          
          const tracks = mediaInfo.getTrackInfos();
          if (tracks !== null && tracks !== undefined) {
            const trackList: Map<string, Object>[] = [];
            for (let i = 0; i < tracks.length; i++) {
              const track = tracks[i];
              const trackMap = new Map<string, Object>();
              trackMap.set('trackIndex', track.index);
              trackMap.set('trackType', track.mType);
              trackMap.set('trackBitrate', track.videoBitrate);
              trackMap.set('videoWidth', track.videoWidth);
              trackMap.set('videoHeight', track.videoHeight);
              trackMap.set('trackDefinition', track.vodDefinition);
              trackMap.set('vodPlayUrl', track.vodPlayUrl);
              trackList.push(trackMap);
              
              // 如果顶层尺寸为 0，从视频轨道获取
              if (width === 0 && height === 0 && track.mType === TrackType.TYPE_VIDEO) {
                width = track.videoWidth;
                height = track.videoHeight;
              }
            }
            info.set('tracks', trackList);
          }
        }
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to get media info: %{public}s', (err as Error).message);
      }
    }
    
    info.set('width', width);
    info.set('height', height);
    
    return info;
  }
  
  snapShot(path: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'snapShot: %{public}s', this.playerId);
    
    if (this.player !== null) {
      try {
        this.player.snapShot();
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to snapshot: %{public}s', (err as Error).message);
      }
    }
  }
  
  addExtSubtitle(url: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'addExtSubtitle: %{public}s url=%{public}s', this.playerId, url);
    
    if (this.player !== null) {
      try {
        this.player.addExtSubtitle(url);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'Ext subtitle added successfully');
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to add ext subtitle: %{public}s', (err as Error).message);
      }
    }
  }
  
  selectExtSubtitle(trackIndex: number, enable: boolean): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'selectExtSubtitle: %{public}s trackIndex=%{public}d enable=%{public}d', 
      this.playerId, trackIndex, enable ? 1 : 0);
    
    if (this.player !== null) {
      try {
        this.player.selectExtSubtitle(trackIndex, enable);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'Ext subtitle selected successfully');
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to select ext subtitle: %{public}s', (err as Error).message);
      }
    }
  }
  
  createThumbnailHelper(thumbnail: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'createThumbnailHelper: %{public}s thumbnail=%{public}s', this.playerId, thumbnail);
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'Thumbnail API not supported by OHOS SDK');
    // SDK 不支持缩略图 API，发送失败回调
    this.sendEvent('thumbnail_onPrepared_Fail');
  }
  
  requestBitmapAtPosition(position: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'requestBitmapAtPosition: %{public}s position=%{public}d', this.playerId, position);
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'Thumbnail API not supported by OHOS SDK');
    // SDK 不支持缩略图 API，发送失败回调
    this.sendEvent('onThumbnailGetFail');
  }
  
  setOnURLSourceExpiredListener(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnURLSourceExpiredListener: %{public}s enable=%{public}d', this.playerId, enable ? 1 : 0);
  }
  
  setOnVidAuthExpiredListener(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnVidAuthExpiredListener: %{public}s enable=%{public}d', this.playerId, enable ? 1 : 0);
  }
  
  reload(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'reload: %{public}s', this.playerId);
    
    if (this.player !== null) {
      try {
        this.player.reload();
        hilog.info(LOG_DOMAIN, LOG_TAG, 'reload success: %{public}s', this.playerId);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to reload player: %{public}s', (err as Error).message);
      }
    }
  }
  
  setConfig(config: Map<string, Object>): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setConfig: %{public}s', this.playerId);
    
    if (this.player === null) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player not initialized for setConfig');
      return;
    }
    
    try {
      const playerConfig = this.player.getConfig();
      if (playerConfig !== undefined && playerConfig !== null) {
        this.applyConfigToPlayerConfig(config, playerConfig);
        this.player.setConfig(playerConfig);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'setConfig success: %{public}s', this.playerId);
      }
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set config: %{public}s', (err as Error).message);
    }
  }
  
  getConfig(): Map<string, Object> {
    const config = new Map<string, Object>();
    
    if (this.player === null) {
      return config;
    }
    
    try {
      const playerConfig = this.player.getConfig();
      if (playerConfig !== undefined && playerConfig !== null) {
        config.set('mMaxBufferDuration', playerConfig.mMaxBufferDuration);
        config.set('mHighBufferDuration', playerConfig.mHighBufferDuration);
        config.set('mStartBufferDuration', playerConfig.mStartBufferDuration);
        config.set('mNetworkTimeout', playerConfig.mNetworkTimeout);
        config.set('mNetworkRetryCount', playerConfig.mNetworkRetryCount);
        config.set('mHttpProxy', playerConfig.mHttpProxy);
        config.set('mReferrer', playerConfig.mReferrer);
        config.set('mUserAgent', playerConfig.mUserAgent);
        config.set('mMaxDelayTime', playerConfig.mMaxDelayTime);
        config.set('mMaxProbeSize', playerConfig.mMaxProbeSize);
        config.set('mClearFrameWhenStop', playerConfig.mClearFrameWhenStop);
        config.set('mEnableSEI', playerConfig.mEnableSEI);
        config.set('mEnableLocalCache', playerConfig.mEnableLocalCache);
        config.set('mDisableAudio', playerConfig.mDisableAudio);
        config.set('mDisableVideo', playerConfig.mDisableVideo);
        config.set('mLiveStartIndex', playerConfig.mLiveStartIndex);
        config.set('mPositionTimerIntervalMs', playerConfig.mPositionTimerIntervalMs);
        config.set('mMaxBackwardBufferDurationMs', playerConfig.mMaxBackwardBufferDurationMs);
        config.set('mPreferAudio', playerConfig.mPreferAudio);
        config.set('mEnableHttpDns', playerConfig.mEnableHttpDns);
        config.set('mEnableHttp3', playerConfig.mEnableHttp3);
        config.set('mEnableStrictFlvHeader', playerConfig.mEnableStrictFlvHeader);
        config.set('mEnableStrictAuthMode', playerConfig.mEnableStrictAuthMode);
        config.set('mEnableProjection', playerConfig.mEnableProjection);
        config.set('mSelectTrackBufferMode', playerConfig.mSelectTrackBufferMode);
        config.set('mMaxAllowedAbrVideoPixelNumber', playerConfig.mMaxAllowedAbrVideoPixelNumber);
      }
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to get config: %{public}s', (err as Error).message);
    }
    
    return config;
  }
  
  /**
   * 返回 Dart 侧 AVPConfig 结构的配置（驼峰 key）。
   * 
   * getConfig() 沿用 Android 的 PlayerConfig 字段名（m 前缀），
   * 而 Dart 的 AVPConfig.convertAt() 读的是 iOS AVPConfig 的属性名，
   * 两者 key 不同，所以这里单独按 AVPConfig 的字段名输出一份。
   */
  getPlayConfig(): Map<string, Object> {
    const config = new Map<string, Object>();
    
    if (this.player === null) {
      return config;
    }
    
    try {
      const playerConfig = this.player.getConfig();
      if (playerConfig !== undefined && playerConfig !== null) {
        config.set('maxBufferDuration', playerConfig.mMaxBufferDuration);
        config.set('highBufferDuration', playerConfig.mHighBufferDuration);
        config.set('startBufferDuration', playerConfig.mStartBufferDuration);
        config.set('networkTimeout', playerConfig.mNetworkTimeout);
        config.set('networkRetryCount', playerConfig.mNetworkRetryCount);
        config.set('maxDelayTime', playerConfig.mMaxDelayTime);
        config.set('maxProbeSize', playerConfig.mMaxProbeSize);
        config.set('httpProxy', playerConfig.mHttpProxy);
        config.set('referer', playerConfig.mReferrer);
        config.set('userAgent', playerConfig.mUserAgent);
        config.set('clearShowWhenStop', playerConfig.mClearFrameWhenStop);
        config.set('enableSEI', playerConfig.mEnableSEI);
        config.set('enableLocalCache', playerConfig.mEnableLocalCache);
        config.set('liveStartIndex', playerConfig.mLiveStartIndex);
        config.set('disableAudio', playerConfig.mDisableAudio);
        config.set('disableVideo', playerConfig.mDisableVideo);
        config.set('positionTimerIntervalMs', playerConfig.mPositionTimerIntervalMs);
        config.set('mMAXBackwardDuration', playerConfig.mMaxBackwardBufferDurationMs);
        config.set('preferAudio', playerConfig.mPreferAudio);
        config.set('enableHttpDns', playerConfig.mEnableHttpDns);
        config.set('enableHttp3', playerConfig.mEnableHttp3);
        config.set('enableStrictFlvHeader', playerConfig.mEnableStrictFlvHeader);
        config.set('enableStrictAuthMode', playerConfig.mEnableStrictAuthMode);
        config.set('enableProjection', playerConfig.mEnableProjection);
        config.set('mSelectTrackBufferMode', playerConfig.mSelectTrackBufferMode);
        config.set('mMaxAllowedAbrVideoPixelNumber', playerConfig.mMaxAllowedAbrVideoPixelNumber);
        
        const headers = playerConfig.getCustomHeaders();
        if (headers !== undefined && headers !== null) {
          config.set('httpHeaders', headers);
        }
      }
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to get play config: %{public}s', (err as Error).message);
    }
    
    return config;
  }
  
  private applyConfigToPlayerConfig(map: Map<string, Object>, config: PlayerConfig): void {
    if (map.has('mMaxBufferDuration')) {
      config.mMaxBufferDuration = map.get('mMaxBufferDuration') as number;
    }
    if (map.has('maxBufferDuration')) {
      config.mMaxBufferDuration = map.get('maxBufferDuration') as number;
    }
    if (map.has('mHighBufferDuration')) {
      config.mHighBufferDuration = map.get('mHighBufferDuration') as number;
    }
    if (map.has('highBufferDuration')) {
      config.mHighBufferDuration = map.get('highBufferDuration') as number;
    }
    if (map.has('mStartBufferDuration')) {
      config.mStartBufferDuration = map.get('mStartBufferDuration') as number;
    }
    if (map.has('startBufferDuration')) {
      config.mStartBufferDuration = map.get('startBufferDuration') as number;
    }
    if (map.has('mNetworkTimeout')) {
      config.mNetworkTimeout = map.get('mNetworkTimeout') as number;
    }
    if (map.has('networkTimeout')) {
      config.mNetworkTimeout = map.get('networkTimeout') as number;
    }
    if (map.has('mNetworkRetryCount')) {
      config.mNetworkRetryCount = map.get('mNetworkRetryCount') as number;
    }
    if (map.has('networkRetryCount')) {
      config.mNetworkRetryCount = map.get('networkRetryCount') as number;
    }
    if (map.has('mHttpProxy')) {
      const proxy = map.get('mHttpProxy') as string;
      config.mHttpProxy = proxy !== null && proxy !== undefined ? proxy : '';
    }
    if (map.has('httpProxy')) {
      const proxy = map.get('httpProxy') as string;
      config.mHttpProxy = proxy !== null && proxy !== undefined ? proxy : '';
    }
    if (map.has('mReferrer')) {
      config.mReferrer = map.get('mReferrer') as string;
    }
    if (map.has('referer')) {
      config.mReferrer = map.get('referer') as string;
    }
    if (map.has('mUserAgent')) {
      config.mUserAgent = map.get('mUserAgent') as string;
    }
    if (map.has('userAgent')) {
      config.mUserAgent = map.get('userAgent') as string;
    }
    if (map.has('mMaxDelayTime')) {
      config.mMaxDelayTime = map.get('mMaxDelayTime') as number;
    }
    if (map.has('maxDelayTime')) {
      config.mMaxDelayTime = map.get('maxDelayTime') as number;
    }
    if (map.has('mMaxProbeSize')) {
      config.mMaxProbeSize = map.get('mMaxProbeSize') as number;
    }
    if (map.has('maxProbeSize')) {
      config.mMaxProbeSize = map.get('maxProbeSize') as number;
    }
    if (map.has('mClearFrameWhenStop')) {
      config.mClearFrameWhenStop = map.get('mClearFrameWhenStop') as boolean;
    }
    if (map.has('clearShowWhenStop')) {
      config.mClearFrameWhenStop = map.get('clearShowWhenStop') as boolean;
    }
    if (map.has('mEnableSEI')) {
      config.mEnableSEI = map.get('mEnableSEI') as boolean;
    }
    if (map.has('enableSEI')) {
      config.mEnableSEI = map.get('enableSEI') as boolean;
    }
    if (map.has('mEnableLocalCache')) {
      config.mEnableLocalCache = map.get('mEnableLocalCache') as boolean;
    }
    if (map.has('enableLocalCache')) {
      config.mEnableLocalCache = map.get('enableLocalCache') as boolean;
    }
    if (map.has('mDisableAudio')) {
      config.mDisableAudio = map.get('mDisableAudio') as boolean;
    }
    if (map.has('disableAudio')) {
      config.mDisableAudio = map.get('disableAudio') as boolean;
    }
    if (map.has('mDisableVideo')) {
      config.mDisableVideo = map.get('mDisableVideo') as boolean;
    }
    if (map.has('disableVideo')) {
      config.mDisableVideo = map.get('disableVideo') as boolean;
    }
    if (map.has('mLiveStartIndex')) {
      config.mLiveStartIndex = map.get('mLiveStartIndex') as number;
    }
    if (map.has('liveStartIndex')) {
      config.mLiveStartIndex = map.get('liveStartIndex') as number;
    }
    if (map.has('mPositionTimerIntervalMs')) {
      config.mPositionTimerIntervalMs = map.get('mPositionTimerIntervalMs') as number;
    }
    if (map.has('positionTimerIntervalMs')) {
      config.mPositionTimerIntervalMs = map.get('positionTimerIntervalMs') as number;
    }
    if (map.has('mMaxBackwardBufferDurationMs')) {
      config.mMaxBackwardBufferDurationMs = map.get('mMaxBackwardBufferDurationMs') as number;
    }
    if (map.has('mMAXBackwardDuration')) {
      config.mMaxBackwardBufferDurationMs = map.get('mMAXBackwardDuration') as number;
    }
    if (map.has('mPreferAudio')) {
      config.mPreferAudio = map.get('mPreferAudio') as boolean;
    }
    if (map.has('preferAudio')) {
      config.mPreferAudio = map.get('preferAudio') as boolean;
    }
    if (map.has('mEnableHttpDns')) {
      config.mEnableHttpDns = map.get('mEnableHttpDns') as number;
    }
    if (map.has('enableHttpDns')) {
      config.mEnableHttpDns = map.get('enableHttpDns') as number;
    }
    if (map.has('mEnableHttp3')) {
      config.mEnableHttp3 = map.get('mEnableHttp3') as boolean;
    }
    if (map.has('enableHttp3')) {
      config.mEnableHttp3 = map.get('enableHttp3') as boolean;
    }
    if (map.has('mEnableStrictFlvHeader')) {
      config.mEnableStrictFlvHeader = map.get('mEnableStrictFlvHeader') as boolean;
    }
    if (map.has('enableStrictFlvHeader')) {
      config.mEnableStrictFlvHeader = map.get('enableStrictFlvHeader') as boolean;
    }
    if (map.has('mEnableStrictAuthMode')) {
      config.mEnableStrictAuthMode = map.get('mEnableStrictAuthMode') as boolean;
    }
    if (map.has('enableStrictAuthMode')) {
      config.mEnableStrictAuthMode = map.get('enableStrictAuthMode') as boolean;
    }
    if (map.has('mEnableProjection')) {
      config.mEnableProjection = map.get('mEnableProjection') as boolean;
    }
    if (map.has('enableProjection')) {
      config.mEnableProjection = map.get('enableProjection') as boolean;
    }
    if (map.has('mSelectTrackBufferMode')) {
      config.mSelectTrackBufferMode = map.get('mSelectTrackBufferMode') as number;
    }
    if (map.has('mMaxAllowedAbrVideoPixelNumber')) {
      config.mMaxAllowedAbrVideoPixelNumber = map.get('mMaxAllowedAbrVideoPixelNumber') as number;
    }
  }
  
  release(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'release: %{public}s', this.playerId);
    
    if (this.player !== null) {
      try {
        this.player.release();
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to release player: %{public}s', (err as Error).message);
      }
      this.player = null;
    }
    
    this.eventSink = null;
    this.isPrepared = false;
    this.isSurfaceReady = false;
  }
  
  releaseAsync(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'releaseAsync: %{public}s', this.playerId);
    
    if (this.player !== null) {
      try {
        this.player.releaseAsync();
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to release player async: %{public}s', (err as Error).message);
      }
      this.player = null;
    }
    
    this.eventSink = null;
    this.isPrepared = false;
    this.isSurfaceReady = false;
  }
  
  private sendEvent(eventName: string): void {
    if (this.eventSink !== null) {
      const event = new Map<string, Object>();
      event.set('method', eventName);
      event.set('playerId', this.playerId);
      this.eventSink.success(event);
    }
  }
  
  private sendEventWithArg(eventName: string, argName: string, argValue: Object): void {
    if (this.eventSink !== null) {
      const event = new Map<string, Object>();
      event.set('method', eventName);
      event.set('playerId', this.playerId);
      event.set(argName, argValue);
      this.eventSink.success(event);
    }
  }
  
  private sendEventWithArgs(eventName: string, args: [string, Object][]): void {
    if (this.eventSink !== null) {
      const event = new Map<string, Object>();
      event.set('method', eventName);
      event.set('playerId', this.playerId);
      for (let i = 0; i < args.length; i++) {
        event.set(args[i][0], args[i][1]);
      }
      this.eventSink.success(event);
    }
  }
}
