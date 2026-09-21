/**
 * AliPlayer PlatformView 四件套 (Factory + View + Builder + Component)
 *
 * 鸿蒙侧使用 XComponent 作为视频渲染面, 替代 Android SurfaceView/TextureView/AliDisplayView。
 *
 * 迁移要点 (issue #4, 经真机 PoC 实测确定):
 *  1. **必须带 `libraryname: 'premierlibrary'`** —— 官方 SDK 的 .so 需作为该 XComponent 的
 *     native 模块加载, 才会把该 XComponent 注册进内部 XcomponentMap。实测: 不带 libraryname
 *     的 XComponent 传 id 给 setSurfaceId 只到 state=3 但**不出画**。
 *  2. **用 `XComponentType.TEXTURE`** —— 官方 Alpha 透明渲染要求 texture 型
 *     (官方原话「礼物必须是 texture 否则会有背景色」)。TEXTURE 型同时兼容非 Alpha 播放。
 *  3. **回调传的是 XComponent 的 id (不是 surfaceId)** —— 官方 `setSurfaceId` 收的是
 *     「XComponentId」。实测: 传 getXComponentSurfaceId() 得到的数字 surfaceId **不出画**。
 *
 * 因此这里 onLoad 时把 **id 字符串** 回传给插件, 由插件赋给官方 player.setSurfaceId。
 *
 * viewType: 'flutter_aliplayer_render_view' (与 Dart 侧 AliPlayerView OhosView 分支一致)
 */
import { PlatformView, PlatformViewFactory, StandardMessageCodec } from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import common from '@ohos.app.ability.common';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0x0001;
const LOG_TAG: string = 'AliPlayerView';

/** 渲染面回调: 当 XComponent 创建时, 通知插件 (viewId, xComponentId)。
 *  注: 第二参为 XComponent 的 **id**(官方 setSurfaceId 所需), 非 surfaceId。 */
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
    // 注册回调, 供 ArkUI Component 在 onLoad 时回调
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

/** ArkUI 渲染组件: XComponent(TEXTURE) + 官方 SDK native 模块 */
@Component
struct AliPlayerRenderComponent {
  @Prop viewId: number = 0;
  private xComponentController: XComponentController = new XComponentController();

  build() {
    Column() {
      XComponent({
        id: 'flutter_aliplayer_render_' + this.viewId.toString(),
        // TEXTURE 型: 官方 Alpha 透明渲染要求 (TEXTURE 同时兼容非 Alpha 播放)
        type: XComponentType.TEXTURE,
        // 必须声明: 官方 SDK 的 .so 作为该 XComponent 的 native 模块加载,
        // 才会把此 XComponent 注册进 SDK 内部 XcomponentMap (否则 setSurfaceId 不出画)
        libraryname: 'premierlibrary',
        controller: this.xComponentController,
      })
        .onLoad(() => {
          // 官方 setSurfaceId 收的是 XComponent 的 id, 不是 surfaceId
          const xcId = 'flutter_aliplayer_render_' + this.viewId.toString();
          hilog.info(LOG_DOMAIN, LOG_TAG, 'onLoad viewId=%{public}d xComponentId=%{public}s',
            this.viewId, xcId);
          const cb = AliPlayerSurfaceRegistry.getCallback(this.viewId);
          if (cb !== null) {
            cb(this.viewId, xcId);
          }
        })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    // 背景保持透明, 便于 Alpha 模式下透出下层内容
    .backgroundColor(Color.Transparent)
  }
}
