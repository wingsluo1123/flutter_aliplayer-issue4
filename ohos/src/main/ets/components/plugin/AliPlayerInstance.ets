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
  ScaleMode,
} from 'premierlibrary';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliPlayerInstance';

export class AliPlayerInstance {
  private playerId: string;
  private context: common.Context | null = null;
  private player: AliPlayer | null = null;
  private eventSink: EventSink | null = null;
  
  private surfaceId: string = '';
  private isSurfaceReady: boolean = false;
  private isPrepared: boolean = false;
  private url: string = '';
  
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
          ['path', savedPath]
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
        this.player.setScaleMode(mode);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set scaling mode: %{public}s', (err as Error).message);
      }
    }
  }
  
  setRotateMode(mode: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setRotateMode: %{public}s mode=%{public}d', this.playerId, mode);
    
    if (this.player !== null) {
      try {
        this.player.setRotateMode(mode);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set rotate mode: %{public}s', (err as Error).message);
      }
    }
  }
  
  setMirrorMode(mode: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setMirrorMode: %{public}s mode=%{public}d', this.playerId, mode);
    
    if (this.player !== null) {
      try {
        this.player.setMirrorMode(mode);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set mirror mode: %{public}s', (err as Error).message);
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
    info.set('width', this.getVideoWidth());
    info.set('height', this.getVideoHeight());
    
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
            }
            info.set('tracks', trackList);
          }
        }
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to get media info: %{public}s', (err as Error).message);
      }
    }
    
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
  
  setOnURLSourceExpiredListener(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnURLSourceExpiredListener: %{public}s enable=%{public}d', this.playerId, enable ? 1 : 0);
  }
  
  setOnVidAuthExpiredListener(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnVidAuthExpiredListener: %{public}s enable=%{public}d', this.playerId, enable ? 1 : 0);
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
