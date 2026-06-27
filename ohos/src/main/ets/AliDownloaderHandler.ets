import { hilog } from '@kit.PerformanceAnalysisKit';
import { AliMediaDownloader, AliDownloaderFactory } from 'premierlibrary';
import { DownloaderConfig } from 'premierlibrary/src/main/ets/com/aliyun/downloader/DownloaderConfig';
import { VidAuth } from 'premierlibrary/src/main/ets/com/aliyun/player/source/VidAuth';
import { VidSts } from 'premierlibrary/src/main/ets/com/aliyun/player/source/VidSts';
import { MethodResult, EventSink } from '@ohos/flutter_ohos';
import Context from '@ohos.app.ability.common';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';

export class AliDownloaderHandler {
  private downloaders: Map<string, AliMediaDownloader> = new Map();
  private downloadEventSink: EventSink | null = null;
  private saveDir: string = '';
  private context: Context | null = null;

  constructor(context: Context | null) {
    this.context = context;
  }

  setEventSink(sink: EventSink | null): void {
    this.downloadEventSink = sink;
  }

  handleMethod(method: string, rawArgs: Object | null, result: MethodResult): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'DownloaderHandler method=%{public}s', method);
    const args: Map<string, Object> | null = rawArgs as Map<string, Object> | null;
    switch (method) {
      case 'prepare':
        this.handlePrepare(args, result);
        break;
      case 'start':
        this.handleStart(args, result);
        break;
      case 'selectItem':
        this.handleSelectItem(args, result);
        break;
      case 'setSaveDir':
        this.handleSetSaveDir(rawArgs, result);
        break;
      case 'getFullSaveDir':
        result.success('');
        break;
      case 'stop':
        this.handleStop(args, result);
        break;
      case 'delete':
        this.handleDelete(args, result);
        break;
      case 'getFilePath':
        this.handleGetFilePath(args, result);
        break;
      case 'release':
        this.handleRelease(args, result);
        break;
      case 'updateSource':
        this.handleUpdateSource(args, result);
        break;
      case 'setDownloaderConfig':
        this.handleSetDownloaderConfig(args, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private getKey(vid: string, index: number): string {
    return vid + '_' + index.toString();
  }

  private getIndex(args: Map<string, Object> | null, defaultValue: number = 0): number {
    if (args === null) {
      return defaultValue;
    }
    const value: Object | undefined = args.get('index');
    if (value === undefined || value === null) {
      return defaultValue;
    }
    if (typeof value === 'string') {
      return Number.parseInt(value as string);
    }
    return value as number;
  }

  private getDownloader(vid: string, index: number): AliMediaDownloader | undefined {
    const exactKey: string = this.getKey(vid, index);
    const exactDownloader: AliMediaDownloader | undefined = this.downloaders.get(exactKey);
    if (exactDownloader !== undefined) {
      return exactDownloader;
    }
    return this.downloaders.get(this.getKey(vid, 0));
  }

  private handlePrepare(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null || this.context === null) {
      result.error('ERROR', 'args or context is null', null);
      return;
    }
    const type: string = args.get('type') as string;
    const vid: string = args.get('vid') as string;
    const region: string = (args.get('region') as string) ?? '';
    const accessKeyId: string = (args.get('accessKeyId') as string) ?? '';
    const accessKeySecret: string = (args.get('accessKeySecret') as string) ?? '';
    const securityToken: string = (args.get('securityToken') as string) ?? '';
    const playAuth: string = (args.get('playAuth') as string) ?? '';
    const index: number = this.getIndex(args);

    try {
      const downloader: AliMediaDownloader = AliDownloaderFactory.create(this.context);
      const key: string = this.getKey(vid, index);
      this.downloaders.set(key, downloader);
      if (index !== 0) {
        this.downloaders.set(this.getKey(vid, 0), downloader);
      }

      downloader.setOnPreparedListener({
        onPrepared: (mediaInfo): void => {
          hilog.info(LOG_DOMAIN, LOG_TAG, 'Downloader onPrepared vid=%{public}s', vid);
          if (this.downloadEventSink !== null) {
            this.downloadEventSink.success({ 'method': 'prepared', 'vid': vid, 'index': index });
          }
          result.success({});
        }
      });
      downloader.setOnProgressListener({
        onDownloadingProgress: (percent: number): void => {
          if (this.downloadEventSink !== null) {
            this.downloadEventSink.success({ 'download_progress': percent });
          }
        },
        onProcessingProgress: (percent: number): void => {
          if (this.downloadEventSink !== null) {
            this.downloadEventSink.success({ 'download_process': percent });
          }
        }
      });
      downloader.setOnCompletionListener({
        onCompletion: (): void => {
          if (this.downloadEventSink !== null) {
            this.downloadEventSink.success({ 'download_completion': vid, 'vid': vid, 'index': index });
          }
        }
      });
      downloader.setOnErrorListener({
        onError: (errorInfo): void => {
          hilog.error(LOG_DOMAIN, LOG_TAG, 'Downloader error vid=%{public}s', vid);
          if (this.downloadEventSink !== null) {
            this.downloadEventSink.success({ 'download_error': vid });
          }
        }
      });

      if (this.saveDir !== '') {
        downloader.setSaveDir(this.saveDir);
      }

      if (type === 'download_sts') {
        const stsInfo: VidSts = new VidSts();
        stsInfo.setVid(vid);
        stsInfo.setRegion(region);
        stsInfo.setAccessKeyId(accessKeyId);
        stsInfo.setAccessKeySecret(accessKeySecret);
        stsInfo.setSecurityToken(securityToken);
        downloader.prepareVidSts(stsInfo);
      } else {
        const authInfo: VidAuth = new VidAuth();
        authInfo.setVid(vid);
        authInfo.setRegion(region);
        authInfo.setPlayAuth(playAuth);
        downloader.prepareVidAuth(authInfo);
      }
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'prepare error=%{public}s', (error as Error).message);
      result.error('ERROR', (error as Error).message, null);
    }
  }

  private handleStart(args: Map<string, Object> | null, result: MethodResult): void {
    const vid: string = args?.get('vid') as string;
    const index: number = this.getIndex(args);
    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader !== undefined) {
      downloader.start();
      result.success(null);
    } else {
      result.error('ERROR', 'Downloader not found for key: ' + this.getKey(vid, index), null);
    }
  }

  private handleSelectItem(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) { result.error('ERROR', 'args is null', null); return; }
    const vid: string = args.get('vid') as string;
    const index: number = this.getIndex(args);
    const key: string = this.getKey(vid, index);
    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader !== undefined) {
      downloader.selectItem(index);
      this.downloaders.set(key, downloader);
      result.success(null);
    } else {
      result.error('ERROR', 'Downloader not found for key: ' + key, null);
    }
  }

  private handleSetSaveDir(rawArgs: Object | null, result: MethodResult): void {
    if (rawArgs !== null && rawArgs !== undefined) {
      this.saveDir = rawArgs as string;
    }
    result.success(null);
  }

  private handleStop(args: Map<string, Object> | null, result: MethodResult): void {
    const vid: string = args?.get('vid') as string;
    const index: number = this.getIndex(args);
    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader !== undefined) {
      downloader.stop();
      result.success(null);
    } else {
      result.error('ERROR', 'Downloader not found', null);
    }
  }

  private handleDelete(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null || this.saveDir === '') { result.success(null); return; }
    const vid: string = args.get('vid') as string;
    const index: number = this.getIndex(args);
    const key: string = this.getKey(vid, index);
    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader !== undefined) {
      try {
        downloader.stop();
        downloader.deleteFile();
        this.downloaders.delete(key);
        result.success(0);
      } catch (error) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'delete error=%{public}s', (error as Error).message);
        result.success(null);
      }
    } else {
      result.success(null);
    }
  }

  private handleGetFilePath(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) { result.success(''); return; }
    const vid: string = args.get('vid') as string;
    const index: number = this.getIndex(args);
    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader !== undefined) {
      const filePath: string = downloader.getFilePath();
      result.success(filePath);
    } else {
      result.success('');
    }
  }

  private handleRelease(args: Map<string, Object> | null, result: MethodResult): void {
    const vid: string = args?.get('vid') as string;
    const index: number = this.getIndex(args);
    const key: string = this.getKey(vid, index);
    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader !== undefined) {
      downloader.stop();
      downloader.release();
      this.downloaders.delete(key);
    }
    result.success(null);
  }

  private handleUpdateSource(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) { result.error('ERROR', 'args is null', null); return; }
    const type: string = args.get('type') as string;
    const vid: string = args.get('vid') as string;
    const index: number = this.getIndex(args);
    const region: string = (args.get('region') as string) ?? '';
    const accessKeyId: string = (args.get('accessKeyId') as string) ?? '';
    const accessKeySecret: string = (args.get('accessKeySecret') as string) ?? '';
    const securityToken: string = (args.get('securityToken') as string) ?? '';
    const playAuth: string = (args.get('playAuth') as string) ?? '';

    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader === undefined) {
      result.error('ERROR', 'Downloader not found', null);
      return;
    }
    try {
      if (type === 'download_sts') {
        const stsInfo: VidSts = new VidSts();
        stsInfo.setVid(vid);
        stsInfo.setRegion(region);
        stsInfo.setAccessKeyId(accessKeyId);
        stsInfo.setAccessKeySecret(accessKeySecret);
        stsInfo.setSecurityToken(securityToken);
        downloader.updateVidStsSource(stsInfo);
      } else {
        const authInfo: VidAuth = new VidAuth();
        authInfo.setVid(vid);
        authInfo.setRegion(region);
        authInfo.setPlayAuth(playAuth);
        downloader.updateVidAuthSource(authInfo);
      }
      result.success(null);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'updateSource error=%{public}s', (error as Error).message);
      result.error('ERROR', (error as Error).message, null);
    }
  }

  private handleSetDownloaderConfig(args: Map<string, Object> | null, result: MethodResult): void {
    if (args === null) { result.error('ERROR', 'args is null', null); return; }
    const vid: string = args.get('vid') as string;
    const index: number = this.getIndex(args);
    const downloader: AliMediaDownloader | undefined = this.getDownloader(vid, index);
    if (downloader === undefined) {
      result.error('ERROR', 'Downloader not found', null);
      return;
    }
    const config: DownloaderConfig = new DownloaderConfig();
    const userAgent: Object | undefined = args.get('UserAgent');
    const referrer: Object | undefined = args.get('Referrer');
    const httpProxy: Object | undefined = args.get('HttpProxy');
    const connectTimeoutS: Object | undefined = args.get('ConnectTimeoutS');
    const networkTimeoutMs: Object | undefined = args.get('NetworkTimeoutMs');
    if (userAgent !== undefined && userAgent !== null) {
      config.mUserAgent = userAgent as string;
    }
    if (referrer !== undefined && referrer !== null) {
      config.mReferrer = referrer as string;
    }
    if (httpProxy !== undefined && httpProxy !== null) {
      config.mHttpProxy = httpProxy as string;
    }
    if (connectTimeoutS !== undefined && connectTimeoutS !== null) {
      config.mConnectTimeoutS = connectTimeoutS as number;
    }
    if (networkTimeoutMs !== undefined && networkTimeoutMs !== null) {
      config.mNetworkTimeoutMs = networkTimeoutMs as number;
    }
    downloader.setDownloaderConfig(config);
    result.success(null);
  }

  releaseAll(): void {
    for (const entry of this.downloaders) {
      const downloader: AliMediaDownloader = entry[1];
      try {
        downloader.stop();
        downloader.release();
      } catch (error) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'releaseAll error=%{public}s', (error as Error).message);
      }
    }
    this.downloaders.clear();
    this.downloadEventSink = null;
  }
}
