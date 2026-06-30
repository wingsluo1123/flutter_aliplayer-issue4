/**
 * AliPlayer PlatformView 四件套 (Factory + View + Builder + Component)
 *
 * 鸿蒙侧使用 XComponent(SURFACE) 作为视频渲染面, 替代 Android SurfaceView/TextureView/AliDisplayView。
 * 通过 XComponentController.getXComponentSurfaceId() 获取 surfaceId, 回传给插件,
 * 由插件在 setPlayerView 调用时赋给 AVPlayer.surfaceId。
 *
 * viewType: 'flutter_aliplayer_render_view' (与 Dart 侧 AliPlayerView OhosView 分支一致)
 */
import { PlatformView, PlatformViewFactory, StandardMessageCodec } from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0x0001;
const LOG_TAG: string = 'AliPlayerView';

/** surfaceId 回调: 当 XComponent surface 创建时, 通知插件 (viewId, surfaceId) */
export type SurfaceIdCallback = (viewId: number, surfaceId: string) => void;

/** 全局 surfaceId 回调注册表 (桥接 PlatformView 与 ArkUI Component) */
export class AliPlayerSurfaceRegistry {
  private static callbacks: Map<number, SurfaceIdCallback> = new Map();

  static register(viewId: number, callback: SurfaceIdCallback): void {
    AliPlayerSurfaceRegistry.callbacks.set(viewId, callback);
  }

  static getCallback(viewId: number): SurfaceIdCallback | null {
    const cb = AliPlayerSurfaceRegistry.callbacks.get(viewId);
    if (cb === undefined) {
      return null;
    }
    return cb;
  }

  static unregister(viewId: number): void {
    AliPlayerSurfaceRegistry.callbacks.delete(viewId);
  }
}

/** PlatformView 实现: 持有 viewId, 返回 XComponent 构建器 */
export class AliPlayerPlatformView extends PlatformView {
  private viewId: number;
  private surfaceIdCallback: SurfaceIdCallback | null;

  constructor(
    context: common.Context,
    viewId: number,
    args: Object,
    callback: SurfaceIdCallback | null,
  ) {
    super();
    this.viewId = viewId;
    this.surfaceIdCallback = callback;
    // 注册 surface 回调, 供 ArkUI Component 在 onLoad 时回调
    if (callback !== null) {
      AliPlayerSurfaceRegistry.register(viewId, callback);
    }
  }

  getViewId(): number {
    return this.viewId;
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(buildAliPlayerView);
  }

  dispose(): void {
    AliPlayerSurfaceRegistry.unregister(this.viewId);
    this.surfaceIdCallback = null;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'dispose viewId=%{public}d', this.viewId);
  }
}

/** PlatformView Factory */
export class AliPlayerViewFactory extends PlatformViewFactory {
  private surfaceIdCallback: SurfaceIdCallback | null;

  constructor(callback: SurfaceIdCallback | null) {
    super(StandardMessageCodec.INSTANCE);
    this.surfaceIdCallback = callback;
  }

  create(context: common.Context, viewId: number, args: Object): PlatformView {
    return new AliPlayerPlatformView(context, viewId, args, this.surfaceIdCallback);
  }
}

/** @Builder 视图构建函数 (参数为框架 Params 类型) */
@Builder
function buildAliPlayerView(params: Params) {
  AliPlayerRenderComponent({
    viewId: (params.platformView as AliPlayerPlatformView).getViewId(),
  });
}

/** ArkUI 渲染组件: XComponent(SURFACE) */
@Component
struct AliPlayerRenderComponent {
  @Prop viewId: number = 0;
  private xComponentController: XComponentController = new XComponentController();

  build() {
    Column() {
      XComponent({
        id: 'flutter_aliplayer_render_' + this.viewId.toString(),
        type: XComponentType.SURFACE,
        controller: this.xComponentController,
      })
        .onLoad(() => {
          try {
            const surfaceId = this.xComponentController.getXComponentSurfaceId();
            hilog.info(LOG_DOMAIN, LOG_TAG, 'onLoad viewId=%{public}d surfaceId=%{public}s',
              this.viewId, surfaceId);
            const cb = AliPlayerSurfaceRegistry.getCallback(this.viewId);
            if (cb !== null) {
              cb(this.viewId, surfaceId);
            }
          } catch (e) {
            hilog.error(LOG_DOMAIN, LOG_TAG, 'onLoad getXComponentSurfaceId failed: %{public}s',
              (e as Error).message);
          }
        })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
