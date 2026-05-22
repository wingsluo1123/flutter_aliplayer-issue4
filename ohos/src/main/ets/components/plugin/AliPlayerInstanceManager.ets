/**
 * 播放器实例管理器
 * 
 * 贌责创建、管理、销毁多个播放器实例（单播放器、列表播放器、直播时移播放器）
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

import { SurfaceCallback } from './AliPlayerPlatformView';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliPlayerInstanceManager';

/**
 * 播放器实例管理器 - 实现 SurfaceCallback 接口
 */
export class AliPlayerInstanceManager implements SurfaceCallback {
  // BinaryMessenger（用于创建实例级 Channel）
  private messenger: BinaryMessenger;
  
  // ApplicationContext
  private context: common.Context;
  
  // 播放器实例映射表（playerId -> AliPlayerInstance）
  private playerInstances: Map<string, AliPlayerInstance> = new Map();
  
  // PlatformView 绑定映射表（viewId -> playerId）
  private viewBinding: Map<number, string> = new Map();
  
  // 缓存的 surfaceId（viewId -> surfaceId），用于处理 surface 先于 player 创建的情况
  private cachedSurfaceIds: Map<number, string> = new Map();
  
  // EventSink（播放事件流）
  private eventSink: EventSink | null = null;

  constructor(messenger: BinaryMessenger, context: common.Context) {
    this.messenger = messenger;
    this.context = context;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliPlayerInstanceManager created');
  }

  /**
    * SurfaceCallback 实现 - surface 创建
    */
  onSurfaceReady(viewId: number, surfaceId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onSurfaceReady: viewId=%{public}d surfaceId=%{public}s', viewId, surfaceId);
    
    this.cachedSurfaceIds.set(viewId, surfaceId);
    
    const playerId = this.viewBinding.get(viewId);
    if (playerId === undefined) {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Surface cached, waiting for player binding: viewId=%{public}d', viewId);
      return;
    }
    
    const instance = this.playerInstances.get(playerId);
    if (instance !== undefined) {
      instance.setSurfaceId(surfaceId);
    }
  }

  onSurfaceDestroyed(viewId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onSurfaceDestroyed: viewId=%{public}d', viewId);
    
    this.cachedSurfaceIds.delete(viewId);
    
    const playerId = this.viewBinding.get(viewId);
    if (playerId === undefined) {
      return;
    }
    
    const instance = this.playerInstances.get(playerId);
    if (instance !== undefined) {
      instance.clearSurfaceId();
    }
  }

  /**
   * 设置 EventSink
   */
  setEventSink(sink: EventSink | null): void {
    this.eventSink = sink;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'EventSink set: %{public}s', sink !== null ? 'valid' : 'null');
    
    if (sink !== null) {
      this.playerInstances.forEach((instance: AliPlayerInstance, playerId: string) => {
        instance.setEventSink(sink);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'EventSink set for player: %{public}s', playerId);
      });
    }
  }

  /**
   * 创建播放器实例
   */
  createPlayer(playerId: string, type: string): void {
    console.info('[AliPlayerInstanceManager] createPlayer START playerId=' + playerId + ' type=' + type);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'createPlayer playerId=%{public}s type=%{public}s', playerId, type);
    
    if (this.playerInstances.has(playerId)) {
      console.warn('[AliPlayerInstanceManager] Player already exists: ' + playerId);
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player already exists: %{public}s', playerId);
      return;
    }
    
    if (this.context === null) {
      console.error('[AliPlayerInstanceManager] context is null!');
      hilog.error(LOG_DOMAIN, LOG_TAG, 'context is null');
      return;
    }
    
    console.info('[AliPlayerInstanceManager] Creating AliPlayerInstance...');
    const instance = new AliPlayerInstance(playerId);
    console.info('[AliPlayerInstanceManager] Setting context...');
    instance.setContext(this.context);
    
    if (this.eventSink !== null) {
      console.info('[AliPlayerInstanceManager] Setting eventSink...');
      instance.setEventSink(this.eventSink);
    }
    
    console.info('[AliPlayerInstanceManager] Adding to playerInstances map...');
    this.playerInstances.set(playerId, instance);
    
    console.info('[AliPlayerInstanceManager] Calling init()...');
    instance.init();
    console.info('[AliPlayerInstanceManager] init() completed');
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Player created: %{public}s', playerId);
  }

  /**
   * 获取播放器实例
   */
  getPlayer(playerId: string): AliPlayerInstance | null {
    if (!this.playerInstances.has(playerId)) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player not found: %{public}s', playerId);
      return null;
    }
    const instance = this.playerInstances.get(playerId);
    return instance !== undefined ? instance : null;
  }

  /**
   * 销毁播放器实例
   */
  destroyPlayer(playerId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'destroyPlayer playerId=%{public}s', playerId);
    
    const instance = this.playerInstances.get(playerId);
    if (instance !== undefined) {
      instance.release();
      this.playerInstances.delete(playerId);
      
      // 清理视图绑定
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

  /**
   * 绑定 PlatformView 到播放器
   */
  bindPlayerView(playerId: string, viewId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'bindPlayerView playerId=%{public}s viewId=%{public}d', playerId, viewId);
    
    const instance = this.playerInstances.get(playerId);
    if (instance !== undefined) {
      this.viewBinding.set(viewId, playerId);
      instance.setViewId(viewId);
      
      const cachedSurfaceId = this.cachedSurfaceIds.get(viewId);
      if (cachedSurfaceId !== undefined) {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'Applying cached surfaceId: %{public}s', cachedSurfaceId);
        instance.setSurfaceId(cachedSurfaceId);
      }
    } else {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Player not found for binding: %{public}s', playerId);
    }
  }

  /**
   * 解绑 PlatformView
   */
  unbindPlayerView(viewId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'unbindPlayerView viewId=%{public}d', viewId);
    
    const playerId = this.viewBinding.get(viewId);
    if (playerId !== undefined) {
      const instance = this.playerInstances.get(playerId);
      if (instance !== undefined) {
        instance.clearViewId();
      }
      this.viewBinding.delete(viewId);
    }
  }

  /**
   * 获取绑定到 View 的播放器 ID
   */
  getPlayerIdByViewId(viewId: number): string | null {
    const playerId = this.viewBinding.get(viewId);
    return playerId !== undefined ? playerId : null;
  }

  /**
   * 释放所有播放器实例
   */
  releaseAll(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'releaseAll');
    
    const playerEntries = Array.from(this.playerInstances.entries());
    for (const entry of playerEntries) {
      const playerId = entry[0];
      const instance = entry[1];
      instance.release();
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'Released player: %{public}s', playerId);
    }
    
    this.playerInstances.clear();
    this.viewBinding.clear();
    this.eventSink = null;
  }

  /**
   * 发送播放事件到 Flutter
   */
  sendEvent(eventData: Map<string, Object>): void {
    if (this.eventSink !== null) {
      this.eventSink.success(eventData);
    }
  }
}