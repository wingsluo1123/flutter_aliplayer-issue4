/**
 * AliPlayerProxy
 *
 * 鸿蒙侧播放器内核封装 —— 直接桥接阿里云官方 HarmonyOS 播放器 SDK
 * (`premierlibrary`)，与 Android/iOS 侧保持同一套语义。
 *
 * 迁移背景 (issue #4):
 *   原实现基于系统 MediaKit AVPlayer「重新实现」阿里云播放器语义，导致:
 *     1. 本地文件播不了 (AVPlayer.url 只接受 http(s):// 与 fd://, file:// 报 onError 401);
 *     2. 同实例换源静默失败 (stop().then(reset()) 异步链 + try/catch 吞异常);
 *     3. Alpha 合成纹理尺寸写死 1280x720, 与上报尺寸不一致 (需自研 C++ 合成器)。
 *   改为转发官方 SDK 后，上述问题由 SDK 自身状态机与实现消除:
 *     - 官方 6.21.0 起原生支持 file:// 本地视频;
 *     - 换源为同步调用, 不再有异步链与吞异常;
 *     - Alpha 由官方 setAlphaRenderMode 内部合成, 自研合成器整体移除。
 *
 * 职责: 播放器生命周期、状态机映射、播控、事件回调转发。
 * 事件仍通过共享 EventSink + 按 playerId 拼接的 BasicMessageChannel 双通道下发,
 * 与 Dart 侧 _onEvent / setMessageHandler 严格对齐 (Dart 协议不变)。
 */
import { AliPlayerFactory, AliPlayer, UrlSource } from 'premierlibrary';
import type { ErrorInfo, InfoBean, MediaInfo, TrackInfo } from 'premierlibrary';
import { AlphaRenderMode, ScaleMode } from 'premierlibrary/src/main/ets/com/aliyun/player/IPlayer';
import common from '@ohos.app.ability.common';
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

/** Aliyun 播放器状态枚举 (与 Dart 侧 PlayState 及官方 IPlayer 常量对齐) */
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
  private context: common.Context;

  private player: AliPlayer | null = null;
  /** 官方 SDK 状态 (与 AliPlayerState 同值), 默认 idle */
  private state: number = AliPlayerState.IDLE;
  private surfaceId: string | null = null;
  private url: string | null = null;
  private released: boolean = false;
  private autoPlay: boolean = false;
  private muted: boolean = false;
  private savedVolume: number = 1.0;
  private loop: boolean = false;
  private currentSpeed: number = 1.0;
  private alphaMode: number = 0;
  /** play() 早于 prepared 时挂起, 待 onPrepared 后执行 */
  private pendingPlay: boolean = false;
  private pendingSeekMs: number = -1;
  private pendingSeekMode: number = 1;

  constructor(
    playerId: string,
    messenger: BinaryMessenger,
    emitEvent: EmitEventCallback,
    context: common.Context,
  ) {
    this.playerId = playerId;
    this.messenger = messenger;
    this.emitEvent = emitEvent;
    this.context = context;
  }

  getPlayerId(): string {
    return this.playerId;
  }

  /** 创建官方播放器并绑定事件监听 */
  async create(): Promise<void> {
    try {
      this.player = AliPlayerFactory.createAliPlayer(this.context, this.playerId);
      this.bindListeners();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'createAliPlayer ok, playerId=%{public}s', this.playerId);
    } catch (e) {
      const err = e as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'createAliPlayer failed: %{public}s', err.message);
      this.sendError(5400101, err.message, 'createAliPlayer failed');
    }
  }

  /** 绑定官方 SDK 事件回调 (仅绑定一次) */
  private bindListeners(): void {
    const p = this.player;
    if (p === null) {
      return;
    }

    p.setOnStateChangedListener({
      onStateChanged: (newState: number): void => {
        this.state = newState;
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onStateChanged=%{public}d, playerId=%{public}s',
          newState, this.playerId);
        // 官方状态值 (idle0/initalized1/prepared2/started3/paused4/stopped5/completion6/error7)
        // 与 AliPlayerState 同值, 直接转发
        this.emitStateChanged(newState);
      }
    });

    p.setOnPreparedListener({
      onPrepared: (): void => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onPrepared, playerId=%{public}s', this.playerId);
        this.emitPrepared();
        if (this.pendingSeekMs >= 0) {
          this.doSeek(this.pendingSeekMs, this.pendingSeekMode);
          this.pendingSeekMs = -1;
        }
        if (this.pendingPlay) {
          this.pendingPlay = false;
          this.doPlay();
        }
      }
    });

    p.setOnRenderingStartListener({
      onRenderingStart: (): void => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onRenderingStart, playerId=%{public}s', this.playerId);
        this.emitRenderingStart();
        this.emitEvent(this.newEvent('onRenderingStart'));
      }
    });

    p.setOnErrorListener({
      onError: (info: ErrorInfo): void => {
        // 转发官方真实错误码, 不做硬编码兜底 (避免掩盖根因)
        const code = info.getCode();
        const msg = info.getMsg();
        hilog.error(LOG_DOMAIN, LOG_TAG, 'onError code=%{public}d msg=%{public}s extra=%{public}s',
          code, msg, info.getExtra());
        this.state = AliPlayerState.ERROR;
        this.sendError(code, msg, 'AliPlayer error');
      }
    });

    p.setOnVideoSizeChangedListener({
      onVideoSizeChanged: (width: number, height: number): void => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onVideoSizeChanged %{public}dx%{public}d', width, height);
        const data = this.newEvent('onVideoSizeChanged');
        data.set('width', width);
        data.set('height', height);
        data.set('rotation', this.getVideoRotation());
        this.emitEvent(data);
      }
    });

    p.setOnCompletionListener({
      onCompletion: (): void => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onCompletion, playerId=%{public}s', this.playerId);
        this.emitEvent(this.newEvent('onCompletion'));
      }
    });

    p.setOnInfoListener({
      onInfo: (infoBean: InfoBean): void => {
        const data = this.newEvent('onInfo');
        data.set('infoCode', infoBean.getCode());
        data.set('extraValue', infoBean.getExtraValue());
        data.set('extraMsg', infoBean.getExtraMsg());
        this.emitEvent(data);
      }
    });

    p.setOnLoadingStatusListener({
      onLoadingBegin: (): void => {
        this.emitEvent(this.newEvent('onLoadingBegin'));
      },
      onLoadingProgress: (percent: number, netSpeed: number): void => {
        const data = this.newEvent('onLoadingProgress');
        data.set('percent', percent);
        data.set('netSpeed', netSpeed);
        this.emitEvent(data);
      },
      onLoadingEnd: (): void => {
        this.emitEvent(this.newEvent('onLoadingEnd'));
      }
    });

    p.setOnSeekCompleteListener({
      onSeekComplete: (): void => {
        this.emitEvent(this.newEvent('onSeekComplete'));
      }
    });
  }

  // ============== 播控 API ==============

  /**
   * 设置 URL 数据源。
   *
   * 本地文件 (issue 阻塞点 #1): 官方 6.21.0 起原生支持以 "file://" 开头的本地视频,
   * 无需再转 fd。这里额外把「无 scheme 的绝对路径」规范化为 file://,
   * 便于接入方直接传沙箱绝对路径。
   *
   * 换源 (issue 阻塞点 #2): 官方为同步调用, 无异步链、无吞异常。
   */
  setUrl(url: string): void {
    this.url = url;
    if (this.player === null) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setUrl but player is null');
      return;
    }
    const normalized = this.normalizeUrl(url);
    try {
      const src = new UrlSource();
      src.setUri(normalized);
      this.player.setUrlDataSource(src);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'setUrl ok: %{public}s', normalized);
    } catch (e) {
      // 不再静默吞掉: 记录并把失败原因上报, 避免接入方遇到「不报错但不生效」
      const err = e as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'setUrl failed: %{public}s', err.message);
      this.sendError(5400102, err.message, 'setUrl failed');
    }
  }

  /**
   * 规范化播放地址。
   * 官方支持 http(s):// 与 file://; 对沙箱绝对路径 (以 / 开头) 补 file:// 前缀,
   * 否则 SDK 无法识别协议。
   */
  private normalizeUrl(url: string): string {
    if (url.startsWith('/')) {
      return `file://${url}`;
    }
    return url;
  }

  /** 设置渲染面 (官方要求: 对应带 libraryname: 'premierlibrary' 的 XComponent 的 id) */
  setSurfaceId(surfaceId: string): void {
    this.surfaceId = surfaceId;
    if (this.player === null) {
      return;
    }
    try {
      this.player.setSurfaceId(surfaceId);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'setSurfaceId ok: %{public}s', surfaceId);
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'setSurfaceId failed: %{public}s', (e as Error).message);
    }
  }

  /**
   * 设置 Alpha 渲染模式。
   *
   * 官方 SDK 内部完成透明合成 (无需自研 C++ 合成器):
   * mode=0 无 Alpha; 1=alpha 在右; 2=在左; 3=在上; 4=在下。
   * 注意: Alpha 生效要求渲染面为 XComponentType.TEXTURE 且带 libraryname。
   *
   * @param alphaTargetSurfaceId / nativeWindowPtr 仅为保持 Dart 侧调用签名兼容,
   *        官方实现下不再需要 (Alpha 由 SDK 内部合成到同一渲染面)。
   */
  setAlphaRenderMode(mode: number, _alphaTargetSurfaceId?: string, _nativeWindowPtr?: string): boolean {
    if (mode < 0 || mode > 4) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setAlphaRenderMode invalid mode=%{public}d', mode);
      return false;
    }
    if (this.player === null) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setAlphaRenderMode(%{public}d) deferred: no player', mode);
      return false;
    }
    try {
      this.player.setAlphaRenderMode(mode as AlphaRenderMode);
      this.alphaMode = mode;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'setAlphaRenderMode ok: %{public}d', mode);
      return true;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'setAlphaRenderMode(%{public}d) failed: %{public}s',
        mode, (e as Error).message);
      return false;
    }
  }

  getAlphaRenderMode(): number {
    if (this.player === null) {
      return this.alphaMode;
    }
    try {
      return this.player.getAlphaRenderMode() as number;
    } catch (e) {
      return this.alphaMode;
    }
  }

  /** prepare */
  prepare(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.prepare();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'prepare called, playerId=%{public}s', this.playerId);
    } catch (e) {
      const err = e as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'prepare failed: %{public}s', err.message);
      this.sendError(5400102, err.message, 'prepare failed');
    }
  }

  /** play (官方 start) */
  play(): void {
    if (this.player === null) {
      return;
    }
    // 播放完成后再次播放: 官方 start() 在末位会立刻再次 completion,
    // 需先 seek(0) 再 start 才能重新起播, 进度条随之归零
    // (对齐阿里云播放器语义, 与旧实现行为一致)。
    if (this.state === AliPlayerState.COMPLETION) {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'play after completion: seek(0) then start');
      this.doSeek(0, 1);
      this.doPlay();
      return;
    }
    if (this.state === AliPlayerState.PREPARED || this.state === AliPlayerState.STARTED ||
        this.state === AliPlayerState.PAUSED) {
      this.doPlay();
      return;
    }
    // 尚未 prepared: 挂起, 待 onPrepared 后执行
    this.pendingPlay = true;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'play deferred (state=%{public}d)', this.state);
  }

  private doPlay(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.start();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'start ok, playerId=%{public}s', this.playerId);
    } catch (e) {
      const err = e as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'start failed: %{public}s', err.message);
      this.sendError(5400102, err.message, 'start failed');
    }
  }

  /** pause */
  pause(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.pause();
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'pause failed: %{public}s', (e as Error).message);
    }
  }

  /**
   * stop。
   *
   * 与旧实现的本质区别: 旧实现在这里挂 `stop().then(reset())` 异步链并在回调里
   * 回写旧 url, 导致紧接着的 setUrl 抛异常被吞、旧视频继续播 (issue 阻塞点 #2)。
   * 官方 SDK 为同步调用, 状态机自行管理, 这里只做一次 stop。
   */
  stop(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.stop();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'stop ok, playerId=%{public}s', this.playerId);
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'stop failed: %{public}s', (e as Error).message);
    }
  }

  /** reload: 网络重连 (官方原生支持) */
  reload(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.reload();
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'reload failed: %{public}s', (e as Error).message);
    }
  }

  /** seekTo, positionMs 为毫秒, seekMode: 1=ACCURATE, 16=INACCURATE (官方直接透传) */
  seekTo(positionMs: number, seekMode: number): void {
    if (this.player === null) {
      return;
    }
    if (this.state === AliPlayerState.PREPARED || this.state === AliPlayerState.STARTED ||
        this.state === AliPlayerState.PAUSED || this.state === AliPlayerState.COMPLETION) {
      this.doSeek(positionMs, seekMode);
      return;
    }
    this.pendingSeekMs = positionMs;
    this.pendingSeekMode = seekMode;
  }

  private doSeek(positionMs: number, seekMode: number): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.seekTo(positionMs, seekMode);
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'seek failed: %{public}s', (e as Error).message);
    }
  }

  /** release / destroy */
  async release(): Promise<void> {
    if (this.released) {
      return;
    }
    this.released = true;
    if (this.player !== null) {
      try {
        this.player.stop();
        this.player.release();
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'release failed: %{public}s', (e as Error).message);
      }
      this.player = null;
    }
    this.state = AliPlayerState.IDLE;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'release ok, playerId=%{public}s', this.playerId);
  }

  // ============== 配置 API ==============

  /** 官方 setVolume 支持 0.0~2.0 (与阿里云语义一致), 无需再 clamp 到 1.0 */
  setVolume(volume: number): void {
    if (!this.muted) {
      this.savedVolume = volume;
    }
    if (this.player === null) {
      return;
    }
    try {
      this.player.setVolume(this.muted ? 0 : volume);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setVolume failed: %{public}s', (e as Error).message);
    }
  }

  getVolume(): number {
    if (this.player === null) {
      return this.savedVolume;
    }
    try {
      return this.player.getVolume();
    } catch (e) {
      return this.savedVolume;
    }
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
    if (this.player === null) {
      return;
    }
    try {
      this.player.setMute(muted);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setMute failed: %{public}s', (e as Error).message);
    }
  }

  isMuted(): boolean {
    if (this.player === null) {
      return this.muted;
    }
    try {
      return this.player.isMuted();
    } catch (e) {
      return this.muted;
    }
  }

  /** 官方 setSpeed 支持 [0.5, 5] 浮点, 无需再映射到枚举 */
  setSpeed(speed: number): void {
    this.currentSpeed = speed;
    if (this.player === null) {
      return;
    }
    try {
      this.player.setSpeed(speed);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setSpeed failed: %{public}s', (e as Error).message);
    }
  }

  getSpeed(): number {
    if (this.player === null) {
      return this.currentSpeed;
    }
    try {
      return this.player.getSpeed();
    } catch (e) {
      return this.currentSpeed;
    }
  }

  setLoop(loop: boolean): void {
    this.loop = loop;
    if (this.player === null) {
      return;
    }
    try {
      this.player.setLoop(loop);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setLoop failed: %{public}s', (e as Error).message);
    }
  }

  isLoop(): boolean {
    if (this.player === null) {
      return this.loop;
    }
    try {
      return this.player.isLoop();
    } catch (e) {
      return this.loop;
    }
  }

  setAutoPlay(autoPlay: boolean): void {
    this.autoPlay = autoPlay;
    if (this.player === null) {
      return;
    }
    try {
      this.player.setAutoPlay(autoPlay);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setAutoPlay failed: %{public}s', (e as Error).message);
    }
  }

  isAutoPlay(): boolean {
    if (this.player === null) {
      return this.autoPlay;
    }
    try {
      return this.player.isAutoPlay();
    } catch (e) {
      return this.autoPlay;
    }
  }

  /** Aliyun ScaleMode: 0=FIT, 1=FILL, 2=TO_FILL — 与官方 ScaleMode 枚举值一一对应 */
  setScalingMode(mode: number): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.setScaleMode(mode as ScaleMode);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setScaleMode failed: %{public}s', (e as Error).message);
    }
  }

  getScalingMode(): number {
    if (this.player === null) {
      return 0;
    }
    try {
      return this.player.getScaleMode() as number;
    } catch (e) {
      return 0;
    }
  }

  getDuration(): number {
    if (this.player === null) {
      return 0;
    }
    try {
      return this.player.getDuration();
    } catch (e) {
      return 0;
    }
  }

  getCurrentPosition(): number {
    if (this.player === null) {
      return 0;
    }
    try {
      return this.player.getCurrentPosition();
    } catch (e) {
      return 0;
    }
  }

  getVideoRotation(): number {
    if (this.player === null) {
      return 0;
    }
    try {
      return this.player.getVideoRotation();
    } catch (e) {
      return 0;
    }
  }

  /**
   * 上报视频尺寸。
   *
   * 迁移说明: Alpha 模式下由官方 SDK 内部完成合成, 尺寸语义与 Android/iOS 一致
   * (直接返回 SDK 值, 不再做「半幅」换算) —— 与 Android 侧 FlutterAliPlayer 行为对齐。
   */
  getVideoWidth(): number {
    if (this.player === null) {
      return 0;
    }
    try {
      return this.player.getVideoWidth();
    } catch (e) {
      return 0;
    }
  }

  getVideoHeight(): number {
    if (this.player === null) {
      return 0;
    }
    try {
      return this.player.getVideoHeight();
    } catch (e) {
      return 0;
    }
  }

  // ============== 轨道管理 ==============

  async getTrackDescription(): Promise<Array<Object>> {
    const out = new Array<Object>();
    if (this.player === null) {
      return out;
    }
    try {
      const info: MediaInfo | null = this.player.getMediaInfo();
      if (info === null || info === undefined) {
        return out;
      }
      const tracks: TrackInfo[] = info.getTrackInfos();
      if (tracks === null || tracks === undefined) {
        return out;
      }
      for (let i = 0; i < tracks.length; i++) {
        const t = tracks[i];
        const m = new Map<string, Object>();
        m.set('index', t.getIndex());
        m.set('type', t.getType() as number);
        out.push(m);
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'getTrackDescription failed: %{public}s', (e as Error).message);
    }
    return out;
  }

  async selectTrack(index: number): Promise<void> {
    if (this.player === null) {
      return;
    }
    try {
      this.player.selectTrack(index);
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
    const event: StateChangedCallbackEvent = {
      method: 'onStateChanged',
      playerId: this.playerId,
      newState: state
    };
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
