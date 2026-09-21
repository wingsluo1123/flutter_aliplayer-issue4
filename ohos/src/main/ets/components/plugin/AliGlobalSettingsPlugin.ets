/**
 * 全局设置插件
 */

import {
  BinaryMessenger,
  MethodChannel,
  MethodCall,
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos';

import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AliPlayerGlobalSettings } from 'premierlibrary';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliGlobalSettingsPlugin';

export class AliGlobalSettingsPlugin implements MethodCallHandler {
  private channel: MethodChannel | null = null;
  private messenger: BinaryMessenger;
  private context: common.Context;

  constructor(messenger: BinaryMessenger, context: common.Context) {
    this.messenger = messenger;
    this.context = context;
    
    this.channel = new MethodChannel(messenger, 'plugins.flutter_global_setting');
    this.channel.setMethodCallHandler(this);
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliGlobalSettingsPlugin created');
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'GlobalSettings onMethodCall: %{public}s', call.method);
    
    switch (call.method) {
      case 'setGlobalEnvironment':
        this.setGlobalEnvironment(call.args as Map<string, Object>, result);
        break;
      case 'setOption':
        this.setOption(call.args as Map<string, Object>, result);
        break;
      case 'disableCrashUpload':
        this.disableCrashUpload(call.args, result);
        break;
      case 'enableEnhancedHttpDns':
        this.enableEnhancedHttpDns(call.args, result);
        break;
      case 'setUseHttp2':
        this.setUseHttp2(call.args, result);
        break;
      case 'enableLocalCache':
        this.enableLocalCache(call.args as Map<string, Object>, result);
        break;
      case 'setCacheFileClearConfig':
        this.setCacheFileClearConfig(call.args as Map<string, Object>, result);
        break;
      case 'clearCaches':
        this.clearCaches(result);
        break;
      case 'enableHttpDns':
        this.enableHttpDns(call.args, result);
        break;
      case 'enableNetworkBalance':
        this.enableNetworkBalance(call.args, result);
        break;
      case 'setDNSResolve':
        this.setDNSResolve(call.args as Map<string, Object>, result);
        break;
      case 'setIPResolveType':
        this.setIPResolveType(call.args, result);
        break;
      case 'setAudioStreamType':
        this.setAudioStreamType(call.args, result);
        break;
      case 'enableAudioLowLatencyMode':
        this.enableAudioLowLatencyMode(call.args, result);
        break;
      case 'setLogLevel':
        hilog.info(LOG_DOMAIN, LOG_TAG, 'setLogLevel');
        result.success(null);
        break;
      case 'enableConsoleLog':
        hilog.info(LOG_DOMAIN, LOG_TAG, 'enableConsoleLog');
        result.success(null);
        break;
      case 'setSystemBrightness':
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'setSystemBrightness not supported on OHOS');
        result.notImplemented();
        break;
      case 'getSystemBrightness':
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'getSystemBrightness not supported on OHOS');
        result.notImplemented();
        break;
      case 'getSDKVersion':
        result.success(AliPlayerGlobalSettings.getSdkVersion());
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private setGlobalEnvironment(args: Map<string, Object> | null, result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setGlobalEnvironment');
    result.notImplemented();
  }

  private setOption(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const opt1 = (args.get('opt1') as Object) as number;
    const opt2 = args.get('opt2');
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setOption: opt1=%{public}d', opt1);
    
    if (typeof opt2 === 'number') {
      AliPlayerGlobalSettings.setOptionNum(opt1, opt2 as number);
    } else if (typeof opt2 === 'string') {
      AliPlayerGlobalSettings.setOptionStr(opt1, opt2 as string);
    }
    
    result.success(null);
  }

  private disableCrashUpload(args: Object | null, result: MethodResult): void {
    const disable = args as boolean;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'disableCrashUpload: %{public}s', String(disable));
    AliPlayerGlobalSettings.disableCrashUpload(disable);
    result.success(null);
  }

  private enableEnhancedHttpDns(args: Object | null, result: MethodResult): void {
    const enable = args as boolean;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableEnhancedHttpDns: %{public}s', String(enable));
    AliPlayerGlobalSettings.enableEnhancedHttpDns(enable);
    result.success(null);
  }

  private setUseHttp2(args: Object | null, result: MethodResult): void {
    const use = args as boolean;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setUseHttp2: %{public}s', String(use));
    AliPlayerGlobalSettings.setUseHttp2(use);
    result.success(null);
  }

  private enableLocalCache(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const enable = (args.get('enable') as Object) as boolean;
    const maxBufferMemoryKB = (args.get('maxBufferMemoryKB') as Object) as number;
    const localCacheDir = (args.get('localCacheDir') as Object) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableLocalCache: enable=%{public}s maxBufferMemoryKB=%{public}d dir=%{public}s',
      String(enable), maxBufferMemoryKB, localCacheDir);
    
    AliPlayerGlobalSettings.enableLocalCache(enable, maxBufferMemoryKB, localCacheDir);
    result.success(null);
  }

  private setCacheFileClearConfig(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const expireMin = (args.get('expireMin') as Object) as number;
    const maxCapacityMB = (args.get('maxCapacityMB') as Object) as number;
    const freeStorageMB = (args.get('freeStorageMB') as Object) as number;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setCacheFileClearConfig: expireMin=%{public}d maxCapacityMB=%{public}d freeStorageMB=%{public}d',
      expireMin, maxCapacityMB, freeStorageMB);
    
    AliPlayerGlobalSettings.setCacheFileClearConfig(expireMin, maxCapacityMB, freeStorageMB);
    result.success(null);
  }

  private clearCaches(result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'clearCaches');
    AliPlayerGlobalSettings.clearCaches();
    result.success(null);
  }

  private enableHttpDns(args: Object | null, result: MethodResult): void {
    const enable = args as boolean;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableHttpDns: %{public}s (deprecated)', String(enable));
    AliPlayerGlobalSettings.enableHttpDns(enable);
    result.success(null);
  }

  private enableNetworkBalance(args: Object | null, result: MethodResult): void {
    const enable = args as boolean;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableNetworkBalance: %{public}s', String(enable));
    AliPlayerGlobalSettings.enableNetworkBalance(enable);
    result.success(null);
  }

  private setDNSResolve(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    
    const host = (args.get('host') as Object) as string;
    const ip = (args.get('ip') as Object) as string;
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setDNSResolve: host=%{public}s ip=%{public}s', host, ip);
    AliPlayerGlobalSettings.setDNSResolve(host, ip);
    result.success(null);
  }

  private setIPResolveType(args: Object | null, result: MethodResult): void {
    const type = args as number;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setIPResolveType: %{public}d', type);
    AliPlayerGlobalSettings.setIPResolveType(type);
    result.success(null);
  }

  private setAudioStreamType(args: Object | null, result: MethodResult): void {
    const streamType = args as number;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setAudioStreamType: %{public}d', streamType);
    AliPlayerGlobalSettings.setAudioStreamType(streamType);
    result.success(null);
  }

  private enableAudioLowLatencyMode(args: Object | null, result: MethodResult): void {
    const enable = args as boolean;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableAudioLowLatencyMode: %{public}s', String(enable));
    AliPlayerGlobalSettings.enableAudioLowLatencyMode(enable);
    result.success(null);
  }

  release(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliGlobalSettingsPlugin release');
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  setLogLevel(level: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setLogLevel: %{public}d', level);
  }

  enableConsoleLog(enable: boolean): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableConsoleLog: %{public}s', String(enable));
  }
}