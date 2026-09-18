cmake_minimum_required(VERSION 3.5.0)
project(alpha_compositor)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(alpha_compositor SHARED
        AlphaCompositeRenderer.cpp
        AlphaCompositorNapi.cpp)

# OHOS NDK: native_window / native_image / EGL / GLES / napi
find_library(hilog-lib hilog_ndk.z)
find_library(EGL-lib EGL)
find_library(GLES-lib GLESv3)
find_library(ace-lib ace_ndk.z)
find_library(napi-lib ace_napi.z)

target_link_libraries(alpha_compositor PUBLIC
        ${hilog-lib}
        ${EGL-lib}
        ${GLES-lib}
        ${ace-lib}
        ${napi-lib}
        libnative_window.so
        libnative_image.so)
