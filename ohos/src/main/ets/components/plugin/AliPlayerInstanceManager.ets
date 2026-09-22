/**
 * 播放器实例管理器
 * 
 * 负责创建、管理、销毁多个播放器实例（单播放器、列表播放器、直播时移播放器）
 */

import {
  BinaryMessenger,
  EventSink,
  BasicMessageChannel,
  StringCodec,
} from '@ohos/flutter_ohos';

import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AliPlayerInstance } from './AliPlayerInstance';
import { AliListPlayerInstance } from './AliListPlayerInstance';
import { AliLiveShiftPlayerInstance } from './AliLiveShiftPlayerInstance';
import { IPlayerInstance } from './IPlayerInstance';

import { SurfaceCallback } from './AliPlayerPlatformView';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliPlayerInstanceManager';

type PlayerInstance = AliPlayerInstance | AliListPlayerInstance | AliLiveShiftPlayerInstance;

interface PlayerInfo {
  instance: PlayerInstance;
  type: string;
}

export class AliPlayerInstanceManager implements SurfaceCallback {
  private messenger: BinaryMessenger;
  private context: common.Context;
  private playerInstances: Map<string, PlayerInfo> = new Map();
  private viewBinding: Map<number, string> = new Map();
  private cachedSurfaceIds: Map<number, string> = new Map();
  private eventSink: EventSink | null = null;

  constructor(messenger: BinaryMessenger, context: common.Context) {
    this.messenger = messenger;
    this.context = context;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliPlayerInstanceManager created');
  }

  onSurfaceReady(viewId: number, surfaceId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onSurfaceReady: viewId=%{public}d surfaceId=%{public}s', viewId, surfaceId);
    
    this.cachedSurfaceIds.set(viewId, surfaceId);
    
    const playerId = this.viewBinding.get(viewId);
    if (playerId === undefined) {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Surface cached, waiting for player binding: viewId=%{public}d', viewId);
      return;
    }
    
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo !== undefined) {
      playerInfo.instance.setSurfaceId(surfaceId);
    }
  }

  onSurfaceDestroyed(viewId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onSurfaceDestroyed: viewId=%{public}d', viewId);
    
    this.cachedSurfaceIds.delete(viewId);
    
    const playerId = this.viewBinding.get(viewId);
    if (playerId === undefined) {
      return;
    }
    
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo !== undefined) {
      playerInfo.instance.clearSurfaceId();
    }
  }

  setEventSink(sink: EventSink | null): void {
    this.eventSink = sink;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'EventSink set: %{public}s', sink !== null ? 'valid' : 'null');
    
    if (sink !== null) {
      this.playerInstances.forEach((playerInfo: PlayerInfo, playerId: string) => {
        playerInfo.instance.setEventSink(sink);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'EventSink set for player: %{public}s', playerId);
      });
    }
  }

  createPlayer(playerId: string, type: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'createPlayer playerId=%{public}s type=%{public}s', playerId, type);
    
    if (this.playerInstances.has(playerId)) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player already exists: %{public}s', playerId);
      return;
    }
    
    let instance: PlayerInstance;
    
    if (type === 'list') {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Creating list player: %{public}s', playerId);
      instance = new AliListPlayerInstance(playerId);
    } else if (type === 'liveShift') {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Creating live shift player: %{public}s', playerId);
      instance = new AliLiveShiftPlayerInstance(playerId);
    } else {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Creating single player: %{public}s', playerId);
      instance = new AliPlayerInstance(playerId);
    }
    
    instance.setContext(this.context);
    
    if (this.eventSink !== null) {
      instance.setEventSink(this.eventSink);
    }
    
    this.playerInstances.set(playerId, { instance: instance, type: type });
    instance.init();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Player created: %{public}s type=%{public}s', playerId, type);
  }

  getPlayer(playerId: string): AliPlayerInstance | null {
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player not found: %{public}s', playerId);
      return null;
    }
    if (playerInfo.type === 'single' || playerInfo.type === '') {
      return playerInfo.instance as AliPlayerInstance;
    }
    return null;
  }

  getListPlayer(playerId: string): AliListPlayerInstance | null {
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'List player not found: %{public}s', playerId);
      return null;
    }
    if (playerInfo.type === 'list') {
      return playerInfo.instance as AliListPlayerInstance;
    }
    return null;
  }

  getLiveShiftPlayer(playerId: string): AliLiveShiftPlayerInstance | null {
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Live shift player not found: %{public}s', playerId);
      return null;
    }
    if (playerInfo.type === 'liveShift') {
      return playerInfo.instance as AliLiveShiftPlayerInstance;
    }
    return null;
  }

  getPlayerInstance(playerId: string): IPlayerInstance | null {
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player instance not found: %{public}s', playerId);
      return null;
    }
    return playerInfo.instance as IPlayerInstance;
  }

  getPlayerType(playerId: string): string {
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo === undefined) {
      return '';
    }
    return playerInfo.type;
  }

  destroyPlayer(playerId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'destroyPlayer playerId=%{public}s', playerId);
    this.removePlayer(playerId, false);
  }

  destroyPlayerAsync(playerId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'destroyPlayerAsync playerId=%{public}s', playerId);
    this.removePlayer(playerId, true);
  }

  private removePlayer(playerId: string, useAsync: boolean): void {
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo !== undefined) {
      if (useAsync) {
        playerInfo.instance.releaseAsync();
      } else {
        playerInfo.instance.release();
      }
      this.playerInstances.delete(playerId);
      
      const viewBindingEntries = Array.from(this.viewBinding.entries());
      for (const entry of viewBindingEntries) {
        const viewId = entry[0];
        const pid = entry[1];
        if (pid === playerId) {
          this.viewBinding.delete(viewId);
          break;
        }
      }
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Player destroyed: %{public}s', playerId);
    }
  }

  bindPlayerView(playerId: string, viewId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'bindPlayerView playerId=%{public}s viewId=%{public}d', playerId, viewId);
    
    const playerInfo = this.playerInstances.get(playerId);
    if (playerInfo !== undefined) {
      this.viewBinding.set(viewId, playerId);
      
      const cachedSurfaceId = this.cachedSurfaceIds.get(viewId);
      if (cachedSurfaceId !== undefined) {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'Applying cached surfaceId: %{public}s', cachedSurfaceId);
        playerInfo.instance.setSurfaceId(cachedSurfaceId);
      }
    } else {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player not found for binding: %{public}s', playerId);
    }
  }

  unbindPlayerView(viewId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'unbindPlayerView viewId=%{public}d', viewId);
    
    const playerId = this.viewBinding.get(viewId);
    if (playerId !== undefined) {
      this.viewBinding.delete(viewId);
    }
  }

  getPlayerIdByViewId(viewId: number): string | null {
    const playerId = this.viewBinding.get(viewId);
    return playerId !== undefined ? playerId : null;
  }

  releaseAll(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'releaseAll');
    
    const playerEntries = Array.from(this.playerInstances.entries());
    for (const entry of playerEntries) {
      const playerId = entry[0];
      const playerInfo = entry[1];
      playerInfo.instance.release();
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'Released player: %{public}s', playerId);
    }
    
    this.playerInstances.clear();
    this.viewBinding.clear();
    this.eventSink = null;
  }

  reloadAll(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'reloadAll');
    
    const playerEntries = Array.from(this.playerInstances.entries());
    for (const entry of playerEntries) {
      const playerId = entry[0];
      const playerInfo = entry[1];
      playerInfo.instance.reload();
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'Reloaded player: %{public}s', playerId);
    }
  }

  sendEvent(eventData: Map<string, Object>): void {
    if (this.eventSink !== null) {
      this.eventSink.success(eventData);
    }
  }
}