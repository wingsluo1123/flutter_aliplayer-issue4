import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AliPlayerFactory, AliPlayer, UrlSource, VidSts, VidAuth, VidMps, LiveSts,
  ScaleMode, PlayerConfig, InfoBean, ErrorInfo,
  MediaInfo, TrackInfo, TrackType,
  Logger, AliPlayerGlobalSettings
} from 'premierlibrary';
import { VidPlayerConfigGen } from 'premierlibrary/src/main/ets/com/aliyun/player/VidPlayerConfigGen';
import {
  OnPreparedListener, OnRenderingStartListener, OnStateChangedListener,
  OnCompletionListener, OnLoadingStatusListener, OnErrorListener,
  OnInfoListener, OnVideoSizeChangedListener, OnSeekCompleteListener,
  OnSubtitleDisplayListener, OnSnapShotListener, OnSeiDataListener,
  OnStreamSwitchedListener, OnTrackChangedListener, OnTrackReadyListener,
  OnSubTrackReadyListener, OnVideoRenderedListener
} from 'premierlibrary/src/main/ets/com/aliyun/player/IPlayer';
import { StsInfo } from 'premierlibrary/src/main/ets/com/aliyun/player/source/StsInfo';
import common from '@ohos.app.ability.common';

// Player state constants (from AliPlayer SDK)
const STATE_PREPARED = 2;
const STATE_STARTED = 3;
const STATE_PAUSED = 4;
const STATE_STOPPED = 6;
// Float comparison epsilon
const FLOAT_EPSILON = 0.0001;

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';

export class AliPlayerEntry {
  public playerId: string = '';
  public player: AliPlayer | null = null;
  public playerType: number = 0;
  public surfaceId: string = '';
  public isSurfaceReady: boolean = false;
  public currentState: number = 0; // 0=idle, 1=initalized, 2=prepared, 3=started, etc.
  public pendingVolume: number = 1.0;
  public pendingSpeed: number = 1.0;
  public pendingSeekPosition: number = -1;
  public pendingPlay: boolean = false;
  public pendingMute: boolean = false;
  public isAutoPlay: boolean = false;
  public isLoop: boolean = false;
  public isMuted: boolean = false;
  public pendingEnableHardDecoder: boolean = false;
  public hasPendingHardDecoder: boolean = false;
  public isAsyncReleasing: boolean = false;
  public lastSnapshotPath: string = '';

  // Callbacks for event forwarding
  public onStateChanged: ((state: number) => void) | null = null;
  public onPrepared: (() => void) | null = null;
  public onRenderingStart: (() => void) | null = null;
  public onCompletion: (() => void) | null = null;
  public onErrorHandler: ((errorCode: number, errorMsg: string, errorExtra: string) => void) | null = null;
  public onVideoSizeChanged: ((width: number, height: number) => void) | null = null;
  public onSeekComplete: (() => void) | null = null;
  public onLoadingBegin: (() => void) | null = null;
  public onLoadingProgress: ((percent: number, netSpeed: number) => void) | null = null;
  public onLoadingEnd: (() => void) | null = null;
  public onInfo: ((infoCode: number, extraValue: number, extraMsg: string) => void) | null = null;
  public onSnapShot: ((arrayBuffer: ArrayBuffer, width: number, height: number) => void) | null = null;
  public onSeiData: ((type: number, data: Uint8Array) => void) | null = null;
  public onStreamSwitchedSuccess: ((url: string) => void) | null = null;
  public onStreamSwitchedFail: ((url: string, errorCode: number, errorMsg: string) => void) | null = null;
  public onTrackChanged: ((trackInfo: Object) => void) | null = null;
  public onTrackReady: ((mediaInfo: MediaInfo | null) => void) | null = null;
  public onSubTrackReady: ((mediaInfo: MediaInfo | null) => void) | null = null;
  public onVideoRendered: ((timeMs: number, pts: number) => void) | null = null;
  public onSubtitleExtAdded: ((trackIndex: number, url: string) => void) | null = null;
  public onSubtitleShow: ((trackIndex: number, id: number, data: string) => void) | null = null;
  public onSubtitleHide: ((trackIndex: number, id: number) => void) | null = null;
  public onSubtitleHeader: ((trackIndex: number, header: string) => void) | null = null;

  private context: common.Context | null = null;

  constructor(context: common.Context, playerId: string) {
    this.context = context;
    this.playerId = playerId;
  }

  async createPlayer(playerType: number = 0): Promise<void> {
    if (this.context === null) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'createPlayer failed: context is null, playerId=%{public}s', this.playerId);
      return;
    }
    this.playerType = playerType;
    let player: AliPlayer;
    if (playerType === 1) {
      player = AliPlayerFactory.createAliListPlayer(this.context as common.Context);
    } else {
      player = AliPlayerFactory.createAliPlayer(this.context as common.Context);
    }
    this.player = player;
    this.setupListeners();
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'createPlayer success playerId=%{public}s', this.playerId);
  }

  private setupListeners(): void {
    if (this.player === null) {
      return;
    }

    this.player.setOnPreparedListener({
      onPrepared: (): void => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onPrepared playerId=%{public}s', this.playerId);
        this.currentState = 2; // prepared
        this.applyPendingConfig();
        if (this.onPrepared !== null) {
          this.onPrepared();
        }
      }
    });

    this.player.setOnRenderingStartListener({
      onRenderingStart: (): void => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onRenderingStart playerId=%{public}s', this.playerId);
        if (this.onRenderingStart !== null) {
          this.onRenderingStart();
        }
      }
    });

    this.player.setOnStateChangedListener({
      onStateChanged: (newState: number): void => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onStateChanged playerId=%{public}s newState=%{public}d',
          this.playerId, newState);
        this.currentState = newState;
        if (this.onStateChanged !== null) {
          this.onStateChanged(newState);
        }
      }
    });

    this.player.setOnCompletionListener({
      onCompletion: (): void => {
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'onCompletion playerId=%{public}s', this.playerId);
        if (this.onCompletion !== null) {
          this.onCompletion();
        }
      }
    });

    this.player.setOnLoadingStatusListener({
      onLoadingBegin: (): void => {
        if (this.onLoadingBegin !== null) {
          this.onLoadingBegin();
        }
      },
      onLoadingProgress: (percent: number, netSpeed: number): void => {
        if (this.onLoadingProgress !== null) {
          this.onLoadingProgress(percent, netSpeed);
        }
      },
      onLoadingEnd: (): void => {
        if (this.onLoadingEnd !== null) {
          this.onLoadingEnd();
        }
      }
    });

    this.player.setOnErrorListener({
      onError: (errorInfo: ErrorInfo): void => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'onError playerId=%{public}s code=%{public}d msg=%{public}s',
          this.playerId, errorInfo.getCode(), errorInfo.getMsg());
        if (this.onErrorHandler !== null) {
          this.onErrorHandler(errorInfo.getCode(), errorInfo.getMsg(), errorInfo.getExtra());
        }
      }
    });

    this.player.setOnInfoListener({
      onInfo: (infoBean: InfoBean): void => {
        if (this.onInfo !== null) {
          this.onInfo(infoBean.getCode(), infoBean.getExtraValue(), infoBean.getExtraMsg());
        }
      }
    });

    this.player.setOnVideoSizeChangedListener({
      onVideoSizeChanged: (width: number, height: number): void => {
        if (this.onVideoSizeChanged !== null) {
          this.onVideoSizeChanged(width, height);
        }
      }
    });

    this.player.setOnSeekCompleteListener({
      onSeekComplete: (): void => {
        if (this.onSeekComplete !== null) {
          this.onSeekComplete();
        }
      }
    });

    this.player.setOnSnapShotListener({
      onSnapShot: (arrayBuffer: ArrayBuffer, width: number, height: number): void => {
        if (this.onSnapShot !== null) {
          this.onSnapShot(arrayBuffer, width, height);
        }
      }
    });

    this.player.setOnSeiDataListener({
      onSeiData: (type: number, data: Uint8Array): void => {
        if (this.onSeiData !== null) {
          this.onSeiData(type, data);
        }
      }
    });

    this.player.setOnStreamSwitchedListener({
      onSwitchedSuccess: (url: string): void => {
        if (this.onStreamSwitchedSuccess !== null) {
          this.onStreamSwitchedSuccess(url);
        }
      },
      onSwitchedFail: (url: string, errorInfo: ErrorInfo): void => {
        if (this.onStreamSwitchedFail !== null) {
          this.onStreamSwitchedFail(url, errorInfo.getCode(), errorInfo.getMsg());
        }
      }
    });

    this.player.setOnTrackChangedListener({
      onChangedSuccess: (trackInfo: TrackInfo): void => {
        if (this.onTrackChanged !== null) {
          this.onTrackChanged(trackInfo);
        }
      }
    });

    this.player.setOnTrackReadyListener({
      onTrackReady: (mediaInfo: MediaInfo): void => {
        if (this.onTrackReady !== null) {
          this.onTrackReady(mediaInfo);
        }
      }
    });

    this.player.setOnSubTrackReadyListener({
      onSubTrackReady: (mediaInfo: MediaInfo): void => {
        if (this.onSubTrackReady !== null) {
          this.onSubTrackReady(mediaInfo);
        }
      }
    });

    this.player.setOnVideoRenderedListener({
      onVideoRendered: (timeMs: number, pts: number): void => {
        if (this.onVideoRendered !== null) {
          this.onVideoRendered(timeMs, pts);
        }
      }
    });

    this.player.setOnSubtitleDisplayListener({
      onSubtitleExtAdded: (trackIndex: number, url: string): void => {
        if (this.onSubtitleExtAdded !== null) {
          this.onSubtitleExtAdded(trackIndex, url);
        }
      },
      onSubtitleShow: (trackIndex: number, id: number, data: string): void => {
        if (this.onSubtitleShow !== null) {
          this.onSubtitleShow(trackIndex, id, data);
        }
      },
      onSubtitleHide: (trackIndex: number, id: number): void => {
        if (this.onSubtitleHide !== null) {
          this.onSubtitleHide(trackIndex, id);
        }
      },
      onSubtitleHeader: (trackIndex: number, header: string): void => {
        if (this.onSubtitleHeader !== null) {
          this.onSubtitleHeader(trackIndex, header);
        }
      }
    });
  }

  setUrlDataSource(url: string): void {
    if (this.player === null) {
      return;
    }
    const urlSource: UrlSource = new UrlSource();
    urlSource.setUri(url);
    this.player.setUrlDataSource(urlSource);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setUrlDataSource playerId=%{public}s url=%{public}s',
      this.playerId, url);
  }

  setVidStsDataSource(vid: string, region: string | null, accessKeyId: string | null,
    accessKeySecret: string | null, securityToken: string | null,
    playConfig: string | null, quality: string, forceQuality: boolean): void {
    if (this.player === null) {
      return;
    }
    const vidSts: VidSts = new VidSts();
    vidSts.setVid(vid);
    if (region !== null) {
      vidSts.setRegion(region);
    }
    if (accessKeyId !== null) {
      vidSts.setAccessKeyId(accessKeyId);
    }
    if (accessKeySecret !== null) {
      vidSts.setAccessKeySecret(accessKeySecret);
    }
    if (securityToken !== null) {
      vidSts.setSecurityToken(securityToken);
    }
    if (playConfig !== null && playConfig.length > 0) {
      const config: VidPlayerConfigGen = new VidPlayerConfigGen();
      vidSts.setPlayerConfig(config);
    }
    if (quality.length > 0) {
      vidSts.setQuality(quality, forceQuality);
    }
    this.player.setVidStsDataSource(vidSts);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setVidStsDataSource playerId=%{public}s vid=%{public}s',
      this.playerId, vid);
  }

  setVidAuthDataSource(vid: string, region: string | null, playAuth: string | null,
    playConfig: string | null, quality: string, forceQuality: boolean): void {
    if (this.player === null) {
      return;
    }
    const vidAuth: VidAuth = new VidAuth();
    vidAuth.setVid(vid);
    if (region !== null) {
      vidAuth.setRegion(region);
    }
    if (playAuth !== null) {
      vidAuth.setPlayAuth(playAuth);
    }
    if (playConfig !== null && playConfig.length > 0) {
      const config: VidPlayerConfigGen = new VidPlayerConfigGen();
      vidAuth.setPlayerConfig(config);
    }
    if (quality.length > 0) {
      vidAuth.setQuality(quality, forceQuality);
    }
    this.player.setVidAuthDataSource(vidAuth);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setVidAuthDataSource playerId=%{public}s vid=%{public}s',
      this.playerId, vid);
  }

  setVidMpsDataSource(mpsInfo: Map<string, Object>): void {
    if (this.player === null) {
      return;
    }
    const vidMps: VidMps = new VidMps();
    const vid: Object | undefined = mpsInfo.get('vid');
    if (vid !== undefined && vid !== null) {
      vidMps.setMediaId(vid as string);
    }
    const qualityVal: Object | undefined = mpsInfo.get('quality');
    if (qualityVal !== undefined && qualityVal !== null && (qualityVal as string).length > 0) {
      vidMps.setQuality(qualityVal as string, false);
    }
    this.player.setVidMpsDataSource(vidMps);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setVidMpsDataSource playerId=%{public}s', this.playerId);
  }

  setLiveStsDataSource(url: string | null, accessKeyId: string | null,
    accessKeySecret: string | null, securityToken: string | null,
    region: string | null, domain: string | null, app: string | null,
    stream: string | null): void {
    if (this.player === null) {
      return;
    }
    const liveSts: LiveSts = new LiveSts();
    if (url !== null) {
      liveSts.setUrl(url);
    }
    if (accessKeyId !== null) {
      liveSts.setAccessKeyId(accessKeyId);
    }
    if (accessKeySecret !== null) {
      liveSts.setAccessKeySecret(accessKeySecret);
    }
    if (securityToken !== null) {
      liveSts.setSecurityToken(securityToken);
    }
    if (region !== null) {
      liveSts.setRegion(region);
    }
    if (domain !== null) {
      liveSts.setDomain(domain);
    }
    if (app !== null) {
      liveSts.setApp(app);
    }
    if (stream !== null) {
      liveSts.setStream(stream);
    }
    this.player.setLiveStsDataSource(liveSts);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setLiveStsDataSource playerId=%{public}s', this.playerId);
  }

  setSurfaceId(surfaceId: string): void {
    if (this.player === null) {
      return;
    }
    this.surfaceId = surfaceId;
    this.isSurfaceReady = true;
    this.player.setSurfaceId(surfaceId);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'setSurfaceId playerId=%{public}s surfaceId=%{public}s',
      this.playerId, surfaceId);
  }

  prepare(): void {
    if (this.player === null) {
      return;
    }
    if (this.isAutoPlay) {
      this.pendingPlay = true;
    }
    if (this.hasPendingHardDecoder) {
      this.player.enableHardwareDecoder(this.pendingEnableHardDecoder);
    }
    this.player.prepare();
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'prepare playerId=%{public}s', this.playerId);
  }

  play(): void {
    if (this.player === null) {
      return;
    }
    if (this.currentState === STATE_PREPARED || this.currentState === STATE_PAUSED || this.currentState === STATE_STOPPED) {
      this.player.start();
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'play playerId=%{public}s', this.playerId);
    } else {
      this.pendingPlay = true;
    }
  }

  pause(): void {
    if (this.player === null) {
      return;
    }
    this.pendingPlay = false;
    this.player.pause();
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'pause playerId=%{public}s', this.playerId);
  }

  requestSnapshot(path: string): void {
    this.lastSnapshotPath = path;
    if (this.player === null) {
      return;
    }
    this.player.snapShot();
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'snapshot playerId=%{public}s path=%{public}s', this.playerId, path);
  }

  stop(): void {
    if (this.player === null) {
      return;
    }
    this.pendingPlay = false;
    this.player.stop();
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'stop playerId=%{public}s', this.playerId);
  }

  seekTo(position: number, mode: number): void {
    if (this.player === null) {
      return;
    }
    if (this.currentState === STATE_PREPARED || this.currentState === STATE_STARTED ||
      this.currentState === STATE_PAUSED || this.currentState === STATE_STOPPED) {
      this.player.seekTo(position, mode);
    } else {
      this.pendingSeekPosition = position;
    }
  }

  setVolume(volume: number): void {
    this.pendingVolume = volume;
    if (this.player !== null && (this.currentState === STATE_PREPARED || this.currentState === STATE_STARTED ||
      this.currentState === STATE_PAUSED || this.currentState === STATE_STOPPED)) {
      this.player.setVolume(volume);
    }
  }

  setSpeed(speed: number): void {
    this.pendingSpeed = speed;
    if (this.player !== null && (this.currentState === STATE_PREPARED || this.currentState === STATE_STARTED ||
      this.currentState === STATE_PAUSED || this.currentState === STATE_STOPPED)) {
      this.player.setSpeed(speed);
    }
  }

  setMute(mute: boolean): void {
    this.pendingMute = mute;
    this.isMuted = mute;
    if (this.player !== null) {
      this.player.setMute(mute);
    }
  }

  setLoop(loop: boolean): void {
    this.isLoop = loop;
    if (this.player !== null) {
      this.player.setLoop(loop);
    }
  }

  setAutoPlay(autoPlay: boolean): void {
    this.isAutoPlay = autoPlay;
    if (this.player !== null) {
      this.player.setAutoPlay(autoPlay);
    }
  }

  enableHardwareDecoder(enabled: boolean): void {
    this.hasPendingHardDecoder = true;
    this.pendingEnableHardDecoder = enabled;
    if (this.player !== null) {
      this.player.enableHardwareDecoder(enabled);
    }
  }

  // Apply pending config that was set before prepared
  private applyPendingConfig(): void {
    if (this.player === null) {
      return;
    }
    if (Math.abs(this.pendingVolume - 1.0) > FLOAT_EPSILON) {
      this.player.setVolume(this.pendingVolume);
    }
    if (Math.abs(this.pendingSpeed - 1.0) > FLOAT_EPSILON) {
      this.player.setSpeed(this.pendingSpeed);
    }
    if (this.pendingMute) {
      this.player.setMute(true);
    }
    if (this.pendingSeekPosition >= 0) {
      this.player.seekTo(this.pendingSeekPosition, 1);
      this.pendingSeekPosition = -1;
    }
    if (this.pendingPlay) {
      this.player.start();
      this.pendingPlay = false;
    }
  }

  destroy(): void {
    if (this.player === null) {
      return;
    }
    try {
      this.player.release();
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'release error playerId=%{public}s error=%{public}s',
        this.playerId, (error as Error).message);
    }
    this.player = null;
    this.isSurfaceReady = false;
    this.surfaceId = '';
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'destroy playerId=%{public}s', this.playerId);
  }

  releaseAsync(): void {
    if (this.player === null) {
      return;
    }
    this.isAsyncReleasing = true;
    try {
      this.player.releaseAsync();
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'releaseAsync error playerId=%{public}s error=%{public}s',
        this.playerId, (error as Error).message);
    }
    this.player = null;
    this.isSurfaceReady = false;
    this.surfaceId = '';
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'releaseAsync playerId=%{public}s', this.playerId);
  }
}
