import { hilog } from '@kit.PerformanceAnalysisKit';
import { AliPlayerGlobalSettings } from 'premierlibrary';
import { MethodResult } from '@ohos/flutter_ohos';
import Context from '@ohos.app.ability.common';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';
const DEFAULT_APP_BRIGHTNESS: number = 0.5;

export class AliPlayerGlobalSettingsHandler {
  private context: Context | null = null;

  constructor(context: Context | null) {
    this.context = context;
  }

  handleMethod(method: string, args: Object | null, result: MethodResult): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'GlobalSettingsHandler method=%{public}s', method);
    switch (method) {
      case 'setGlobalEnvironment':
        this.handleSetGlobalEnvironment(args, result);
        break;
      case 'setOption':
        this.handleSetOption(args, result);
        break;
      case 'disableCrashUpload':
        this.handleDisableCrashUpload(args, result);
        break;
      case 'enableEnhancedHttpDns':
        this.handleEnableEnhancedHttpDns(args, result);
        break;
      case 'setCacheUrlHashCallback':
        this.handleSetCacheUrlHashCallback(result);
        break;
      case 'setNetworkCallback':
        result.success(null);
        break;
      case 'setAdaptiveDecoderGetBackupURLCallback':
        result.success(null);
        break;
      case 'setSystemBrightness':
        this.handleSetSystemBrightness(args, result);
        break;
      case 'getSystemBrightness':
        this.handleGetSystemBrightness(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private handleSetGlobalEnvironment(args: Object | null, result: MethodResult): void {
    const config: number = this.objectToNumber(args);
    AliPlayerGlobalSettings.setOptionNum(0, config);
    result.success(null);
  }

  private handleSetOption(args: Object | null, result: MethodResult): void {
    const options: Map<string, Object> | null = args as Map<string, Object> | null;
    if (options !== null) {
      const opt1: number = options.get('opt1') as number;
      const opt2: Object = options.get('opt2') as Object;
      if (typeof opt2 === 'number') {
        AliPlayerGlobalSettings.setOptionNum(opt1, opt2 as number);
      } else if (typeof opt2 === 'string') {
        AliPlayerGlobalSettings.setOptionStr(opt1, opt2 as string);
      }
    }
    result.success(null);
  }

  private handleDisableCrashUpload(args: Object | null, result: MethodResult): void {
    AliPlayerGlobalSettings.disableCrashUpload(this.objectToBoolean(args));
    result.success(null);
  }

  private handleEnableEnhancedHttpDns(args: Object | null, result: MethodResult): void {
    AliPlayerGlobalSettings.enableEnhancedHttpDns(this.objectToBoolean(args));
    result.success(null);
  }

  private objectToNumber(value: Object | null): number {
    if (value === null || value === undefined) {
      return 0;
    }
    if (typeof value === 'string') {
      return Number.parseInt(value as string);
    }
    return value as number;
  }

  private objectToBoolean(value: Object | null): boolean {
    if (value !== null && value !== undefined) {
      return value as boolean;
    }
    return false;
  }

  private handleSetCacheUrlHashCallback(result: MethodResult): void {
    try {
      AliPlayerGlobalSettings.setCacheUrlHashCallback({
        getUrlHashCallback: (url: string): string => {
          hilog.info(LOG_DOMAIN, LOG_TAG, 'getUrlHashCallback url=%{public}s', url);
          return url;
        }
      });
      hilog.info(LOG_DOMAIN, LOG_TAG, 'setCacheUrlHashCallback done');
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'setCacheUrlHashCallback error=%{public}s', (error as Error).message);
    }
    result.success(null);
  }

  private handleSetSystemBrightness(args: Object | null, result: MethodResult): void {
    // Use window brightness as fallback since system brightness needs high permission
    result.success(null);
  }

  private handleGetSystemBrightness(result: MethodResult): void {
    // Return app window brightness approximate
    result.success(DEFAULT_APP_BRIGHTNESS);
  }
}
