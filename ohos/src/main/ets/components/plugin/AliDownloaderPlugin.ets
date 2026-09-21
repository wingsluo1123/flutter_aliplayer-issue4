/**
 * 视频下载器插件
 */

import {
  BinaryMessenger,
  MethodChannel,
  MethodCall,
  MethodCallHandler,
  MethodResult,
  EventChannel,
  EventSink,
  StreamHandler,
} from '@ohos/flutter_ohos';

import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliDownloaderPlugin';

export class AliDownloaderPlugin implements MethodCallHandler, StreamHandler {
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private messenger: BinaryMessenger;
  private context: common.Context;
  private saveDir: string = '';

  constructor(messenger: BinaryMessenger, context: common.Context) {
    this.messenger = messenger;
    this.context = context;
    
    this.channel = new MethodChannel(messenger, 'plugins.flutter_alidownload');
    this.channel.setMethodCallHandler(this);
    
    this.eventChannel = new EventChannel(messenger, 'plugins.flutter_alidownload_event');
    this.eventChannel.setStreamHandler(this);
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliDownloaderPlugin created');
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Downloader onMethodCall: %{public}s', call.method);
    
    switch (call.method) {
      case 'prepare':
        this.prepareDownload(call.args as Map<string, Object>, result);
        break;
      case 'setSaveDir':
        this.setSaveDir(call.args, result);
        break;
      case 'selectItem':
        result.notImplemented();
        break;
      case 'start':
        this.startDownload(call.args as Map<string, Object>, result);
        break;
      case 'stop':
        this.stopDownload(call.args as Map<string, Object>, result);
        break;
      case 'delete':
        this.deleteDownload(call.args as Map<string, Object>, result);
        break;
      case 'release':
        this.releaseDownloader(call.args as Map<string, Object>, result);
        break;
      case 'getFilePath':
        result.notImplemented();
        break;
      case 'updateSource':
        result.notImplemented();
        break;
      case 'setDownloaderConfig':
        result.notImplemented();
        break;
      case 'getFullSaveDir':
        if (call.args !== null) {
          result.success(call.args as string);
        } else {
          result.error('INVALID_ARGS', 'Arguments required', null);
        }
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private prepareDownload(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const type = (args.get('type') as Object) as string;
    const vid = (args.get('vid') as Object) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'prepareDownload: type=%{public}s vid=%{public}s', type, vid);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Note: Download requires Alibaba Cloud VOD account and STS credentials');
    
    result.success(null);
  }

  private setSaveDir(args: Object | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    this.saveDir = args as string;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setSaveDir: %{public}s', this.saveDir);
    result.success(null);
  }

  private startDownload(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    const vid = (args.get('vid') as Object) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'startDownload: vid=%{public}s', vid);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Note: Requires Alibaba Cloud VOD account');
    
    result.success(null);
  }

  private stopDownload(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    const vid = (args.get('vid') as Object) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'stopDownload: vid=%{public}s', vid);
    result.success(null);
  }

  private deleteDownload(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    const vid = (args.get('vid') as Object) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'deleteDownload: vid=%{public}s', vid);
    result.success(null);
  }

  private releaseDownloader(args: Map<string, Object> | null, result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'releaseDownloader');
    result.success(null);
  }

  onListen(args: Object, events: EventSink): void {
    this.eventSink = events;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Downloader EventChannel onListen');
  }

  onCancel(args: Object): void {
    this.eventSink = null;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Downloader EventChannel onCancel');
  }

  release(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliDownloaderPlugin release');
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    if (this.eventChannel !== null) {
      this.eventChannel.setStreamHandler(null);
      this.eventChannel = null;
    }
    this.eventSink = null;
  }
}