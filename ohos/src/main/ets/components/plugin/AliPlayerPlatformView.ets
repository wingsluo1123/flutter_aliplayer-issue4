/**
 * 阿里云播放器 PlatformView 实现
 * 
 * 负责视频画面的渲染承载:
 * - XComponent(SURFACE) 创建
 * - surfaceId 获取并回绑给播放器实例
 * - 视图生命周期管理
 */

import PlatformView from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'AliPlayerPlatformView';

/**
 * 回调接口: surface 创建/销毁通知
 */
export interface SurfaceCallback {
  onSurfaceReady(viewId: number, surfaceId: string): void;
  onSurfaceDestroyed(viewId: number): void;
}

/**
 * Builder 数据类 - 使用 @Observed 装饰
 */
@Observed
export class AliPlayerViewData {
  playerId: string = '';
  viewId: number = -1;
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;
  viewType: string = 'surfaceview';
  surfaceCallback: SurfaceCallback | null = null;
  xComponentController: XComponentController = new XComponentController();
}

/**
 * 视图构建函数 - 参数必须使用 Params 类型
 */
@Builder
function buildAliPlayerView(params: Params) {
  AliPlayerSurfaceComponent({ params: params });
}

/**
 * 视频渲染组件 - build 方法必须有单一根容器
 */
@Component
struct AliPlayerSurfaceComponent {
  @ObjectLink params: Params;
  
  build() {
    Column() {
      // 从 params.platformView 获取 AliPlayerPlatformView 实例
      AliPlayerPlatformViewInstance({ platformView: this.params.platformView as AliPlayerPlatformView });
    }
    .width('100%')
    .height('100%');
  }
}

/**
 * XComponent 包装组件 - 使用 @State 管理控制器
 */
@Component
struct AliPlayerPlatformViewInstance {
  @State platformView: AliPlayerPlatformView | null = null;
  private controller: XComponentController = new XComponentController();
  
  build() {
    if (this.platformView !== null) {
      XComponent({
        id: 'flutter_aliplayer_render_' + this.platformView.getViewData().viewId.toString(),
        type: XComponentType.TEXTURE,
        libraryname: 'premierlibrary',
        controller: this.controller
      })
      .onLoad(() => {
        this.onXComponentLoad();
      })
      .onDestroy(() => {
        this.onXComponentDestroy();
      })
      .width(this.platformView.getViewData().width)
      .height(this.platformView.getViewData().height);
    }
  }
  
  private onXComponentLoad(): void {
    if (this.platformView === null) {
      return;
    }
    const data = this.platformView.getViewData();
    // 官方 setSurfaceId 接收 XComponent id，而不是 controller 返回的数字 surfaceId。
    const xComponentId: string = 'flutter_aliplayer_render_' + data.viewId.toString();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'XComponent onLoad, viewId=%{public}d xComponentId=%{public}s',
      data.viewId, xComponentId);

    if (data.surfaceCallback !== null && data.viewId >= 0) {
      data.surfaceCallback.onSurfaceReady(data.viewId, xComponentId);
    }
    data.xComponentController = this.controller;
  }
  
  private onXComponentDestroy(): void {
    if (this.platformView === null) {
      return;
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'XComponent onDestroy');
    
    const data = this.platformView.getViewData();
    if (data.surfaceCallback !== null && data.viewId >= 0) {
      data.surfaceCallback.onSurfaceDestroyed(data.viewId);
    }
  }
}

/**
 * PlatformView 实现
 */
export class AliPlayerPlatformView extends PlatformView {
  private viewData: AliPlayerViewData;
  
  constructor(context: common.Context, viewId: number, args: Object) {
    super();
    
    this.viewData = new AliPlayerViewData();
    this.viewData.viewId = viewId;
    
    if (args !== null && args !== undefined) {
      const creationParams = args as Map<string, Object>;
      
      const playerIdValue = creationParams.get('playerId');
      if (playerIdValue !== undefined) {
        this.viewData.playerId = playerIdValue as string;
      }
      
      const xValue = creationParams.get('x');
      if (xValue !== undefined) {
        this.viewData.x = xValue as number;
      }
      
      const yValue = creationParams.get('y');
      if (yValue !== undefined) {
        this.viewData.y = yValue as number;
      }
      
      const widthValue = creationParams.get('width');
      if (widthValue !== undefined) {
        this.viewData.width = widthValue as number;
      }
      
      const heightValue = creationParams.get('height');
      if (heightValue !== undefined) {
        this.viewData.height = heightValue as number;
      }
      
      const viewTypeValue = creationParams.get('viewType');
      if (viewTypeValue !== undefined) {
        this.viewData.viewType = viewTypeValue as string;
      }
      
      hilog.debug(LOG_DOMAIN, LOG_TAG, 
        'PlatformView created: viewId=%{public}d playerId=%{public}s width=%{public}d height=%{public}d', 
        this.viewData.viewId, this.viewData.playerId, this.viewData.width, this.viewData.height);
    }
  }
  
  /**
   * 设置 surface 回调
   */
  setSurfaceCallback(callback: SurfaceCallback): void {
    this.viewData.surfaceCallback = callback;
  }
  
  /**
   * 获取视图数据
   */
  getViewData(): AliPlayerViewData {
    return this.viewData;
  }
  
  /**
   * 获取视图构建器 - 必须返回 WrappedBuilder<[Params]>
   */
  getView(): WrappedBuilder<[Params]> {
    return wrapBuilder<[Params]>(buildAliPlayerView);
  }
  
  /**
   * 释放视图资源
   */
  dispose(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'PlatformView disposed: viewId=%{public}d', this.viewData.viewId);
    this.viewData.surfaceCallback = null;
  }
}