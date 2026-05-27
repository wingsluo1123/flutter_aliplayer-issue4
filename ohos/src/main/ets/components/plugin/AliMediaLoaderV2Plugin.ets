/**
 * 媒体预加载 V2 插件
 * 
 * 注意：premierlibrary 未导出 MediaLoaderV2、PreloadTask 等类
 * 此插件为占位实现
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
const LOG_TAG: string = 'AliMediaLoaderV2Plugin';

export class AliMediaLoaderV2Plugin implements MethodCallHandler, StreamHandler {
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private messenger: BinaryMessenger;
  private context: common.Context;

  constructor(messenger: BinaryMessenger, context: common.Context) {
    this.messenger = messenger;
    this.context = context;
    
    this.channel = new MethodChannel(messenger, 'plugins.flutter_aliplayer_loader_v2');
    this.channel.setMethodCallHandler(this);
    
    this.eventChannel = new EventChannel(messenger, 'flutter_aliplayer_loader_v2_event');
    this.eventChannel.setStreamHandler(this);
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliMediaLoaderV2Plugin created');
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'MediaLoaderV2 onMethodCall: %{public}s', call.method);
    
    switch (call.method) {
      case 'addTask':
        hilog.info(LOG_DOMAIN, LOG_TAG, 'addTask: SDK未导出MediaLoaderV2相关API');
        result.success('stub_task_id');
        break;
      case 'pauseTask':
        hilog.info(LOG_DOMAIN, LOG_TAG, 'pauseTask');
        result.success(null);
        break;
      case 'resumeTask':
        hilog.info(LOG_DOMAIN, LOG_TAG, 'resumeTask');
        result.success(null);
        break;
      case 'cancelTask':
        hilog.info(LOG_DOMAIN, LOG_TAG, 'cancelTask');
        result.success(null);
        break;
      case 'getPreloadConfig':
        result.success({'duration': 1000, 'loadStartPositionMs': 0});
        break;
      case 'setPreloadConfig':
        result.success(null);
        break;
      case 'resetPreloadConfig':
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  onListen(args: Object, events: EventSink): void {
    this.eventSink = events;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'MediaLoaderV2 EventChannel onListen');
  }

  onCancel(args: Object): void {
    this.eventSink = null;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'MediaLoaderV2 EventChannel onCancel');
  }

  release(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliMediaLoaderV2Plugin release');
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