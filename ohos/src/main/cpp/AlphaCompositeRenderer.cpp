// AlphaCompositeRenderer
//
// OHOS 侧透明通道视频合成渲染器 (issue #3 问题一实现)。
//
// 渲染管线:
//   AVPlayer --(surfaceId)--> OH_NativeImage(离屏消费) --(GL_TEXTURE_EXTERNAL_OES)
//     --> GLES shader 按 AlphaRenderMode 采样 RGB 半区 + Alpha 半区合成
//     --> EGL 绘制到 XComponent 的 NativeWindow(透明背景)
//
// 线程模型: GL 上下文绑定在专用渲染线程(RenderLoop), 帧到达经信号唤醒该线程执行合成。
#include "AlphaCompositeRenderer.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <hilog/log.h>
#include <native_image/native_image.h>
#include <native_window/external_window.h>

#include <chrono>
#include <cmath>
#include <cstring>
#include <mutex>

#ifndef GL_TEXTURE_EXTERNAL_OES
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#endif

namespace {
constexpr uint32_t kLogDomain = 0x0001;
const char *kLogTag = "AlphaComposite";
constexpr float VERTEX_COORDS[] = {
    -1.0f, -1.0f,
     1.0f, -1.0f,
    -1.0f,  1.0f,
     1.0f,  1.0f,
};
// 纹理坐标: 与 VERTEX_COORDS 一一对应, 直接使用"显示空间 UV"
// (左上 0,0 → 右下 1,1), 不做手工翻转 —— 方向修正全部交给 uTransform
// (OH_NativeImage_GetTransformMatrixV2, 含旋转/镜像/裁剪)。
// 曾在此手工做过一次 V 翻转, 与 uTransform 的修正叠加成"二次翻转",
// 实测导致合成画面相对直出画面上下颠倒。
constexpr float TEX_COORDS[] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,
};

// 顶点着色器: 把显示空间 UV 先经 uTransform(旋转/镜像/裁剪)映射到内容空间,
// 半区切分在内容空间进行, 保证旋转/镜像下 RGB 与 Alpha 半区方向仍正确。
// uQuadScale: 顶点四边形缩放, 由 setScalingMode 基于"合成后半幅尺寸"与目标面宽高比推导,
// 实现 FIT(留黑边) / FILL(裁切) / TO_FILL(拉伸)。
const char *VERT_SRC = R"(#version 300 es
precision mediump float;
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec2 aTexCoord;
uniform vec2 uQuadScale;
out vec2 vDisplayUv;
void main() {
    gl_Position = vec4(aPos * uQuadScale, 0.0, 1.0);
    // 只传"显示空间"UV; 映射到 buffer 空间放在片元着色器里,
    // 因为半区切分必须在显示空间完成 (见 FRAG_SRC 注释)。
    vDisplayUv = aTexCoord;
}
)";

// 片元着色器: 按 mode 采样 RGB 半区与 Alpha 半区合成。
// 视频 "宽=2x内容宽" 的拼接流: 左右模式取 x 半区; 上下模式取 y 半区。
//
// 经顶点着色器输入的 vTexCoord 已是内容空间 UV
// (已用 OH_NativeImage_GetTransformMatrixV2 的矩阵去除旋转/镜像/裁剪),
// 此处直接在内容空间切半区采样, 保证旋转/镜像下 RGB 与 Alpha 方向一致。
const char *FRAG_SRC = R"(#version 300 es
#extension GL_OES_EGL_image_external : require
precision mediump float;
in vec2 vDisplayUv;
out vec4 fragColor;
uniform samplerExternalOES uTexture;
uniform mat4 uTransform;
uniform int uMode; // 1:alpha在右 2:alpha在左 3:alpha在上 4:alpha在下
void main() {
    // 关键: 半区切分在"显示空间"进行 —— mode 的语义是"用户看到的方位"
    // (alpha 在右/左/上/下)。显示空间切分后再用 uTransform 映射到 buffer
    // 空间采样, 这样视频带旋转元数据 (90/270) 时切分方位依然正确。
    // 若在 buffer 空间直接切分, 旋转后"右半"会对应 buffer 的另一条轴 → 错位。
    vec2 rgbUv = vDisplayUv;
    vec2 alphaUv = vDisplayUv;
    if (uMode == 1) {           // alpha 在右半: rgb 取左半, alpha 取右半
        rgbUv.x = vDisplayUv.x * 0.5;
        alphaUv.x = vDisplayUv.x * 0.5 + 0.5;
    } else if (uMode == 2) {    // alpha 在左半
        rgbUv.x = vDisplayUv.x * 0.5 + 0.5;
        alphaUv.x = vDisplayUv.x * 0.5;
    } else if (uMode == 3) {    // alpha 在上半: color 取下半, alpha 取上半
        rgbUv.y = vDisplayUv.y * 0.5;
        alphaUv.y = vDisplayUv.y * 0.5 + 0.5;
    } else if (uMode == 4) {    // alpha 在下半: color 取上半, alpha 取下半
        rgbUv.y = vDisplayUv.y * 0.5 + 0.5;
        alphaUv.y = vDisplayUv.y * 0.5;
    }
    // 显示空间 -> buffer 空间 (含旋转/镜像/裁剪)
    vec2 rgbT = (uTransform * vec4(rgbUv, 0.0, 1.0)).xy;
    vec2 alphaT = (uTransform * vec4(alphaUv, 0.0, 1.0)).xy;
    vec4 rgb = texture(uTexture, rgbT);
    float alpha = texture(uTexture, alphaT).r;
    // 必须输出预乘 alpha: Flutter 引擎把纹理内容按预乘处理
    // (合成公式 out = src + dst * (1 - src.a))。
    // 若直出非预乘 RGB, alpha=0 处不会被判为全透明, 而是变成
    // "内容RGB + 垫层RGB" 的叠加色 (实测透明区显示成紫色而非透出下层)。
    fragColor = vec4(rgb.rgb * alpha, alpha);
}
)";

GLuint CompileShader(GLenum type, const char *src) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    GLint ok = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok != GL_TRUE) {
        char buf[512];
        glGetShaderInfoLog(shader, sizeof(buf), nullptr, buf);
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "shader compile failed: %{public}s", buf);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}
} // namespace

namespace flutter_aliplayer {

AlphaCompositeRenderer::AlphaCompositeRenderer(uint64_t targetSurfaceId)
    : targetSurfaceId_(targetSurfaceId) {}

AlphaCompositeRenderer::AlphaCompositeRenderer(OHNativeWindow *windowPtr)
    : targetSurfaceId_(0), externalWindow_(windowPtr) {}

AlphaCompositeRenderer::~AlphaCompositeRenderer() { Release(); }

bool AlphaCompositeRenderer::InitEGL() {
    display_ = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display_ == EGL_NO_DISPLAY) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "eglGetDisplay failed");
        return false;
    }
    EGLint major = 0, minor = 0;
    if (!eglInitialize(display_, &major, &minor)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "eglInitialize failed");
        return false;
    }
    // 目标 surface 需要透明: alpha 尺寸 >= 8
    EGLint attribs[] = {
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_NONE,
    };
    EGLConfig config = nullptr;
    EGLint numConfigs = 0;
    if (!eglChooseConfig(display_, attribs, &config, 1, &numConfigs) || numConfigs < 1) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "eglChooseConfig failed");
        return false;
    }
    eglSurface_ = eglCreateWindowSurface(display_, config,
        reinterpret_cast<EGLNativeWindowType>(
            externalWindow_ != nullptr ? externalWindow_ : targetWindow_), nullptr);
    if (eglSurface_ == EGL_NO_SURFACE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "eglCreateWindowSurface failed 0x%{public}x",
            eglGetError());
        return false;
    }
    // Texture 路径: 引擎纹理窗口的 buffer 尺寸要等首帧才设置, 会导致 swap 时
    // EGL_BAD_ALLOC(0x3003) — 此处显式设置一个与视频匹配的初始几何尺寸。
    if (externalWindow_ != nullptr) {
        int32_t gw = 1280, gh = 720;
        OH_NativeWindow_NativeWindowHandleOpt(externalWindow_, SET_BUFFER_GEOMETRY, gw, gh);
        // 合成结果带 alpha: 纹理窗口 buffer 需用 RGBA8888, 否则按不透明格式合成
        // (直连窗口后此设置不再引发 No DlImage — 那是 surfaceId 重建窗口导致的)
        int fmt = NATIVEBUFFER_PIXEL_FMT_RGBA_8888;
        OH_NativeWindow_NativeWindowHandleOpt(externalWindow_, SET_FORMAT, fmt);
        OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "texture window geometry 1280x720 fmt=RGBA8888");
    }
    static const EGLint ctxAttribs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    eglContext_ = eglCreateContext(display_, config, EGL_NO_CONTEXT, ctxAttribs);
    if (eglContext_ == EGL_NO_CONTEXT) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "eglCreateContext failed");
        return false;
    }
    // 注意: 不在此处 MakeCurrent — GL 上下文由专用渲染线程(RenderLoop)持有,
    // EGL 上下文同一时刻只能绑定一个线程。
    // 上方仅对 Texture 直连窗口(externalWindow_)显式设置了 geometry/format;
    // 对 surfaceId 重建的窗口(targetWindow_)不做 SET_FORMAT/SET_UI_TIMESTAMP 等操作,
    // 额外设置会干扰 Flutter 引擎的 buffer 获取 (No DlImage available)。
    return true;
}

bool AlphaCompositeRenderer::BuildProgram() {
    GLuint vert = CompileShader(GL_VERTEX_SHADER, VERT_SRC);
    GLuint frag = CompileShader(GL_FRAGMENT_SHADER, FRAG_SRC);
    if (vert == 0 || frag == 0) {
        return false;
    }
    program_ = glCreateProgram();
    glAttachShader(program_, vert);
    glAttachShader(program_, frag);
    glLinkProgram(program_);
    glDeleteShader(vert);
    glDeleteShader(frag);
    GLint ok = GL_FALSE;
    glGetProgramiv(program_, GL_LINK_STATUS, &ok);
    if (ok != GL_TRUE) {
        char buf[512];
        glGetProgramInfoLog(program_, sizeof(buf), nullptr, buf);
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "program link failed: %{public}s", buf);
        return false;
    }
    modeUniform_ = glGetUniformLocation(program_, "uMode");
    transformUniform_ = glGetUniformLocation(program_, "uTransform");
    textureUniform_ = glGetUniformLocation(program_, "uTexture");
    quadUniform_ = glGetUniformLocation(program_, "uQuadScale");

    // VBO
    glGenBuffers(1, &vbo_);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(VERTEX_COORDS), VERTEX_COORDS, GL_STATIC_DRAW);
    glGenBuffers(1, &vboTex_);
    glBindBuffer(GL_ARRAY_BUFFER, vboTex_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(TEX_COORDS), TEX_COORDS, GL_STATIC_DRAW);

    // VAO
    glGenVertexArrays(1, &vao_);
    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, vboTex_);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);
    return true;
}

bool AlphaCompositeRenderer::SetupNativeImage() {
    glGenTextures(1, &videoTexture_);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, videoTexture_);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // OH_NativeImage 作为 AVPlayer 输出帧的消费者
    nativeImage_ = OH_NativeImage_Create(videoTexture_, GL_TEXTURE_EXTERNAL_OES);
    if (nativeImage_ == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "OH_NativeImage_Create failed");
        return false;
    }
    producerWindow_ = OH_NativeImage_AcquireNativeWindow(nativeImage_);
    if (producerWindow_ == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "AcquireNativeWindow failed");
        return false;
    }
    uint64_t imageSurfaceId = 0;
    OH_NativeImage_GetSurfaceId(nativeImage_, &imageSurfaceId);
    producerSurfaceId_ = imageSurfaceId;
    OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag,
        "offscreen producer surfaceId=%{public}llu target=%{public}llu",
        static_cast<unsigned long long>(imageSurfaceId),
        static_cast<unsigned long long>(targetSurfaceId_));
    // 帧可用回调 → 请求一次渲染
    OH_OnFrameAvailableListener listener;
    listener.context = this;
    listener.onFrameAvailable = [](void *ctx) {
        static_cast<AlphaCompositeRenderer *>(ctx)->RequestRender();
    };
    OH_NativeImage_SetOnFrameAvailableListener(nativeImage_, listener);
    return true;
}

void AlphaCompositeRenderer::Render() {
    std::lock_guard<std::mutex> lock(renderMutex_);
    // GL 上下文已由渲染线程常驻持有, 无需再次 MakeCurrent
    // 消费最新一帧到 external OES 纹理
    OH_NativeImage_UpdateSurfaceImage(nativeImage_);
    OH_NativeImage_GetTransformMatrixV2(nativeImage_, transformMat_);
    // 先由矩阵更新旋转标记 (横竖屏切换会改变显示宽高), 再据此重算合成尺寸
    const bool prevRotated = rotated90_.load();
    UpdateRotationFlag();

    // 源尺寸取自 ArkTS 推送的 AVPlayer.width/height。
    // 不能查询离屏 producer 窗口 — 实测 GET_BUFFER_GEOMETRY 恒返回 0x0。
    const int prevW = videoWidth_.load();
    const int prevH = videoHeight_.load();
    videoWidth_ = sourceWidth_.load();
    videoHeight_ = sourceHeight_.load();
    // 目标面几何 (FIT/FILL 的 letterbox/crop 需要)。设备旋转后纹理尺寸会变,
    // 因此尺寸变化也要触发重算。
    const int prevTW = lastTargetWidth_.load();
    const int prevTH = lastTargetHeight_.load();
    OHNativeWindow *targetWin = externalWindow_ != nullptr ? externalWindow_ : targetWindow_;
    if (targetWin != nullptr) {
        int32_t tw = 0, th = 0;
        OH_NativeWindow_NativeWindowHandleOpt(targetWin, GET_BUFFER_GEOMETRY, &th, &tw);
        if (tw > 0 && th > 0) {
            targetWidth_ = static_cast<int>(tw);
            targetHeight_ = static_cast<int>(th);
            lastTargetWidth_ = targetWidth_.load();
            lastTargetHeight_ = targetHeight_.load();
        }
    }
    // 视频尺寸、旋转状态或目标面尺寸变化时重算合成尺寸与缩放四边形
    if (videoWidth_.load() > 0 && videoHeight_.load() > 0 &&
        (prevW != videoWidth_.load() || prevH != videoHeight_.load() ||
         prevRotated != rotated90_.load() ||
         prevTW != lastTargetWidth_.load() || prevTH != lastTargetHeight_.load() ||
         composedWidth_.load() == 0 || composedHeight_.load() == 0)) {
        UpdateComposedSize(videoWidth_.load(), videoHeight_.load());
    }

    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program_);
    glBindVertexArray(vao_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, videoTexture_);
    glUniformMatrix4fv(transformUniform_, 1, GL_FALSE, transformMat_);
    glUniform1i(textureUniform_, 0);
    glUniform1i(modeUniform_, mode_);
    glUniform2f(quadUniform_, quadScaleX_.load(), quadScaleY_.load());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
    eglSwapBuffers(display_, eglSurface_);
}

bool AlphaCompositeRenderer::Start() {
    if (started_) {
        return true;
    }
    // 1. 目标 surface: 外部 NativeWindow (Texture 路径) 直接用; 否则经 surfaceId 创建
    if (externalWindow_ == nullptr) {
        int32_t ret = OH_NativeWindow_CreateNativeWindowFromSurfaceId(targetSurfaceId_, &targetWindow_);
        if (ret != 0 || targetWindow_ == nullptr) {
            OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag,
                "CreateNativeWindowFromSurfaceId failed: %{public}d", ret);
            return false;
        }
    }
    // EGL display/context 在主线程创建; MakeCurrent 与 GL 资源(program/纹理)
    // 全部在渲染线程内完成 — GL 上下文只能绑定调用线程。
    if (!InitEGL()) {
        return false;
    }
    // 启动专用渲染线程
    threadRunning_ = true;
    renderThread_ = std::thread(&AlphaCompositeRenderer::RenderLoop, this);
    started_ = true;
    OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "started, target surfaceId=%{public}llu",
        static_cast<unsigned long long>(targetSurfaceId_));
    return true;
}

void AlphaCompositeRenderer::SetMode(int mode) {
    // 注意: 不能在持有 renderMutex_ 时调用 RequestRender —
    // Render() 会再次加锁, 非递归互斥锁会自死锁。
    {
        std::lock_guard<std::mutex> lock(renderMutex_);
        mode_ = mode;
    }
    // mode 变化会改变半幅切分方向 → 合成后尺寸随之变化
    UpdateComposedSize(sourceWidth_.load(), sourceHeight_.load());
    if (started_) {
        RequestRender();
    }
}

void AlphaCompositeRenderer::SetScalingMode(int mode) {
    if (mode < 0 || mode > 2) {
        return;
    }
    {
        std::lock_guard<std::mutex> lock(renderMutex_);
        scalingMode_ = mode;
    }
    // 缩放基准是合成后的半幅尺寸, 需按新的缩放模式重算四边形
    UpdateComposedSize(sourceWidth_.load(), sourceHeight_.load());
    if (started_) {
        RequestRender();
    }
}

void AlphaCompositeRenderer::SetVideoSize(int width, int height) {
    if (width <= 0 || height <= 0) {
        return;
    }
    const bool changed = (sourceWidth_.load() != width) || (sourceHeight_.load() != height);
    sourceWidth_ = width;
    sourceHeight_ = height;
    if (changed) {
        OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag,
            "video size set by ArkTS: %{public}dx%{public}d", width, height);
        UpdateComposedSize(width, height);
        if (started_) {
            RequestRender();
        }
    }
}

/**
 * 由 transform 矩阵判定是否存在 90/270 旋转。
 * OH_NativeImage_GetTransformMatrixV2 给出列主序 4x4 矩阵 (OpenGL 约定):
 *   [0]=m00, [1]=m10, [4]=m01, [5]=m11
 * 无旋转/180 旋转时两轴各自映射自身 (|m00|≈1 且 |m11|≈1);
 * 90/270 旋转时 x/y 轴互换, 即 |m00|≈0 且 |m11|≈0。
 * 横竖屏切换、以及带 rotation 元数据的竖屏源都会命中此分支。
 */
void AlphaCompositeRenderer::UpdateRotationFlag() {
    const float m00 = std::fabs(transformMat_[0]);
    const float m01 = std::fabs(transformMat_[4]);
    const float m10 = std::fabs(transformMat_[1]);
    const float m11 = std::fabs(transformMat_[5]);
    // 尚无有效帧时 GetTransformMatrixV2 会给出全零矩阵 (例如 SetMode 触发的一次
    // 提前渲染, 此时 UpdateSurfaceImage 还没有图像)。全零不是旋转, 必须保持
    // 上一次判定, 否则普通横屏视频会被误判成 90° 旋转而算错显示尺寸。
    const float magnitude = m00 + m01 + m10 + m11;
    if (magnitude < 0.01f) {
        return;
    }
    // 90/270 旋转: x/y 轴互换 → 主对角线两项同时趋近 0。
    // 无旋转或 180 旋转: 主轴各自映射自身 (|m00|≈1, |m11|≈1), 显示宽高不互换。
    const bool rotated = (m00 < 0.5f) && (m11 < 0.5f);
    if (rotated != rotated90_.load()) {
        OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag,
            "rotation changed: rotated90=%{public}d (m00=%{public}f m01=%{public}f "
            "m10=%{public}f m11=%{public}f)",
            rotated ? 1 : 0, static_cast<double>(m00), static_cast<double>(m01),
            static_cast<double>(m10), static_cast<double>(m11));
    }
    rotated90_ = rotated;
}

/**
 * 由 mode 与原始帧尺寸推导合成后(可见内容)尺寸, 并按缩放模式算出顶点四边形缩放。
 * mode=1/2: 内容为左/右半 → 宽减半; mode=3/4: 内容为上/下半 → 高减半。
 * 注意: 对外尺寸(getVideoWidth/Height、onVideoSizeChanged)报的是合成后尺寸,
 * 与 Android SDK 的 getVideoWidth 语义一致(业务拿到的是可见画面尺寸)。
 */
void AlphaCompositeRenderer::UpdateComposedSize(int fullWidth, int fullHeight) {
    // 源尺寸未知时保持原值: 对外尺寸回退由 ArkTS 侧负责 (AVPlayer.width/height)
    if (fullWidth <= 0 || fullHeight <= 0) {
        return;
    }
    const int m = mode_.load();
    // fullWidth/fullHeight 来自 AVPlayer.width/height —— 已是"显示空间"尺寸
    // (实测: buffer 480x960 + rotation=90 的源, AVPlayer 报 960x480)。
    // 半区切分同样在显示空间进行 (见 FRAG_SRC), 因此这里直接对显示尺寸取半,
    // 不做宽高互换 —— 否则会与 shader 的切分空间不一致, 旋转时尺寸算错。
    int cw = fullWidth;
    int ch = fullHeight;
    if (m == 1 || m == 2) {
        cw = fullWidth / 2;
    } else if (m == 3 || m == 4) {
        ch = fullHeight / 2;
    }
    const int dispW = cw;
    const int dispH = ch;
    composedWidth_ = dispW;
    composedHeight_ = dispH;

    const int tw = targetWidth_.load();
    const int th = targetHeight_.load();
    if (tw <= 0 || th <= 0) {
        // 目标面几何未知: 不做缩放补偿 (quadScale=1), 但尺寸仍要对外上报
        OH_LOG_Print(LOG_APP, LOG_WARN, kLogDomain, kLogTag,
            "UpdateComposedSize: target geometry unknown (%{public}dx%{public}d), "
            "quad scale defaults to 1; composed %{public}dx%{public}d",
            tw, th, dispW, dispH);
        quadScaleX_ = 1.0f;
        quadScaleY_ = 1.0f;
        return;
    }
    const float contentAspect = static_cast<float>(dispW) / static_cast<float>(dispH);
    const float targetAspect = static_cast<float>(tw) / static_cast<float>(th);
    float sx = 1.0f;
    float sy = 1.0f;
    const int sm = scalingMode_.load();
    if (sm == 0) {
        // FIT: 完整显示内容, 不足方向留黑边
        if (contentAspect > targetAspect) {
            sy = targetAspect / contentAspect;
        } else {
            sx = contentAspect / targetAspect;
        }
    } else if (sm == 1) {
        // FILL: 铺满目标面, 超出部分裁切
        if (contentAspect > targetAspect) {
            sx = contentAspect / targetAspect;
        } else {
            sy = targetAspect / contentAspect;
        }
    }
    // sm == 2 (TO_FILL): 拉伸铺满, 不做缩放补偿
    quadScaleX_ = sx;
    quadScaleY_ = sy;
    OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag,
        "composed size %{public}dx%{public}d (full %{public}dx%{public}d mode=%{public}d) "
        "target %{public}dx%{public}d scale %{public}f x %{public}f scaling=%{public}d",
        cw, ch, fullWidth, fullHeight, m, tw, th,
        static_cast<double>(sx), static_cast<double>(sy), sm);
}

void AlphaCompositeRenderer::RequestRender() {
    // 帧回调在 AVPlayer 生产者线程, 此处只投递信号, 渲染在专用线程执行
    if (threadRunning_) {
        framePending_ = true;
        signalCv_.notify_one();
    }
}

void AlphaCompositeRenderer::RenderLoop() {
    // 渲染线程: GL 上下文在此线程建立并常驻; GL 资源(program/纹理/NativeImage)也在此创建
    if (!eglMakeCurrent(display_, eglSurface_, eglSurface_, eglContext_)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag,
            "render thread eglMakeCurrent failed 0x%{public}x", eglGetError());
        threadRunning_ = false;
        return;
    }
    if (!BuildProgram()) {
        threadRunning_ = false;
        return;
    }
    if (!SetupNativeImage()) {
        threadRunning_ = false;
        return;
    }
    // 通知等待离屏 surfaceId 的调用方 (getProducerSurfaceId)
    readyCv_.notify_all();
    OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "render thread started");
    while (threadRunning_) {
        std::unique_lock<std::mutex> lock(signalMutex_);
        signalCv_.wait(lock, [this] { return framePending_.load() || !threadRunning_.load(); });
        lock.unlock();
        if (!threadRunning_) {
            break;
        }
        framePending_ = false;
        Render();
    }
    eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "render thread exited");
}

int AlphaCompositeRenderer::GetVideoWidth() const { return videoWidth_; }
int AlphaCompositeRenderer::GetVideoHeight() const { return videoHeight_; }
int AlphaCompositeRenderer::GetComposedWidth() const { return composedWidth_; }
int AlphaCompositeRenderer::GetComposedHeight() const { return composedHeight_; }

uint64_t AlphaCompositeRenderer::GetProducerSurfaceId() const {
    // 渲染线程可能尚未创建完 NativeImage — 阻塞等待就绪 (最多 3s), 避免返回 0
    std::unique_lock<std::mutex> lock(readyMutex_);
    readyCv_.wait_for(lock, std::chrono::milliseconds(3000),
        [this] { return producerSurfaceId_ != 0 || !threadRunning_.load(); });
    return producerSurfaceId_;
}

void AlphaCompositeRenderer::Release() {
    if (!started_ && nativeImage_ == nullptr) {
        return;
    }
    // 先停渲染线程
    if (threadRunning_) {
        threadRunning_ = false;
        signalCv_.notify_all();
        if (renderThread_.joinable()) {
            renderThread_.join();
        }
    }
    std::lock_guard<std::mutex> lock(renderMutex_);
    if (nativeImage_ != nullptr) {
        OH_NativeImage_Destroy(&nativeImage_);
        nativeImage_ = nullptr;
        producerWindow_ = nullptr; // 随 NativeImage 一并释放
    }
    if (display_ != EGL_NO_DISPLAY) {
        if (eglSurface_ != EGL_NO_SURFACE) {
            eglDestroySurface(display_, eglSurface_);
            eglSurface_ = EGL_NO_SURFACE;
        }
        if (eglContext_ != EGL_NO_CONTEXT) {
            eglDestroyContext(display_, eglContext_);
            eglContext_ = EGL_NO_CONTEXT;
        }
        eglTerminate(display_);
        display_ = EGL_NO_DISPLAY;
    }
    if (targetWindow_ != nullptr) {
        OH_NativeWindow_DestroyNativeWindow(targetWindow_);
        targetWindow_ = nullptr;
    }
    if (vao_ != 0) { glDeleteVertexArrays(1, &vao_); vao_ = 0; }
    if (vbo_ != 0) { glDeleteBuffers(1, &vbo_); vbo_ = 0; }
    if (vboTex_ != 0) { glDeleteBuffers(1, &vboTex_); vboTex_ = 0; }
    if (program_ != 0) { glDeleteProgram(program_); program_ = 0; }
    started_ = false;
    OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "released");
}

} // namespace flutter_aliplayer
