// NAPI 桥接: ArkTS <-> AlphaCompositeRenderer
//
// ArkTS 侧用法:
//   import alphaCompositor from 'libalpha_compositor.so';
//   const handle = alphaCompositor.createRenderer(targetSurfaceId);
//   alphaCompositor.setMode(handle, mode);
//   const producerSurfaceId = alphaCompositor.getProducerSurfaceId(handle);
//   alphaCompositor.destroyRenderer(handle);
#include "AlphaCompositeRenderer.h"

#include <napi/native_api.h>

#include <map>
#include <mutex>

namespace {
std::mutex g_mutex;
uint64_t g_nextHandle = 1;
std::map<uint64_t, flutter_aliplayer::AlphaCompositeRenderer *> g_renderers;

flutter_aliplayer::AlphaCompositeRenderer *GetRenderer(uint64_t handle) {
    auto it = g_renderers.find(handle);
    return it == g_renderers.end() ? nullptr : it->second;
}

napi_value CreateRenderer(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        napi_throw_error(env, nullptr, "createRenderer requires targetSurfaceId");
        return nullptr;
    }
    // ArkTS 传入 string (surfaceId 可能超出 JS 安全整数范围)
    char surfaceIdStr[64] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], surfaceIdStr, sizeof(surfaceIdStr), &len);
    uint64_t targetSurfaceId = strtoull(surfaceIdStr, nullptr, 10);

    // 可选第二参数: OHNativeWindow* 指针 (Texture 路径, 引擎窗口不能经 surfaceId 重建)
    OHNativeWindow *externalWindow = nullptr;
    if (argc >= 2 && args[1] != nullptr) {
        char winPtrStr[32] = {0};
        size_t wlen = 0;
        napi_get_value_string_utf8(env, args[1], winPtrStr, sizeof(winPtrStr), &wlen);
        if (wlen > 0) {
            externalWindow = reinterpret_cast<OHNativeWindow *>(strtoull(winPtrStr, nullptr, 10));
        }
    }

    flutter_aliplayer::AlphaCompositeRenderer *renderer =
        externalWindow != nullptr ? new flutter_aliplayer::AlphaCompositeRenderer(externalWindow)
                                  : new flutter_aliplayer::AlphaCompositeRenderer(targetSurfaceId);
    if (!renderer->Start()) {
        delete renderer;
        napi_throw_error(env, nullptr, "AlphaCompositeRenderer start failed");
        return nullptr;
    }
    uint64_t handle = 0;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        handle = g_nextHandle++;
        g_renderers[handle] = renderer;
    }
    char handleStr[32] = {0};
    snprintf(handleStr, sizeof(handleStr), "%llu", static_cast<unsigned long long>(handle));
    napi_value result = nullptr;
    napi_create_string_utf8(env, handleStr, NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value SetMode(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 2) {
        napi_throw_error(env, nullptr, "setMode requires handle and mode");
        return nullptr;
    }
    char handleStr[32] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], handleStr, sizeof(handleStr), &len);
    uint32_t mode = 0;
    napi_get_value_uint32(env, args[1], &mode);

    auto *renderer = GetRenderer(strtoull(handleStr, nullptr, 10));
    if (renderer != nullptr) {
        renderer->SetMode(static_cast<int>(mode));
    }
    napi_value undefined = nullptr;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value SetVideoSize(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr, nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 3) {
        napi_throw_error(env, nullptr, "setVideoSize requires handle, width and height");
        return nullptr;
    }
    char handleStr[32] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], handleStr, sizeof(handleStr), &len);
    int32_t width = 0;
    int32_t height = 0;
    napi_get_value_int32(env, args[1], &width);
    napi_get_value_int32(env, args[2], &height);

    auto *renderer = GetRenderer(strtoull(handleStr, nullptr, 10));
    if (renderer != nullptr) {
        renderer->SetVideoSize(width, height);
    }
    napi_value undefined = nullptr;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value SetScalingMode(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 2) {
        napi_throw_error(env, nullptr, "setScalingMode requires handle and mode");
        return nullptr;
    }
    char handleStr[32] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], handleStr, sizeof(handleStr), &len);
    uint32_t mode = 0;
    napi_get_value_uint32(env, args[1], &mode);

    auto *renderer = GetRenderer(strtoull(handleStr, nullptr, 10));
    if (renderer != nullptr) {
        renderer->SetScalingMode(static_cast<int>(mode));
    }
    napi_value undefined = nullptr;
    napi_get_undefined(env, &undefined);
    return undefined;
}

/** 合成后(可见内容)尺寸, 逗号分隔 "宽,高" — ArkTS 侧无 BigInt 需求, 但避免多返回值 */
napi_value GetComposedSize(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        napi_throw_error(env, nullptr, "getComposedSize requires handle");
        return nullptr;
    }
    char handleStr[32] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], handleStr, sizeof(handleStr), &len);
    auto *renderer = GetRenderer(strtoull(handleStr, nullptr, 10));
    if (renderer == nullptr) {
        napi_throw_error(env, nullptr, "renderer not found");
        return nullptr;
    }
    char sizeStr[32] = {0};
    snprintf(sizeStr, sizeof(sizeStr), "%d,%d",
        renderer->GetComposedWidth(), renderer->GetComposedHeight());
    napi_value result = nullptr;
    napi_create_string_utf8(env, sizeStr, NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value GetProducerSurfaceId(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        napi_throw_error(env, nullptr, "getProducerSurfaceId requires handle");
        return nullptr;
    }
    char handleStr[32] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], handleStr, sizeof(handleStr), &len);
    auto *renderer = GetRenderer(strtoull(handleStr, nullptr, 10));
    if (renderer == nullptr) {
        napi_throw_error(env, nullptr, "renderer not found");
        return nullptr;
    }
    char surfaceIdStr[32] = {0};
    snprintf(surfaceIdStr, sizeof(surfaceIdStr), "%llu",
        static_cast<unsigned long long>(renderer->GetProducerSurfaceId()));
    napi_value result = nullptr;
    napi_create_string_utf8(env, surfaceIdStr, NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value DestroyRenderer(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        return nullptr;
    }
    char handleStr[32] = {0};
    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], handleStr, sizeof(handleStr), &len);
    uint64_t handle = strtoull(handleStr, nullptr, 10);
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        auto it = g_renderers.find(handle);
        if (it != g_renderers.end()) {
            delete it->second;
            g_renderers.erase(it);
        }
    }
    napi_value undefined = nullptr;
    napi_get_undefined(env, &undefined);
    return undefined;
}
} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"createRenderer", nullptr, CreateRenderer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setMode", nullptr, SetMode, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setVideoSize", nullptr, SetVideoSize, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setScalingMode", nullptr, SetScalingMode, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getComposedSize", nullptr, GetComposedSize, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getProducerSurfaceId", nullptr, GetProducerSurfaceId, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroyRenderer", nullptr, DestroyRenderer, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module alphaCompositorModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "alpha_compositor",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterAlphaCompositorModule(void) {
    napi_module_register(&alphaCompositorModule);
}
