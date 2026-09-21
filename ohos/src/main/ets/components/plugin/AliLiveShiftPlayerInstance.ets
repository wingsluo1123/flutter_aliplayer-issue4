/**
 * 阿里云直播时移播放器实例封装
 * 
 * 负责直播时移播放器实例的生命周期管理、时移操作、事件分发
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import common from '@ohos.app.ability.common';
import { AliPlayerFactory, AliLiveShiftPlayer, IPlayer, ErrorInfo, InfoBean, InfoCode, UrlSource, PlayerConfig } from 'premierlibrary';
import { LiveShift } from 'premierlibrary/src/main/ets/com/aliyun/player/source/LiveShift';
import {
  ScaleMode,
  RotateMode,
  MirrorMode,
  AlphaRenderMode
} from 'premierlibrary/src/main/ets/com/aliyun/player/IPlayer';
import { IPlayerInstance } from './IPlayerInstance';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliLiveShiftPlayerInstance';

export class AliLiveShiftPlayerInstance implements IPlayerInstance {
  private playerId: string;
  private context: common.Context | null = null;
  private player: AliLiveShiftPlayer | null = null;
  private eventSink: EventSink | null = null;
  
  private surfaceId: string = '';
  private isSurfaceReady: boolean = false;
  private isPrepared: boolean = false;
  
  constructor(playerId: string) {
    this.playerId = playerId;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'AliLiveShiftPlayerInstance created: %{public}s', playerId);
  }
  
  setContext(context: common.Context): void {
    this.context = context;
  }
  
  init(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Initializing live shift player: %{public}s', this.playerId);
    
    if (this.context === null) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Context is null');
      return;
    }
    
    try {
      this.player = AliPlayerFactory.createAliLiveShiftPlayer(this.context);
      this.setupListeners();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Live shift player created: %{public}s', this.playerId);
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to create live shift player: %{public}s', (err as Error).message);
    }
  }
  
  private setupListeners(): void {
    if (this.player === null) return;
    
    this.player.setOnPreparedListener({
      onPrepared: () => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onPrepared: %{public}s', this.playerId);
        this.isPrepared = true;
        this.sendEvent('onPrepared');
      }
    });
    
    this.player.setOnRenderingStartListener({
      onRenderingStart: () => {
        this.sendEvent('onRenderingStart');
      }
    });
    
    this.player.setOnStateChangedListener({
      onStateChanged: (newState: number) => {
        this.sendEventWithArg('onStateChanged', 'newState', newState);
      }
    });
    
    this.player.setOnCompletionListener({
      onCompletion: () => {
        this.sendEvent('onCompletion');
      }
    });
    
    this.player.setOnErrorListener({
      onError: (errorInfo: ErrorInfo) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'onError: %{public}s code=%{public}d', 
          this.playerId, errorInfo.getCode());
        const event = new Map<string, Object>();
        event.set('method', 'onError');
        event.set('playerId', this.playerId);
        event.set('errorCode', errorInfo.getCode());
        event.set('errorMsg', errorInfo.getMsg());
        if (this.eventSink !== null) {
          this.eventSink.success(event);
        }
      }
    });
    
    this.player.setOnInfoListener({
      onInfo: (infoBean: InfoBean) => {
        const code = infoBean.getCode();
        if (code === InfoCode.CurrentPosition || code === InfoCode.BufferedPosition) {
          this.sendEventWithArgs('onInfo', [
            ['infoCode', code],
            ['extraValue', infoBean.getExtraValue()]
          ]);
        }
      }
    });
    
    this.player.setOnTimeShiftUpdaterListener({
      onUpdater: (currentTime: number, shiftStartTime: number, shiftEndTime: number) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onUpdater: currentTime=%{public}d shiftStart=%{public}d shiftEnd=%{public}d',
          currentTime, shiftStartTime, shiftEndTime);
        this.sendEventWithArgs('onUpdater', [
          ['currentTime', currentTime],
          ['shiftStartTime', shiftStartTime],
          ['shiftEndTime', shiftEndTime]
        ]);
      }
    });
    
    this.player.setOnSeekLiveCompletionListener({
      onSeekLiveCompletion: (playTime: number) => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onSeekLiveCompletion: playTime=%{public}d', playTime);
        this.sendEventWithArg('onSeekLiveCompletion', 'playTime', playTime);
      }
    });
  }
  
  setEventSink(sink: EventSink | null): void {
    this.eventSink = sink;
  }
  
  setSurfaceId(surfaceId: string): void {
    this.surfaceId = surfaceId;
    this.isSurfaceReady = true;
    if (this.player !== null) {
      this.player.setSurfaceId(surfaceId);
      this.sendEvent('onSurfaceReady');
    }
  }
  
  clearSurfaceId(): void {
    this.surfaceId = '';
    this.isSurfaceReady = false;
  }
  
  setUrl(url: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setUrl: %{public}s', url);
    if (this.player !== null) {
      try {
        const liveShift = new LiveShift();
        liveShift.setUrl(url);
        liveShift.setTimeLineUrl('');
        this.player.setLiveShiftDataSource(liveShift);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'setLiveShiftDataSource success');
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'setUrl failed: %{public}s', (err as Error).message);
      }
    }
  }
  
  setLiveShiftDataSource(url: string, timeLineUrl: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setLiveShiftDataSource: url=%{public}s', url);
    if (this.player !== null) {
      try {
        const liveShift = new LiveShift();
        liveShift.setUrl(url);
        liveShift.setTimeLineUrl(timeLineUrl);
        this.player.setLiveShiftDataSource(liveShift);
      } catch (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to set live shift source: %{public}s', (err as Error).message);
      }
    }
  }
  
  seekToLiveTime(liveTime: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'seekToLiveTime: %{public}d', liveTime);
    if (this.player !== null) {
      this.player.seekToLiveTime(liveTime);
    }
  }
  
  getCurrentLiveTime(): number {
    if (this.player !== null) {
      return this.player.getCurrentLiveTime();
    }
    return 0;
  }
  
  getCurrentTime(): number {
    if (this.player !== null) {
      return this.player.getCurrentTime();
    }
    return 0;
  }
  
  prepare(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'prepare: %{public}s', this.playerId);
    if (this.player !== null) {
      this.player.prepare();
    }
  }
  
  play(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'play: %{public}s', this.playerId);
    if (this.player !== null) {
      this.player.start();
    }
  }
  
  pause(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'pause: %{public}s', this.playerId);
    if (this.player !== null) {
      this.player.pause();
    }
  }
  
  stop(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'stop: %{public}s', this.playerId);
    if (this.player !== null) {
      this.player.stop();
    }
  }
  
  seekTo(positionMs: number): void {
    if (this.player !== null) {
      this.player.seekTo(positionMs, 1);
    }
  }
  
  setVolume(volume: number): void {
    if (this.player !== null) {
      this.player.setVolume(volume);
    }
  }
  
  setSpeed(speed: number): void {
    if (this.player !== null) {
      this.player.setSpeed(speed);
    }
  }
  
  setLoop(loop: boolean): void {
    if (this.player !== null) {
      this.player.setLoop(loop);
    }
  }
  
  setMute(muted: boolean): void {
    if (this.player !== null) {
      this.player.setMute(muted);
    }
  }
  
  setMuted(muted: boolean): void {
    this.setMute(muted);
  }
  
  getVolume(): number {
    if (this.player !== null) {
      return this.player.getVolume();
    }
    return 1.0;
  }
  
  setAutoPlay(autoPlay: boolean): void {
    if (this.player !== null) {
      this.player.setAutoPlay(autoPlay);
    }
  }
  
  isMuted(): boolean {
    if (this.player !== null) {
      return this.player.isMuted();
    }
    return false;
  }
  
  setScalingMode(mode: number): void {
    if (this.player !== null) {
      this.player.setScaleMode(this.toScaleMode(mode));
    }
  }
  
  setRotateMode(mode: number): void {
    if (this.player !== null) {
      this.player.setRotateMode(this.toRotateMode(mode));
    }
  }
  
  setMirrorMode(mode: number): void {
    if (this.player !== null) {
      this.player.setMirrorMode(this.toMirrorMode(mode));
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

  setBackgroundColor(color: number): void {
    if (this.player !== null) {
      this.player.setVideoBackgroundColor(color);
    }
  }

  selectTrack(trackIndex: number): void {
    if (this.player !== null) {
      this.player.selectTrack(trackIndex);
    }
  }
  
  setDefaultBandWidth(bandWidth: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setDefaultBandWidth: %{public}s bandWidth=%{public}d', this.playerId, bandWidth);
  }
  
  setDefaultResolution(resolution: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setDefaultResolution: %{public}s resolution=%{public}d', this.playerId, resolution);
  }
  
  addExtSubtitle(url: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'addExtSubtitle: %{public}s url=%{public}s', this.playerId, url);
  }
  
  selectExtSubtitle(trackIndex: number, enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'selectExtSubtitle: %{public}s trackIndex=%{public}d enable=%{public}d', 
      this.playerId, trackIndex, enable ? 1 : 0);
  }
  
  createThumbnailHelper(thumbnail: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'createThumbnailHelper: %{public}s thumbnail=%{public}s', this.playerId, thumbnail);
  }
  
  requestBitmapAtPosition(position: number): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'requestBitmapAtPosition: %{public}s position=%{public}d', this.playerId, position);
  }
  
  snapShot(path: string): void {
    if (this.player !== null) {
      this.player.snapShot();
    }
  }
  
  setOnURLSourceExpiredListener(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnURLSourceExpiredListener: %{public}s', this.playerId);
  }
  
  setOnVidAuthExpiredListener(enable: boolean): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setOnVidAuthExpiredListener: %{public}s', this.playerId);
  }
  
  getDuration(): number {
    if (this.player !== null) {
      return this.player.getDuration();
    }
    return 0;
  }
  
  getCurrentPosition(): number {
    if (this.player !== null) {
      return this.player.getCurrentPosition();
    }
    return 0;
  }
  
  getVideoWidth(): number {
    if (this.player !== null) {
      return this.player.getVideoWidth();
    }
    return 0;
  }
  
  getVideoHeight(): number {
    if (this.player !== null) {
      return this.player.getVideoHeight();
    }
    return 0;
  }
  
  getMediaInfo(): Map<string, Object> {
    const info = new Map<string, Object>();
    info.set('duration', this.getDuration());
    info.set('width', this.getVideoWidth());
    info.set('height', this.getVideoHeight());
    return info;
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
      }
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to get config: %{public}s', (err as Error).message);
    }
    
    return config;
  }
  
  private applyConfigToPlayerConfig(map: Map<string, Object>, config: PlayerConfig): void {
    if (map.has('mMaxBufferDuration') || map.has('maxBufferDuration')) {
      const val = map.get('mMaxBufferDuration') ?? map.get('maxBufferDuration');
      if (val !== undefined) config.mMaxBufferDuration = val as number;
    }
    if (map.has('mHighBufferDuration') || map.has('highBufferDuration')) {
      const val = map.get('mHighBufferDuration') ?? map.get('highBufferDuration');
      if (val !== undefined) config.mHighBufferDuration = val as number;
    }
    if (map.has('mStartBufferDuration') || map.has('startBufferDuration')) {
      const val = map.get('mStartBufferDuration') ?? map.get('startBufferDuration');
      if (val !== undefined) config.mStartBufferDuration = val as number;
    }
    if (map.has('mNetworkTimeout') || map.has('networkTimeout')) {
      const val = map.get('mNetworkTimeout') ?? map.get('networkTimeout');
      if (val !== undefined) config.mNetworkTimeout = val as number;
    }
    if (map.has('mNetworkRetryCount') || map.has('networkRetryCount')) {
      const val = map.get('mNetworkRetryCount') ?? map.get('networkRetryCount');
      if (val !== undefined) config.mNetworkRetryCount = val as number;
    }
    if (map.has('mHttpProxy') || map.has('httpProxy')) {
      const val = map.get('mHttpProxy') ?? map.get('httpProxy');
      if (val !== undefined) config.mHttpProxy = val as string;
    }
    if (map.has('mReferrer') || map.has('referer')) {
      const val = map.get('mReferrer') ?? map.get('referer');
      if (val !== undefined) config.mReferrer = val as string;
    }
    if (map.has('mUserAgent') || map.has('userAgent')) {
      const val = map.get('mUserAgent') ?? map.get('userAgent');
      if (val !== undefined) config.mUserAgent = val as string;
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

  release(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'release: %{public}s', this.playerId);
    if (this.player !== null) {
      this.player.release();
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
  
  private sendEventWithArg(eventName: string, key: string, value: Object): void {
    if (this.eventSink !== null) {
      const event = new Map<string, Object>();
      event.set('method', eventName);
      event.set('playerId', this.playerId);
      event.set(key, value);
      this.eventSink.success(event);
    }
  }
  
  private sendEventWithArgs(eventName: string, args: Array<[string, Object]>): void {
    if (this.eventSink !== null) {
      const event = new Map<string, Object>();
      event.set('method', eventName);
      event.set('playerId', this.playerId);
      for (const arg of args) {
        event.set(arg[0], arg[1]);
      }
      this.eventSink.success(event);
    }
  }
}
