import { hilog } from '@kit.PerformanceAnalysisKit';
import { avSession } from '@kit.AVSessionKit';
import common from '@ohos.app.ability.common';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliplayerAVSession';

export interface AVSessionCommandCallback {
  onPlay: () => void;
  onPause: () => void;
  onStop: () => void;
  onSeek: (position: number) => void;
  onSetSpeed: (speed: number) => void;
  onSetLoopMode: (loopMode: number) => void;
}

export class AliPlayerAVSession {
  private session: avSession.AVSession | null = null;
  private context: common.UIAbilityContext | null = null;
  private callback: AVSessionCommandCallback | null = null;
  private isActive: boolean = false;

  constructor(context: common.UIAbilityContext | null) {
    this.context = context;
  }

  setCommandCallback(callback: AVSessionCommandCallback): void {
    this.callback = callback;
  }

  async createSession(tag: string): Promise<void> {
    if (this.context === null) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'createSession skipped - no UIAbilityContext');
      return;
    }
    try {
      this.session = await avSession.createAVSession(this.context, tag, 'audio');
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'createAVSession success');
      this.registerCommands();
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'createAVSession error=%{public}s', (error as Error).message);
    }
  }

  private registerCommands(): void {
    if (this.session === null) {
      return;
    }

    this.session.on('play', () => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession play command');
      if (this.callback !== null) {
        this.callback.onPlay();
      }
    });

    this.session.on('pause', () => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession pause command');
      if (this.callback !== null) {
        this.callback.onPause();
      }
    });

    this.session.on('stop', () => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession stop command');
      if (this.callback !== null) {
        this.callback.onStop();
      }
    });

    this.session.on('seek', (time: number) => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession seek command time=%{public}d', time);
      if (this.callback !== null) {
        this.callback.onSeek(time);
      }
    });

    this.session.on('setSpeed', (speed: number) => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession setSpeed command speed=%{public}f', speed);
      if (this.callback !== null) {
        this.callback.onSetSpeed(speed);
      }
    });

    this.session.on('setLoopMode', (loopMode: number) => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession setLoopMode command loopMode=%{public}d', loopMode);
      if (this.callback !== null) {
        this.callback.onSetLoopMode(loopMode);
      }
    });
  }

  async activate(): Promise<void> {
    if (this.session === null || this.isActive) {
      return;
    }
    try {
      await this.session.activate();
      this.isActive = true;
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession activated');
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'AVSession activate error=%{public}s', (error as Error).message);
    }
  }

  async deactivate(): Promise<void> {
    if (this.session === null || !this.isActive) {
      return;
    }
    try {
      await this.session.deactivate();
      this.isActive = false;
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession deactivated');
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'AVSession deactivate error=%{public}s', (error as Error).message);
    }
  }

  async setMetaData(title: string, artist: string, mediaImage: string): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      const metadata: avSession.AVMetadata = {
        title: title,
        artist: artist,
        description: '',
        mediaImage: mediaImage,
        assetId: ''
      };
      await this.session.setAVMetadata(metadata);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'setAVMetadata error=%{public}s', (error as Error).message);
    }
  }

  async setPlaybackState(state: number, position: number): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      const playState: avSession.AVPlaybackState = {
        state: state as avSession.PlaybackState,
        position: { elapsedTime: position, updateTime: Date.now() }
      };
      await this.session.setAVPlaybackState(playState);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'setAVPlaybackState error=%{public}s', (error as Error).message);
    }
  }

  destroy(): void {
    if (this.session !== null) {
      try {
        this.session.destroy();
      } catch (error) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'AVSession destroy error=%{public}s', (error as Error).message);
      }
      this.session = null;
    }
    this.isActive = false;
    this.callback = null;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'AVSession destroyed');
  }
}
