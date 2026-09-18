// libalpha_compositor.so 的 ArkTS 类型声明 (NAPI 模块 alpha_compositor)
// 注意: 必须是 default 导出, 与 `import alphaCompositor from 'libalpha_compositor.so'` 匹配。
declare namespace alphaCompositor {
  // targetSurfaceId: 目标 surface; nativeWindowPtr: 可选, OHNativeWindow* 指针的十进制字符串 (Texture 路径)
  function createRenderer(targetSurfaceId: string, nativeWindowPtr?: string): string;
  function setMode(handle: string, mode: number): void;
  // 源视频显示尺寸 (AVPlayer.width/height): 离屏 producer 窗口查不到几何, 需由 ArkTS 推送
  function setVideoSize(handle: string, width: number, height: number): void;
  // 缩放模式 (0=FIT, 1=FILL, 2=TO_FILL), 缩放基准为合成后的半幅尺寸
  function setScalingMode(handle: string, mode: number): void;
  // 合成后(可见内容)尺寸, 返回 "宽,高"
  function getComposedSize(handle: string): string;
  function getProducerSurfaceId(handle: string): string;
  function destroyRenderer(handle: string): void;
}
export default alphaCompositor;
