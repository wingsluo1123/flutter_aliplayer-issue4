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
import alphaCompositor from 'libalpha_compositor.so';
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

/** MediaKit 业务错误的对象形态 (仅取 business error code) */
interface MediaErrorLike {
  code?: number;
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
  // surfaceId 是否已成功赋值过。MediaKit 规定首次赋值只能在 initialized 状态,
  // 赋值过之后才可在 prepared/playing/paused/completed/stopped 状态更新。
  private surfaceIdApplied: boolean = false;
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
  private pendingPrepare: boolean = false;
  // Alpha 合成渲染器句柄 ('' = 未创建)。mode≠0 时 AVPlayer 输出到离屏 surface,
  // 由 C++ AlphaCompositeRenderer 合成后画到 XComponent surface。
  private alphaRendererHandle: string = '';
  private alphaMode: number = 0;
  // Aliyun ScaleMode: 0=FIT, 1=FILL, 2=TO_FILL。Alpha 模式下需转发给合成器。
  private scalingMode: number = 0;

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
      // 转发 AVPlayer 的真实错误码 (BusinessError.code), 不要硬编码成 5400102 掩盖根因
      this.sendError(this.errCodeOf(err), err.message, 'AVPlayer error');
    });
    player.on('videoSizeChange', (width: number, height: number) => {
      // 合成器需要源尺寸计算半幅内容尺寸与缩放 (离屏 producer 窗口查不到几何)
      this.pushVideoSizeToCompositor(width, height);
      // Alpha 模式下对外报合成后(可见内容)尺寸, 与 getVideoWidth/Height 语义一致
      const size = this.toReportedSize(width, height);
      const data = this.newEvent('onVideoSizeChanged');
      data.set('width', size[0]);
      data.set('height', size[1]);
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
      // setUrl 后过早调用的 prepare 在此状态才可执行
      if (this.pendingPrepare) {
        this.pendingPrepare = false;
        this.prepare();
      }
    } else if (state === 'prepared') {
      this.isPrepared = true;
      // prepared 状态可更新已赋值过的 surfaceId — 重放延后的切换
      // (典型场景: prepare 之后才调用 setAlphaRenderMode, 此时 surface 只能延后)
      this.replayPendingSurfaceId();
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

  /** @returns 是否已真正写入 AVPlayer.surfaceId (延后待应用时返回 false) */
  private applySurfaceId(): boolean {
    if (this.avPlayer === null) {
      return false;
    }
    const sid = this.resolveTargetSurfaceId();
    if (sid === null || sid === undefined || sid.length === 0) {
      return false;
    }
    // MediaKit (@ohos.multimedia.media.d.ts, surfaceId) 的赋值规则:
    //   - 首次赋值只能在 'initialized' 状态;
    //   - 赋值过之后, 可在 prepared / playing / paused / completed / stopped 状态更新。
    // idle / error 等状态赋值会抛 5400102 (Operation not allowed), 因此延后到
    // initialized (handleStateChange) 再真正设置。
    if (!this.canSetSurfaceId()) {
      this.pendingSurfaceId = sid;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'applySurfaceId deferred (state=%{public}s): %{public}s',
        this.currentState, sid);
      return false;
    }
    try {
      this.avPlayer.surfaceId = sid;
      this.surfaceIdApplied = true;
      this.pendingSurfaceId = null;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'applySurfaceId ok: %{public}s', sid);
      return true;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'applySurfaceId failed: %{public}s', (e as Error).message);
      return false;
    }
  }

  /** 当前状态是否允许给 AVPlayer.surfaceId 赋值 (见 applySurfaceId 的状态规则注释) */
  private canSetSurfaceId(): boolean {
    if (this.currentState === 'initialized') {
      return true;
    }
    if (!this.surfaceIdApplied) {
      return false;
    }
    return this.currentState === 'prepared' || this.currentState === 'playing' ||
      this.currentState === 'paused' || this.currentState === 'completed' ||
      this.currentState === 'stopped';
  }

  /** 有延后未应用的 surface 时, 在允许赋值的状态重放一次 */
  private replayPendingSurfaceId(): void {
    if (this.pendingSurfaceId === null) {
      return;
    }
    this.applySurfaceId();
  }

  /** 计算当前要应用的渲染面 surfaceId: alpha 模式下为合成 renderer 的离屏 producer 面 */
  private resolveTargetSurfaceId(): string {
    if (this.alphaRendererHandle !== '') {
      return alphaCompositor.getProducerSurfaceId(this.alphaRendererHandle) as string;
    }
    return this.pendingSurfaceId !== null ? this.pendingSurfaceId : (this.surfaceId ?? '');
  }

  /**
   * 设置 Alpha 渲染模式 (issue #3 问题一, Texture 路径)。
   * mode=0: 直出 XComponent surface (默认路径, 零开销);
   * mode=1-4: 创建 C++ 合成渲染器, AVPlayer 输出到离屏 surface,
   *          GLES shader 合成后画到 alphaTargetSurfaceId (Flutter 纹理 surface)。
   * alphaTargetSurfaceId: 由 plugin 经 TextureRegistry 创建并传入; 传空则回退 XComponent surface。
   */
  setAlphaRenderMode(mode: number, alphaTargetSurfaceId?: string, nativeWindowPtr?: string): boolean {
    if (mode === this.alphaMode) {
      return true;
    }
    if (mode === 0) {
      // 切回直出: 销毁合成渲染器, AVPlayer 重新指向 XComponent surface
      if (this.alphaRendererHandle !== '') {
        alphaCompositor.destroyRenderer(this.alphaRendererHandle);
        this.alphaRendererHandle = '';
      }
      this.alphaMode = 0;
      // 清掉可能残留的离屏 surface — 否则 resolveTargetSurfaceId 会继续返回它,
      // 导致切回直出后画面仍指向已销毁的合成器
      this.pendingSurfaceId = null;
      this.applySurfaceId();
      return true;
    }
    if (mode < 1 || mode > 4) {
      return false;
    }
    // 合成目标: 优先纹理 surface (透出下层 Widget), 无纹理时回退 XComponent surface
    const targetSid = (alphaTargetSurfaceId !== undefined && alphaTargetSurfaceId.length > 0)
      ? alphaTargetSurfaceId : this.surfaceId;
    if (targetSid === null || targetSid === undefined || targetSid.length === 0) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setAlphaRenderMode(%{public}d) deferred: no target surface yet', mode);
      return false;
    }
    try {
      if (this.alphaRendererHandle === '') {
        this.alphaRendererHandle = nativeWindowPtr !== undefined && nativeWindowPtr.length > 0
          ? alphaCompositor.createRenderer(targetSid, nativeWindowPtr) as string
          : alphaCompositor.createRenderer(targetSid) as string;
        hilog.info(LOG_DOMAIN, LOG_TAG, 'alpha renderer created: %{public}s target=%{public}s win=%{public}s',
          this.alphaRendererHandle, targetSid, nativeWindowPtr ?? 'none');
        // 新建的合成器需继承此前已设置的缩放模式
        alphaCompositor.setScalingMode(this.alphaRendererHandle, this.scalingMode);
        // videoSizeChange 可能早于合成器创建 (Alpha 常在 prepared 后开启),
        // 因此创建后立即补推一次已知的源尺寸
        try {
          if (this.avPlayer !== null) {
            this.pushVideoSizeToCompositor(this.avPlayer.width, this.avPlayer.height);
          }
        } catch (e) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, 'push initial video size failed: %{public}s',
            (e as Error).message);
        }
      }
      alphaCompositor.setMode(this.alphaRendererHandle, mode);
      this.alphaMode = mode;
      // AVPlayer 切到离屏 surface: 首次赋值须等 initialized, 之后可在
      // prepared/playing 等状态更新; 不允许时 applySurfaceId 会延后并重放。
      this.applySurfaceId();
      return true;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'setAlphaRenderMode(%{public}d) failed: %{public}s',
        mode, (e as Error).message);
      return false;
    }
  }

  getAlphaRenderMode(): number {
    return this.alphaMode;
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
    // setUrl 后 AVPlayer 需异步进入 initialized 才允许 prepare, 挂起到状态就绪
    if (this.currentState !== 'initialized') {
      this.pendingPrepare = true;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'prepare deferred (state=%{public}s), playerId=%{public}s',
        this.currentState, this.playerId);
      return;
    }
    try {
      this.avPlayer.prepare().then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'prepare ok, playerId=%{public}s', this.playerId);
      }).catch((e: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'prepare failed: %{public}s', e.message);
        this.sendError(this.errCodeOf(e), e.message, 'prepare failed');
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
    // 播放完成后再次播放: AVPlayer completed 状态下 seek(0) + play 即可重新起播,
    // 进度条随之归零 (对齐阿里云播放器语义)。
    if (this.currentState === 'completed') {
      try {
        this.avPlayer.seek(0, media.SeekMode.SEEK_PREV_SYNC);
        this.doPlay();
        return;
      } catch (e) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'play after completed exception: %{public}s', (e as Error).message);
      }
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
        this.sendError(this.errCodeOf(e), e.message, 'play failed');
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

  /** stop: AVPlayer stop 后回到 idle, 需 reset + 重新 setUrl 才能再次播放。
   *  对齐阿里云语义: stop 后 play() 应可重新起播。 */
  stop(): void {
    if (this.avPlayer === null) {
      return;
    }
    const savedUrl = this.url;
    this.isPrepared = false;
    try {
      this.avPlayer.stop().then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'stop ok, resetting, playerId=%{public}s', this.playerId);
        this.avPlayer!.reset().then(() => {
          this.currentState = 'idle';
          // reset 后 AVPlayer 回到全新状态, 首次 surfaceId 赋值须重新走 initialized
          this.surfaceIdApplied = false;
          if (savedUrl !== null) {
            try {
              this.avPlayer!.url = savedUrl;
              // 重新 prepare (initialized 到达后由 pendingPrepare 触发)
              this.prepare();
            } catch (e) {
              hilog.error(LOG_DOMAIN, LOG_TAG, 'stop re-setUrl failed: %{public}s', (e as Error).message);
            }
          }
        }).catch((e: Error) => {
          hilog.error(LOG_DOMAIN, LOG_TAG, 'stop reset failed: %{public}s', e.message);
        });
      }).catch((e: Error) => {
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
        // reset 后 AVPlayer 回到全新状态, 首次 surfaceId 赋值须重新走 initialized
        this.surfaceIdApplied = false;
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
    // 释放 Alpha 合成渲染器
    if (this.alphaRendererHandle !== '') {
      try {
        alphaCompositor.destroyRenderer(this.alphaRendererHandle);
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'destroy alpha renderer failed: %{public}s', (e as Error).message);
      }
      this.alphaRendererHandle = '';
      this.alphaMode = 0;
    }
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
    // Alpha 模式下 AVPlayer 输出到离屏面, 实际呈现由合成器决定:
    // 合成器的缩放基准是"合成后半幅尺寸", 需同步转发, 否则缩放不生效。
    if (this.alphaRendererHandle !== '') {
      try {
        alphaCompositor.setScalingMode(this.alphaRendererHandle, mode);
        this.scalingMode = mode;
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'setScalingMode on compositor failed: %{public}s',
          (e as Error).message);
      }
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
      return this.toReportedSize(this.avPlayer.width, this.avPlayer.height)[0];
    } catch (e) {
      return 0;
    }
  }

  getVideoHeight(): number {
    if (this.avPlayer === null) {
      return 0;
    }
    try {
      return this.toReportedSize(this.avPlayer.width, this.avPlayer.height)[1];
    } catch (e) {
      return 0;
    }
  }

  /**
   * 把源视频显示尺寸推给合成器。
   * 合成器无法自行获取该尺寸: 离屏 producer 窗口的 GET_BUFFER_GEOMETRY 实测恒为 0x0,
   * 而 AVPlayer.width/height 是权威值 (且已含旋转元数据修正)。
   */
  private pushVideoSizeToCompositor(width: number, height: number): void {
    if (this.alphaRendererHandle === '' || width <= 0 || height <= 0) {
      return;
    }
    try {
      alphaCompositor.setVideoSize(this.alphaRendererHandle, width, height);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setVideoSize on compositor failed: %{public}s',
        (e as Error).message);
    }
  }

  /**
   * 对外上报的视频尺寸。AVPlayer 给出的是原始(拼接后)帧尺寸; Alpha 模式下可见内容
   * 只占半幅 (mode=1/2 取左右半 → 宽减半; mode=3/4 取上下半 → 高减半),
   * 因此对外报合成后尺寸, 保证业务按返回尺寸计算宽高比/布局时与画面一致。
   */
  private toReportedSize(fullWidth: number, fullHeight: number): number[] {
    if (this.alphaMode === 1 || this.alphaMode === 2) {
      return [Math.floor(fullWidth / 2), fullHeight];
    }
    if (this.alphaMode === 3 || this.alphaMode === 4) {
      return [fullWidth, Math.floor(fullHeight / 2)];
    }
    return [fullWidth, fullHeight];
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

  /** 提取 MediaKit 业务错误码 (BusinessError.code); 无 code 时回退 5400102 */
  private errCodeOf(e: Error): number {
    const code = (e as MediaErrorLike).code;
    return typeof code === 'number' ? code : 5400102;
  }
}
