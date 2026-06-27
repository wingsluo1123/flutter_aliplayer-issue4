import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  MediaLoader, VodMediaLoader, OnLoadStatusListener, OnVodLoadStatusListener
} from 'premierlibrary';
import { MethodResult, EventSink } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';

export class MediaLoaderHandler {
  private mediaLoaderV1: MediaLoader | null = null;
  private mediaLoaderV2: VodMediaLoader | null = null;
  private mediaLoaderEventSink: EventSink | null = null;
  private loaderV2EventSink: EventSink | null = null;
  private context: common.Context | null = null;

  constructor(context: common.Context | null) {
    this.context = context;
  }

  setMediaLoaderEventSink(sink: EventSink | null): void {
    this.mediaLoaderEventSink = sink;
  }

  setLoaderV2EventSink(sink: EventSink | null): void {
    this.loaderV2EventSink = sink;
  }

  // Handle methods from plugins.flutter_aliplayer_media_loader (V1)
  handleMediaLoaderMethod(method: string, args: Map<string, Object> | null, result: MethodResult): void {
    switch (method) {
      case 'load':
        this.handleV1Load(args, result);
        break;
      case 'resume':
        this.handleV1Resume(args, result);
        break;
      case 'pause':
        this.handleV1Pause(args, result);
        break;
      case 'cancel':
        this.handleV1Cancel(args, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  // Handle methods from plugins.flutter_aliplayer_loader_v2 (V2)
  handleLoaderV2Method(method: string, args: Map<string, Object> | null, result: MethodResult): void {
    switch (method) {
      case 'addTask':
        this.handleV2AddTask(args, result);
        break;
      case 'getPreloadConfig':
        this.handleV2GetPreloadConfig(result);
        break;
      case 'setPreloadConfig':
        this.handleV2SetPreloadConfig(args, result);
        break;
      case 'resetPreloadConfig':
        this.handleV2ResetPreloadConfig(result);
        break;
      case 'pauseTask':
        this.handleV2PauseTask(args, result);
        break;
      case 'resumeTask':
        this.handleV2ResumeTask(args, result);
        break;
      case 'cancelTask':
        this.handleV2CancelTask(args, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private ensureMediaLoader(): MediaLoader | null {
    if (this.mediaLoaderV1 === null && this.context !== null) {
      this.mediaLoaderV1 = new MediaLoader();
      this.setupV1Listeners();
    }
    return this.mediaLoaderV1;
  }

  private ensureVodMediaLoader(): VodMediaLoader | null {
    if (this.mediaLoaderV2 === null && this.context !== null) {
      this.mediaLoaderV2 = VodMediaLoader.getInstance();
      this.setupV2Listeners();
    }
    return this.mediaLoaderV2;
  }

  private setupV1Listeners(): void {
    if (this.mediaLoaderV1 === null) {
      return;
    }
    this.mediaLoaderV1.setOnLoadStatusListener({
      onCompleted: (url: string): void => {
        const event: Map<string, Object> = new Map();
        event.set('url', url);
        this.mediaLoaderEventSink?.success(event);
      },
      onError: (url: string, code: number, msg: string): void => {
        const event: Map<string, Object> = new Map();
        event.set('url', url);
        event.set('code', code.toString());
        event.set('msg', msg);
        this.mediaLoaderEventSink?.success(event);
      },
      onCancel: (url: string): void => {
        const event: Map<string, Object> = new Map();
        event.set('url', url);
        this.mediaLoaderEventSink?.success(event);
      }
    } as OnLoadStatusListener);
  }

  private setupV2Listeners(): void {
    if (this.mediaLoaderV2 === null) {
      return;
    }
    this.mediaLoaderV2.setOnLoadStatusListener({
      onCompleted: (vid: string, index: number): void => {
        const event: Map<string, Object> = new Map();
        event.set('taskId', vid);
        event.set('urlOrVid', index.toString());
        this.loaderV2EventSink?.success(event);
      },
      onError: (vid: string, index: number, errorCode: number, errorMsg: string): void => {
        const event: Map<string, Object> = new Map();
        event.set('taskId', vid);
        event.set('urlOrVid', index.toString());
        event.set('errorCode', errorCode.toString());
        event.set('errorMsg', errorMsg);
        this.loaderV2EventSink?.success(event);
      },
      onCanceled: (vid: string, index: number): void => {
        const event: Map<string, Object> = new Map();
        event.set('taskId', vid);
        event.set('urlOrVid', index.toString());
        this.loaderV2EventSink?.success(event);
      }
    } as OnVodLoadStatusListener);
  }

  private handleV1Load(args: Map<string, Object> | null, result: MethodResult): void {
    const loader: MediaLoader | null = this.ensureMediaLoader();
    if (loader === null) {
      result.error('ERROR', 'MediaLoader init failed', null);
      return;
    }
    const url: string = args?.get('url') as string;
    const duration: string = args?.get('duration') as string;
    loader.load(url, Number.parseInt(duration));
    result.success(null);
  }

  private handleV1Resume(args: Map<string, Object> | null, result: MethodResult): void {
    const loader: MediaLoader | null = this.ensureMediaLoader();
    if (loader === null) {
      result.error('ERROR', 'MediaLoader init failed', null);
      return;
    }
    const url: string = args?.get('url') as string;
    loader.resume(url);
    result.success(null);
  }

  private handleV1Pause(args: Map<string, Object> | null, result: MethodResult): void {
    const loader: MediaLoader | null = this.ensureMediaLoader();
    if (loader === null) {
      result.error('ERROR', 'MediaLoader init failed', null);
      return;
    }
    const url: string = args?.get('url') as string;
    loader.pause(url);
    result.success(null);
  }

  private handleV1Cancel(args: Map<string, Object> | null, result: MethodResult): void {
    const loader: MediaLoader | null = this.ensureMediaLoader();
    if (loader === null) {
      result.error('ERROR', 'MediaLoader init failed', null);
      return;
    }
    const url: string = args?.get('url') as string;
    loader.cancel(url);
    result.success(null);
  }

  private handleV2AddTask(args: Map<string, Object> | null, result: MethodResult): void {
    const loader: VodMediaLoader | null = this.ensureVodMediaLoader();
    if (loader === null) {
      result.error('ERROR', 'VodMediaLoader init failed', null);
      return;
    }
    // addTask returns taskId
    const taskId: string = 'task_' + Date.now().toString();
    result.success(taskId);
  }

  private handleV2GetPreloadConfig(result: MethodResult): void {
    const config: Map<string, Object> = new Map();
    config.set('preloadStrategy', 'default');
    result.success(config);
  }

  private handleV2SetPreloadConfig(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }

  private handleV2ResetPreloadConfig(result: MethodResult): void {
    result.success(null);
  }

  private handleV2PauseTask(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }

  private handleV2ResumeTask(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }

  private handleV2CancelTask(args: Map<string, Object> | null, result: MethodResult): void {
    result.success(null);
  }

  releaseAll(): void {
    if (this.mediaLoaderV1 !== null) {
      this.mediaLoaderV1 = null;
    }
    if (this.mediaLoaderV2 !== null) {
      this.mediaLoaderV2 = null;
    }
    this.mediaLoaderEventSink = null;
    this.loaderV2EventSink = null;
  }
}
