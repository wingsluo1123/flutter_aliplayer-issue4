import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';

type SurfaceReadyCallback = ((playerId: number, surfaceId: string) => void) | null;

export class VideoViewRegistry {
  private static views: Map<number, Object> = new Map();
  private static surfaceCallback: SurfaceReadyCallback = null;
  public static latestPlayerId: number = -1;
  private static pendingSurfaceIds: Map<number, string> = new Map();

  static setLatestPlayerId(pid: number): void {
    VideoViewRegistry.latestPlayerId = pid;
  }

  static setSurfaceCallback(cb: SurfaceReadyCallback): void {
    VideoViewRegistry.surfaceCallback = cb;
  }

  static register(playerId: number, view: Object): void {
    VideoViewRegistry.views.set(playerId, view);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Registry register playerId=%{public}d', playerId);
  }

  static unregister(playerId: number): void {
    VideoViewRegistry.views.delete(playerId);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Registry unregister playerId=%{public}d', playerId);
  }

  static getView(playerId: number): Object | undefined {
    return VideoViewRegistry.views.get(playerId);
  }

  static onSurfaceReady(playerId: number, surfaceId: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Registry onSurfaceReady playerId=%{public}d surfaceId=%{public}s',
      playerId, surfaceId);
    VideoViewRegistry.pendingSurfaceIds.set(playerId, surfaceId);
    if (VideoViewRegistry.surfaceCallback !== null) {
      VideoViewRegistry.surfaceCallback(playerId, surfaceId);
    }
  }

  static getPendingSurfaceId(playerId: number): string | undefined {
    return VideoViewRegistry.pendingSurfaceIds.get(playerId);
  }

  static removePendingSurfaceId(playerId: number): void {
    VideoViewRegistry.pendingSurfaceIds.delete(playerId);
  }

  static clear(): void {
    VideoViewRegistry.views.clear();
    VideoViewRegistry.surfaceCallback = null;
    VideoViewRegistry.latestPlayerId = -1;
  }
}
