// AlphaCompositeRenderer — OHOS 透明通道视频合成渲染器 (issue #3 问题一)
// 详见 AlphaCompositeRenderer.cpp 头部注释。
#ifndef FLUTTER_ALIPLAYER_ALPHA_COMPOSITE_RENDERER_H
#define FLUTTER_ALIPLAYER_ALPHA_COMPOSITE_RENDERER_H

#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <native_image/native_image.h>
#include <native_window/external_window.h>

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <thread>

namespace flutter_aliplayer {

class AlphaCompositeRenderer {
public:
    explicit AlphaCompositeRenderer(uint64_t targetSurfaceId);
    // 直接以 OHNativeWindow* 创建 (Texture 路径: 引擎窗口不能经 surfaceId 重建 EGLSurface)
    AlphaCompositeRenderer(OHNativeWindow *windowPtr);
    ~AlphaCompositeRenderer();

    // 初始化 EGL/program/OH_NativeImage 并启动。返回 false 时可安全析构。
    bool Start();
    // 设置 AlphaRenderMode: 0 无 / 1 右 / 2 左 / 3 上 / 4 下
    void SetMode(int mode);
    // 设置缩放模式 (Aliyun ScaleMode): 0=FIT, 1=FILL, 2=TO_FILL(stretch)。
    // 缩放基准为合成后的半幅尺寸, 而非 AVPlayer 原始拼接尺寸。
    void SetScalingMode(int mode);
    // 源视频显示尺寸, 由 ArkTS 侧经 AVPlayer.width/height 推送。
    // 不能依赖离屏 producer 窗口的 GET_BUFFER_GEOMETRY — 实测在 Alpha 路径下
    // 该查询返回 0x0 (buffer 几何由生产者决定, 合成器查询时尚未就绪)。
    void SetVideoSize(int width, int height);
    // AVPlayer 离屏输出 surfaceId (设置给 AVPlayer.surfaceId)
    uint64_t GetProducerSurfaceId() const;
    // 原始(拼接后)帧尺寸: AVPlayer 送入离屏面的完整尺寸
    int GetVideoWidth() const;
    int GetVideoHeight() const;
    // 合成后(可见内容)尺寸: 半幅模式(1/2 取 x 半, 3/4 取 y 半)下为原始尺寸的一半。
    // 对外 (getVideoWidth/Height, onVideoSizeChanged) 应报此尺寸。
    int GetComposedWidth() const;
    int GetComposedHeight() const;
    // 实际执行一帧合成 (渲染线程调用)
    void Render();
    void Release();

private:
    bool InitEGL();
    bool BuildProgram();
    bool SetupNativeImage();
    void RequestRender();
    void RenderLoop();
    // 由 mode 与原始帧尺寸推导合成后尺寸; 尺寸变化时同步目标窗口 buffer 几何
    void UpdateComposedSize(int fullWidth, int fullHeight);
    // 由当前 transform 矩阵判定是否存在 90/270 旋转 (横竖屏切换)
    void UpdateRotationFlag();
    bool isRotated90() const { return rotated90_.load(); }

    uint64_t targetSurfaceId_;
    OHNativeWindow *targetWindow_ = nullptr;
    // 外部传入的 NativeWindow (Texture 路径, 归引擎所有, Release 时不销毁)
    OHNativeWindow *externalWindow_ = nullptr;

    // EGL
    EGLDisplay display_ = EGL_NO_DISPLAY;
    EGLSurface eglSurface_ = EGL_NO_SURFACE;
    EGLContext eglContext_ = EGL_NO_CONTEXT;

    // GLES
    GLuint program_ = 0;
    GLuint vao_ = 0;
    GLuint vbo_ = 0;
    GLuint vboTex_ = 0;
    GLuint videoTexture_ = 0;
    GLint modeUniform_ = -1;
    GLint transformUniform_ = -1;
    GLint textureUniform_ = -1;
    GLint quadUniform_ = -1;
    float transformMat_[16] = {0};

    // NativeImage (AVPlayer 帧消费者)
    OH_NativeImage *nativeImage_ = nullptr;
    OHNativeWindow *producerWindow_ = nullptr;
    uint64_t producerSurfaceId_ = 0;

    std::atomic<bool> started_{false};
    std::atomic<int> mode_{0};
    std::atomic<int> videoWidth_{0};
    std::atomic<int> videoHeight_{0};
    // 合成后(可见内容)尺寸 — mode 与原始尺寸共同决定
    std::atomic<int> composedWidth_{0};
    std::atomic<int> composedHeight_{0};
    // 缩放模式: 0=FIT, 1=FILL, 2=TO_FILL。
    // 默认 FIT, 与 Android 侧 SCALE_ASPECT_FIT 及 getScalingMode() 的默认值一致;
    // ArkTS 创建合成器后也会立即推送一次当前值覆盖此处。
    std::atomic<int> scalingMode_{0};
    // 目标窗口 buffer 几何 (计算 FIT/FILL 的 letterbox/crop 用)
    std::atomic<int> targetWidth_{0};
    std::atomic<int> targetHeight_{0};
    // 顶点四边形缩放 (x,y) — 由 composed 与 target 宽高比 + 缩放模式推导
    std::atomic<float> quadScaleX_{1.0f};
    std::atomic<float> quadScaleY_{1.0f};
    // 由 ArkTS 侧推送的源视频显示尺寸 (AVPlayer.width/height)
    std::atomic<int> sourceWidth_{0};
    std::atomic<int> sourceHeight_{0};
    // transform 矩阵是否含 90/270 旋转 (旋转时显示宽高与 buffer 宽高互换)。
    // 用原子量保存: 矩阵由渲染线程写, 而 UpdateComposedSize 也会被 ArkTS 线程调用。
    std::atomic<bool> rotated90_{false};
    // 上次参与计算的目标面几何: 设备旋转会改变目标纹理尺寸, 需据此重算缩放
    std::atomic<int> lastTargetWidth_{0};
    std::atomic<int> lastTargetHeight_{0};
    std::mutex renderMutex_;
    // 专用渲染线程: GL 上下文绑定在其上 (帧回调线程无 GL 上下文, 不能直接渲染)
    std::thread renderThread_;
    std::mutex signalMutex_;
    std::condition_variable signalCv_;
    std::atomic<bool> framePending_{false};
    std::atomic<bool> threadRunning_{false};
    // 离屏 surface (NativeImage) 就绪信号: ArkTS 获取 producerSurfaceId 前等待
    // (mutable: 在 const 的 GetProducerSurfaceId 中也要加锁)
    mutable std::mutex readyMutex_;
    mutable std::condition_variable readyCv_;
};

} // namespace flutter_aliplayer

#endif // FLUTTER_ALIPLAYER_ALPHA_COMPOSITE_RENDERER_H
