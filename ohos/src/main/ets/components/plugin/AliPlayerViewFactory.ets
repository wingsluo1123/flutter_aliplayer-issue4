/**
 * 阿里云播放器 PlatformView Factory
 * 
 * 负责创建 PlatformView 实例,并传入 surfaceId 回调
 */

import PlatformViewFactory from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformViewFactory';
import PlatformView from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import common from '@ohos.app.ability.common';
import { AliPlayerPlatformView, SurfaceCallback } from './AliPlayerPlatformView';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliPlayerViewFactory';

export class AliPlayerViewFactory extends PlatformViewFactory {
  private surfaceCallback: SurfaceCallback;
  
  constructor(surfaceCallback: SurfaceCallback) {
    super(new StandardMessageCodec());
    this.surfaceCallback = surfaceCallback;
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'AliPlayerViewFactory created');
  }
  
  /**
   * 创建 PlatformView 实例
   */
  create(context: common.Context, viewId: number, args: Object): PlatformView {
    const platformView = new AliPlayerPlatformView(context, viewId, args);
    
    // 设置 surfaceId 回调
    platformView.setSurfaceCallback(this.surfaceCallback);
    
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'PlatformView created: viewId=%{public}d', viewId);
    
    return platformView;
  }
}