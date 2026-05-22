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

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliGlobalSettingsPlugin';

/**
 * 全局设置插件
 */
export class AliGlobalSettingsPlugin implements MethodCallHandler {
  private channel: MethodChannel | null = null;
  private messenger: BinaryMessenger;
  private context: common.Context;
  
  // 日志级别
  private logLevel: number = 3; // LogLevel.INFO
  
  // 是否启用控制台日志
  private consoleLogEnabled: boolean = true;

  constructor(messenger: BinaryMessenger, context: common.Context) {
    this.messenger = messenger;
    this.context = context;
    
    // 注册全局设置 MethodChannel
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
        this.disableCrashUpload(call.args as Map<string, Object>, result);
        break;
      case 'enableEnhancedHttpDns':
        this.enableEnhancedHttpDns(call.args as Map<string, Object>, result);
        break;
      case 'setLogLevel':
        this.setLogLevelInternal(call.args as Map<string, Object>, result);
        break;
      case 'enableConsoleLog':
        this.enableConsoleLogInternal(call.args as Map<string, Object>, result);
        break;
      case 'setSystemBrightness':
        this.setSystemBrightness(call.args as Map<string, Object>, result);
        break;
      case 'getSystemBrightness':
        this.getSystemBrightness(call.args as Map<string, Object>, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private setGlobalEnvironment(args: Map<string, Object> | null, result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setGlobalEnvironment');
    // TODO: 实现全局环境设置
    result.notImplemented();
  }

  private setOption(args: Map<string, Object> | null, result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setOption');
    result.notImplemented();
  }

  private disableCrashUpload(args: Map<string, Object> | null, result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'disableCrashUpload');
    result.success(null);
  }

  private enableEnhancedHttpDns(args: Map<string, Object> | null, result: MethodResult): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableEnhancedHttpDns');
    result.notImplemented();
  }

  /**
   * 设置日志级别（公开方法）
   */
  setLogLevel(level: number): void {
    this.logLevel = level;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'setLogLevel: %{public}d', level);
    
    // TODO: 调用阿里云 SDK
    // AliPlayerGlobalSettings.setLogLevel(level);
  }

  private setLogLevelInternal(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    const level = (args.get('level') as Object) as number;
    this.setLogLevel(level);
    result.success(null);
  }

  /**
   * 启用控制台日志（公开方法）
   */
  enableConsoleLog(enable: boolean): void {
    this.consoleLogEnabled = enable;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'enableConsoleLog: %{public}s', String(enable));
    
    // TODO: 调用阿里云 SDK
    // AliPlayerGlobalSettings.enableConsoleLog(enable);
  }

  private enableConsoleLogInternal(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) {
      result.error('INVALID_ARGS', 'Arguments required', null);
      return;
    }
    const enable = (args.get('enable') as Object) as boolean;
    this.enableConsoleLog(enable);
    result.success(null);
  }

  private setSystemBrightness(args: Map<string, Object> | null, result: MethodResult): void {
    // HarmonyOS 需要特殊权限控制屏幕亮度
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'setSystemBrightness not supported');
    result.notImplemented();
  }

  private getSystemBrightness(args: Map<string, Object> | null, result: MethodResult): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'getSystemBrightness not supported');
    result.notImplemented();
  }

  release(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AliGlobalSettingsPlugin release');
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }
}