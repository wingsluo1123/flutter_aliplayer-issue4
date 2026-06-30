/**
 * AliPlayerProxy
 *
 * 基于 HarmonyOS MediaKit AVPlayer 重新实现的阿里云播放器内核封装。
 * 负责: AVPlayer 生命周期、状态机映射、播控、事件回调转发。
 *
 * 适配说明:
 * - 鸿蒙侧无 AliyunPlayer SDK, 使用 @ohos.multimedia.media 的 AVPlayer 替代。
 * - Aliyun 私有能力(VidSts/VidAuth/ARTC/DRM/HttpDNS 等)在此层做安全空实现并日志提示。
 * - 事件通过共享 EventSink(由插件注入) 与按 playerId 拼接的 BasicMessageChannel 双通道下发,
 *   与 Dart 侧 _onEvent / setMessageHandler 严格对齐。
 */
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  BasicMessageChannel,
  StringCodec,
  BinaryMessenger,
  EventSink,
} from '@ohos/flutter_ohos';

const LOG_DOMAIN: number = 0x0001;
const LOG_TAG: string = 'AliPlayerProxy';

/** BasicMessageChannel 回调事件 (onPrepare / onRenderingStart) */
interface PlayerCallbackEvent {
  method: string;
  playerId: string;
}

/** BasicMessageChannel onStateChanged 回调事件 */
interface StateChangedCallbackEvent {
  method: string;
  playerId: string;
  newState: number;
}

/** Aliyun 播放器状态枚举 (与 Dart 侧 PlayState 对齐) */
export class AliPlayerState {
  static readonly IDLE: number = 0;
  static readonly INITIALIZED: number = 1;
  static readonly PREPARED: number = 2;
  static readonly STARTED: number = 3;
  static readonly PAUSED: number = 4;
  static readonly STOPPED: number = 5;
  static readonly COMPLETION: number = 6;
  static readonly ERROR: number = 7;
}

/** 事件发送回调 (由插件注入, 转发到共享 EventSink) */
export type EmitEventCallback = (data: Map<string, Object>) => void;

export class AliPlayerProxy {
  private playerId: string;
  private messenger: BinaryMessenger;
  private emitEvent: EmitEventCallback;

  private avPlayer: media.AVPlayer | null = null;
  private currentState: string = 'idle';
  private surfaceId: string | null = null;
  private pendingSurfaceId: string | null = null;
  private pendingPlay: boolean = false;
  private pendingSeekMs: number = -1;
  private pendingSeekMode: number = 1; // 默认精准
  private isPrepared: boolean = false;
  private autoPlay: boolean = false;
  private muted: boolean = false;
  private savedVolume: number = 1.0;
  private loop: boolean = false;
  private url: string | null = null;
  private released: boolean = false;
  private listenersBound: boolean = false;
  private currentSpeed: number = 1.0;

  constructor(playerId: string, messenger: BinaryMessenger, emitEvent: EmitEventCallback) {
    this.playerId = playerId;
    this.messenger = messenger;
    this.emitEvent = emitEvent;
  }

  getPlayerId(): string {
    return this.playerId;
  }

  /** 创建 AVPlayer 并绑定事件监听 */
  async create(): Promise<void> {
    try {
      this.avPlayer = await media.createAVPlayer();
      this.bindListeners();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'createAVPlayer ok, playerId=%{public}s', this.playerId);
    } catch (e) {
      const err = e as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'createAVPlayer failed: %{public}s', err.message);
      this.sendError(5400101, err.message, 'createAVPlayer failed');
    }
  }

  /** 绑定 AVPlayer 事件回调 (仅绑定一次) */
  private bindListeners(): void {
    if (this.avPlayer === null || this.listenersBound) {
      return;
    }
    this.listenersBound = true;
    const player = this.avPlayer;

    player.on('stateChange', (state: string, reason: media.StateChangeReason) => {
      this.handleStateChange(state, reason);
    });
    player.on('error', (err: Error) => {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'AVPlayer error: %{public}s', err.message);
      this.currentState = 'error';
      this.sendError(5400102, err.message, 'AVPlayer error');
    });
    player.on('videoSizeChange', (width: number, height: number) => {
      const data = this.newEvent('onVideoSizeChanged');
      data.set('width', width);
      data.set('height', height);
      data.set('rotation', 0);
      this.emitEvent(data);
    });
    player.on('startRenderFrame', () => {
      this.emitRenderingStart();
      const data = this.newEvent('onRenderingStart');
      this.emitEvent(data);
    });
    player.on('endOfStream', () => {
      const data = this.newEvent('onCompletion');
      this.emitEvent(data);
    });
    player.on('seekDone', (timeMs: number) => {
      const data = this.newEvent('onSeekComplete');
      this.emitEvent(data);
    });
    player.on('timeUpdate', (position: number) => {
      const data = this.newEvent('onInfo');
      data.set('infoCode', 2); // InfoCode.CURRENTPOSITION
      data.set('extraValue', position);
      data.set('extraMsg', '');
      this.emitEvent(data);
    });
    player.on('durationUpdate', (duration: number) => {
      const data = this.newEvent('onInfo');
      data.set('infoCode', 1); // InfoCode.BUFFEREDPOSITION
      data.set('extraValue', duration);
      data.set('extraMsg', '');
      this.emitEvent(data);
    });
    player.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      if (infoType === media.BufferingInfoType.BUFFERING_START) {
        this.emitEvent(this.newEvent('onLoadingBegin'));
      } else if (infoType === media.BufferingInfoType.BUFFERING_END) {
        this.emitEvent(this.newEvent('onLoadingEnd'));
      } else if (infoType === media.BufferingInfoType.BUFFERING_PERCENT) {
        const data = this.newEvent('onLoadingProgress');
        data.set('percent', value);
        data.set('netSpeed', 0);
        this.emitEvent(data);
      }
    });
  }

  /** AVPlayer 状态机变化处理 */
  private handleStateChange(state: string, _reason: media.StateChangeReason): void {
    this.currentState = state;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'stateChange -> %{public}s, playerId=%{public}s', state, this.playerId);

    if (state === 'initialized') {
      // initialized 阶段可设置 surfaceId / audioRendererInfo
      this.applySurfaceId();
      this.applyAudioRendererInfo();
    } else if (state === 'prepared') {
      this.isPrepared = true;
      this.emitPrepared();
      // 应用 loop/autoPlay
      try {
        if (this.avPlayer !== null) {
          this.avPlayer.loop = this.loop;
        }
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'set loop on prepared failed: %{public}s', (e as Error).message);
      }
      if (this.pendingSeekMs >= 0) {
        this.doSeek(this.pendingSeekMs, this.pendingSeekMode);
        this.pendingSeekMs = -1;
      }
      if (this.pendingPlay || this.autoPlay) {
        this.pendingPlay = false;
        this.doPlay();
      }
    } else if (state === 'completed') {
      this.emitStateChanged(AliPlayerState.COMPLETION);
    } else if (state === 'error') {
      this.emitStateChanged(AliPlayerState.ERROR);
    } else if (state === 'playing') {
      this.emitStateChanged(AliPlayerState.STARTED);
    } else if (state === 'paused') {
      this.emitStateChanged(AliPlayerState.PAUSED);
    } else if (state === 'stopped') {
      this.emitStateChanged(AliPlayerState.STOPPED);
    }
  }

  // ============== 播控 API ==============

  /** 设置 URL 数据源 */
  setUrl(url: string): void {
    this.url = url;
    if (this.avPlayer === null) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setUrl but avPlayer is null');
      return;
    }
    try {
      this.avPlayer.url = url;
      this.isPrepared = false;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'setUrl failed: %{public}s', (e as Error).message);
    }
  }

  /** 设置渲染面 surfaceId */
  setSurfaceId(surfaceId: string): void {
    this.surfaceId = surfaceId;
    if (this.avPlayer === null) {
      return;
    }
    // surfaceId 只能在 initialized 及之后状态设置
    if (this.currentState === 'idle') {
      this.pendingSurfaceId = surfaceId;
    } else {
      this.applySurfaceId();
    }
  }

  private applySurfaceId(): void {
    if (this.avPlayer === null) {
      return;
    }
    const sid = this.pendingSurfaceId !== null ? this.pendingSurfaceId : this.surfaceId;
    if (sid !== null && sid !== undefined && sid.length > 0) {
      try {
        this.avPlayer.surfaceId = sid;
        this.pendingSurfaceId = null;
        hilog.info(LOG_DOMAIN, LOG_TAG, 'applySurfaceId ok: %{public}s', sid);
      } catch (e) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'applySurfaceId failed: %{public}s', (e as Error).message);
      }
    }
  }

  private applyAudioRendererInfo(): void {
    if (this.avPlayer === null) {
      return;
    }
    try {
      const info: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MOVIE,
        rendererFlags: 0,
      };
      this.avPlayer.audioRendererInfo = info;
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'applyAudioRendererInfo failed: %{public}s', (e as Error).message);
    }
  }

  /** prepare */
  prepare(): void {
    if (this.avPlayer === null) {
      return;
    }
    if (this.currentState === 'prepared' || this.currentState === 'playing' ||
        this.currentState === 'paused') {
      this.isPrepared = true;
      return;
    }
    try {
      this.avPlayer.prepare().then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'prepare ok, playerId=%{public}s', this.playerId);
      }).catch((e: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'prepare failed: %{public}s', e.message);
        this.sendError(5400102, e.message, 'prepare failed');
      });
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'prepare exception: %{public}s', (e as Error).message);
    }
  }

  /** play */
  play(): void {
    if (this.avPlayer === null) {
      return;
    }
    if (!this.isPrepared) {
      this.pendingPlay = true;
      return;
    }
    this.doPlay();
  }

  private doPlay(): void {
    if (this.avPlayer === null) {
      return;
    }
    try {
      this.avPlayer.play().then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'play ok, playerId=%{public}s', this.playerId);
      }).catch((e: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'play failed: %{public}s', e.message);
        this.sendError(5400102, e.message, 'play failed');
      });
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'play exception: %{public}s', (e as Error).message);
    }
  }

  /** pause */
  pause(): void {
    if (this.avPlayer === null) {
      return;
    }
    try {
      this.avPlayer.pause().catch((e: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'pause failed: %{public}s', e.message);
      });
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'pause exception: %{public}s', (e as Error).message);
    }
  }

  /** stop */
  stop(): void {
    if (this.avPlayer === null) {
      return;
    }
    try {
      this.avPlayer.stop().catch((e: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'stop failed: %{public}s', e.message);
      });
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'stop exception: %{public}s', (e as Error).message);
    }
  }

  /** reload: 网络重连近似实现 — reset -> 重新 setUrl -> prepare */
  reload(): void {
    if (this.avPlayer === null || this.url === null) {
      return;
    }
    this.isPrepared = false;
    const savedUrl = this.url;
    try {
      this.avPlayer.reset().then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'reload reset ok, re-setUrl, playerId=%{public}s', this.playerId);
        this.currentState = 'idle';
        try {
          this.avPlayer!.url = savedUrl;
        } catch (e) {
          hilog.error(LOG_DOMAIN, LOG_TAG, 'reload setUrl failed: %{public}s', (e as Error).message);
        }
      }).catch((e: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'reload reset failed: %{public}s', e.message);
      });
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'reload exception: %{public}s', (e as Error).message);
    }
  }

  /** seekTo, positionMs 为毫秒, seekMode: 1=ACCURATE, 16=INACCURATE */
  seekTo(positionMs: number, seekMode: number): void {
    if (this.avPlayer === null) {
      return;
    }
    if (!this.isPrepared) {
      this.pendingSeekMs = positionMs;
      this.pendingSeekMode = seekMode;
      return;
    }
    this.doSeek(positionMs, seekMode);
  }

  private doSeek(positionMs: number, seekMode: number): void {
    if (this.avPlayer === null) {
      return;
    }
    // Aliyun SeekMode.ACCURATE(1) -> SEEK_CLOSEST; INACCURATE(16) -> SEEK_PREV_SYNC
    let mode: media.SeekMode = media.SeekMode.SEEK_PREV_SYNC;
    if (seekMode === 1) {
      mode = media.SeekMode.SEEK_CLOSEST;
    }
    try {
      this.avPlayer.seek(positionMs, mode);
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'seek exception: %{public}s', (e as Error).message);
    }
  }

  /** release / destroy */
  async release(): Promise<void> {
    if (this.released) {
      return;
    }
    this.released = true;
    if (this.avPlayer !== null) {
      try {
        await this.avPlayer.release();
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'release failed: %{public}s', (e as Error).message);
      }
      this.avPlayer = null;
    }
    this.isPrepared = false;
    this.listenersBound = false;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'release ok, playerId=%{public}s', this.playerId);
  }

  // ============== 配置 API ==============

  setVolume(volume: number): void {
    // Aliyun 允许 0~2, AVPlayer 限 0~1, 做 clamp
    const v = Math.min(1.0, Math.max(0.0, volume));
    if (!this.muted) {
      this.savedVolume = v;
    }
    if (this.avPlayer === null) {
      return;
    }
    try {
      this.avPlayer.setVolume(this.muted ? 0 : v);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setVolume failed: %{public}s', (e as Error).message);
    }
  }

  getVolume(): number {
    return this.savedVolume;
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
    this.setVolume(this.savedVolume);
  }

  isMuted(): boolean {
    return this.muted;
  }

  setSpeed(speed: number): void {
    this.currentSpeed = speed;
    if (this.avPlayer === null) {
      return;
    }
    const pbSpeed = this.mapSpeedToAVPlayer(speed);
    try {
      this.avPlayer.setSpeed(pbSpeed);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setSpeed failed: %{public}s', (e as Error).message);
    }
  }

  getSpeed(): number {
    return this.currentSpeed;
  }

  private mapSpeedToAVPlayer(speed: number): media.PlaybackSpeed {
    // Aliyun speed 为浮点, 映射到最近的 PlaybackSpeed 枚举
    if (speed <= 0.25) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_25_X;
    } else if (speed <= 0.5) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_50_X;
    } else if (speed <= 0.75) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    } else if (speed <= 1.0) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    } else if (speed <= 1.25) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    } else if (speed <= 1.5) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    } else if (speed <= 1.75) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    } else if (speed <= 2.0) {
      return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    } else {
      return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
  }

  setLoop(loop: boolean): void {
    this.loop = loop;
    if (this.avPlayer !== null && this.isPrepared) {
      try {
        this.avPlayer.loop = loop;
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'setLoop failed: %{public}s', (e as Error).message);
      }
    }
  }

  isLoop(): boolean {
    return this.loop;
  }

  setAutoPlay(autoPlay: boolean): void {
    this.autoPlay = autoPlay;
  }

  isAutoPlay(): boolean {
    return this.autoPlay;
  }

  /** Aliyun ScaleMode: 0=FIT, 1=FILL(crop), 2=TO_FILL(stretch) */
  setScalingMode(mode: number): void {
    if (this.avPlayer === null) {
      return;
    }
    let scaleType: media.VideoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
    if (mode === 0) {
      scaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
    } else if (mode === 1) {
      scaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP;
    } else if (mode === 2) {
      scaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_SCALED_ASPECT;
    }
    try {
      this.avPlayer.videoScaleType = scaleType;
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setScalingMode failed: %{public}s', (e as Error).message);
    }
  }

  getScalingMode(): number {
    if (this.avPlayer === null) {
      return 0;
    }
    try {
      const t = this.avPlayer.videoScaleType;
      if (t === media.VideoScaleType.VIDEO_SCALE_TYPE_FIT) {
        return 0;
      } else if (t === media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP) {
        return 1;
      } else if (t === media.VideoScaleType.VIDEO_SCALE_TYPE_SCALED_ASPECT) {
        return 2;
      }
    } catch (e) {
      // ignore
    }
    return 0;
  }

  getDuration(): number {
    if (this.avPlayer === null) {
      return 0;
    }
    try {
      return this.avPlayer.duration;
    } catch (e) {
      return 0;
    }
  }

  getCurrentPosition(): number {
    if (this.avPlayer === null) {
      return 0;
    }
    try {
      return this.avPlayer.currentTime;
    } catch (e) {
      return 0;
    }
  }

  getVideoWidth(): number {
    if (this.avPlayer === null) {
      return 0;
    }
    try {
      return this.avPlayer.width;
    } catch (e) {
      return 0;
    }
  }

  getVideoHeight(): number {
    if (this.avPlayer === null) {
      return 0;
    }
    try {
      return this.avPlayer.height;
    } catch (e) {
      return 0;
    }
  }

  // ============== 轨道管理 (P1) ==============

  async getTrackDescription(): Promise<Array<media.MediaDescription>> {
    if (this.avPlayer === null) {
      return [];
    }
    try {
      return await this.avPlayer.getTrackDescription();
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'getTrackDescription failed: %{public}s', (e as Error).message);
      return [];
    }
  }

  async selectTrack(index: number): Promise<void> {
    if (this.avPlayer === null) {
      return;
    }
    try {
      await this.avPlayer.selectTrack(index);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'selectTrack failed: %{public}s', (e as Error).message);
    }
  }

  // ============== 事件下发 ==============

  /** 构造事件 Map (带 method + playerId) */
  private newEvent(method: string): Map<string, Object> {
    const data = new Map<string, Object>();
    data.set('method', method);
    data.set('playerId', this.playerId);
    return data;
  }

  /** 通过共享 EventSink 下发事件 */
  private emit(data: Map<string, Object>): void {
    this.emitEvent(data);
  }

  /** 通过 BasicMessageChannel 下发 onPrepare (Dart 侧使用 StringCodec + JSON) */
  private emitPrepared(): void {
    const event: PlayerCallbackEvent = { method: 'onPrepared', playerId: this.playerId };
    const json = JSON.stringify(event);
    this.sendBasicMessage('aliPlayer_onPrepare' + this.playerId, json);
    // 同时通过 EventChannel 下发 (Dart _onEvent 也处理 onPrepared)
    this.emitEvent(this.newEvent('onPrepared'));
  }

  /** 通过 BasicMessageChannel 下发 onRenderingStart */
  private emitRenderingStart(): void {
    const event: PlayerCallbackEvent = { method: 'onRenderingStart', playerId: this.playerId };
    const json = JSON.stringify(event);
    this.sendBasicMessage('aliPlayer_onRenderingStart' + this.playerId, json);
  }

  /** 通过 BasicMessageChannel 下发 onStateChanged (Dart _onEvent 中已注释, 必须走 BasicMessageChannel) */
  private emitStateChanged(state: number): void {
    const event: StateChangedCallbackEvent = { method: 'onStateChanged', playerId: this.playerId, newState: state };
    const json = JSON.stringify(event);
    this.sendBasicMessage('aliPlayer_onStateChanged' + this.playerId, json);
  }

  private sendBasicMessage(channelName: string, message: string): void {
    try {
      const channel = new BasicMessageChannel(this.messenger, channelName, StringCodec.INSTANCE);
      channel.send(message, (_reply: string) => {});
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'sendBasicMessage failed: %{public}s', (e as Error).message);
    }
  }

  /** 发送 error 事件 */
  private sendError(code: number, extra: string, msg: string): void {
    const data = this.newEvent('onError');
    data.set('errorCode', code);
    data.set('errorExtra', extra);
    data.set('errorMsg', msg);
    this.emitEvent(data);
  }
}
