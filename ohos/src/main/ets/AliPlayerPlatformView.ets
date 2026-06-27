import PlatformView, { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import PlatformViewFactory from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformViewFactory';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';
import { VideoViewRegistry } from './VideoViewRegistry';
import Any from '@ohos/flutter_ohos/src/main/ets/plugin/common/Any';

const LOG_DOMAIN: number = 0xFF00;
const LOG_TAG: string = 'FlutterAliplayer';

@Builder
function buildAliPlayerView(params: Params) {
  AliPlayerViewComponent({ platformView: params.platformView as AliPlayerPlatformView });
}

@Component
struct AliPlayerViewComponent {
  private platformView: AliPlayerPlatformView | null = null;
  private xcController: XComponentController = new XComponentController();

  build() {
    Column() {
      XComponent({
        type: XComponentType.SURFACE,
        controller: this.xcController,
        libraryname: 'premierlibrary',
        id: 'aliplayer_surface'
      })
        .onLoad(() => {
          const surfaceId: string = this.xcController.getXComponentSurfaceId();
          hilog.debug(LOG_DOMAIN, LOG_TAG, 'XComponent onLoad surfaceId=%{public}s', surfaceId);
          if (this.platformView !== null) {
            this.platformView.onXComponentLoad(surfaceId);
          }
        })
        .onDestroy(() => {
          hilog.debug(LOG_DOMAIN, LOG_TAG, 'XComponent onDestroy');
          if (this.platformView !== null) {
            this.platformView.onXComponentDestroy();
          }
        })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}

export class AliPlayerPlatformView extends PlatformView {
  private viewParams: Map<string, Object> = new Map();
  private playerId: number = -1;

  constructor(context: common.Context, viewId: number, args: Any) {
    super();
    this.viewParams.set('viewId', viewId);
    // 使用 Flutter 分配的 PlatformView ID 作为 playerId，
    // 以便 surfaceReady 回调能正确关联到调用 setPlayerView 的播放器
    this.playerId = viewId;
    VideoViewRegistry.register(this.playerId, this);
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(buildAliPlayerView);
  }

  onXComponentLoad(surfaceId: string): void {
    VideoViewRegistry.onSurfaceReady(this.playerId, surfaceId);
  }

  onXComponentDestroy(): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'AliPlayerPlatformView onXComponentDestroy playerId=%{public}d', this.playerId);
  }

  dispose(): void {
    VideoViewRegistry.unregister(this.playerId);
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'AliPlayerPlatformView dispose playerId=%{public}d', this.playerId);
  }
}

export class AliPlayerViewFactory extends PlatformViewFactory {
  constructor() {
    super(new StandardMessageCodec());
  }

  create(context: common.Context, viewId: number, args: Any): PlatformView {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'AliPlayerViewFactory create viewId=%{public}d', viewId);
    return new AliPlayerPlatformView(context, viewId, args);
  }
}
