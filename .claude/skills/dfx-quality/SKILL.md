---
name: dfx-quality
description: |
  对 Flutter 插件鸿蒙适配做 DFX 质量检测，从【稳定性】【性能】【功耗】【UX】【兼容性】五大维度审查。
  C1 稳定性（Platform.isOhos构建风险、Controller/ETS资源释放配对、FlutterEntry生命周期、日志规范）、
  C2 性能（addListener空setState、列表用builder+keepAlives、大图ResizeImage、deactivate stop动画）、
  C3 功耗（Timer/StreamSubscription未cancel、EngineBindings未detach）、
  C4 UX（跨层viewType/Channel一致、Dart侧生命周期配对、TextStyle极端色）、
  C5 兼容性（compatibleSdkVersion与API用法一致、canIUse/syscap守护、deviceTypes与实现一致、SemVer）。
  使用检测脚本（--dry-run 模式）自动化扫描 + agent 逐项核对，只检测不修复，
  输出按 🔴/🟡/🟢 分级、含 file:line 的发现清单。
  适用于（Use when）：Flutter 插件鸿蒙适配 DFX 质量检测、稳定性检测、性能检测、功耗检测、UX 质量检测、兼容性检测
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash      # 运行检测脚本（--dry-run 模式，只读分析，不修改被评估库）
---

# 鸿蒙 DFX 质量检测

对 Flutter 插件鸿蒙适配做 DFX 质量检测，涵盖稳定性、性能、功耗、UX、兼容性五大维度。本 Skill 只检测、**只读**——绝不修改被评估库。

**Dart + ETS 双端扫描是本 Skill 的核心机制**：脚本同时扫描 `lib/**/*.dart` 和 `ohos/**/*.ets`，覆盖跨层资源释放、生命周期配对、Channel 一致性等 Flutter 特有问题。

## 何时使用本 Skill

- 评估 / 验收 Flutter 插件鸿蒙适配的 DFX 质量（稳定性、性能、功耗、UX、兼容性）

## 五大维度

| 维度 | 子维度 | 覆盖 | 适用端 | 检测方式 |
|------|------|------|:--:|------|
| **C. DFX 质量** | **C1 稳定性** | Platform.isOhos构建风险、Controller dispose配对、ETS端资源释放配对、FlutterEntry生命周期配对、日志规范 | Dart+ETS | dfx_dart.py + dfx_ets.py + agent 核对 |
| | **C2 性能** | addListener空setState、列表用builder+keepAlives、大图ResizeImage、deactivate中stop动画 | Dart | dfx_dart.py + agent 核对 |
| | **C3 功耗** | Timer/StreamSubscription未cancel、EngineBindings未detach | Dart+ETS | dfx_dart.py + dfx_ets.py + agent 核对 |
| | **C4 UX** | 跨层viewType/Channel一致、Dart侧生命周期配对、TextStyle极端色 | Dart+ETS | dfx_channel_consistency.py + dfx_dart.py + agent 核对 |
| | **C5 兼容性** | compatibleSdkVersion与API用法一致、canIUse/syscap守护、deviceTypes与实现一致、SemVer | ETS | agent 核对 |

> Flutter Dart 侧性能问题不被 B1 覆盖，仍需本 Skill 检测。

## 严重级别（沿用统一标记，勿自创同义词）

- 🔴 `[blocking]` 必须修复——存在严重缺陷，必须修复
- 🟡 `[important]` 应当修复——明显问题，建议修复
- 🟢 `[nit]` 可选优化——不阻塞
- 💡 `[suggestion]` 替代方案 / 改进思路（含 Grep 粗查得到的启发式线索）

> 🔴/🟡/🟢 为标准三档（由红到绿），💡 为非阻塞注解。
> **本 Skill 不打分、不加权、不评 A–E 等级**；总体结论为定性判断。

## 自动化检测脚本

使用检测脚本（`--dry-run` 模式）对 `ohos/` 和 `lib/` 做自动化扫描，再对脚本无法覆盖的问题由 agent 逐项核对。

| 脚本 | 扫描目标 | 检测项 |
|------|---------|--------|
| `scripts/dfx_dart.py` | `lib/**/*.dart`（支持多目录`--target`） | Platform.isOhos风险、Controller dispose、addListener空setState、ListView非builder、大图未ResizeImage/cacheWidth、Timer未cancel、print残留、TextStyle极端色 |
| `scripts/dfx_ets.py` | `ohos/**/*.ets` | PlatformView dispose为空、onDetachedFromEngine为空、Texture未unregister、FlutterEntry生命周期、EngineBindings未detach、console.log |
| `scripts/dfx_channel_consistency.py` | Dart+ETS | 跨层viewType/Channel名称一致性比对 |

```bash
python scripts/dfx_dart.py --target <dart_dir> --dry-run
python scripts/dfx_ets.py --target <ets_dir> --dry-run
python scripts/dfx_channel_consistency.py --dart-target <dart_dir> --ets-target <ets_dir>
```

退出码：0=通过，1=目录不存在，2=有未处理告警。

## C1 稳定性

（Dart+ETS 双端 · 脚本 + agent 核对）

| 检查项 | 检测方式 | 级别 |
|--------|---------|:--:|
| Platform.isOhos构建风险 | dfx_dart.py | 🟡 |
| AnimationController dispose配对 | dfx_dart.py | 🔴 |
| StreamController close配对 | dfx_dart.py | 🔴 |
| ETS端PlatformView dispose资源释放 | dfx_ets.py | 🔴 |
| ETS端FlutterPlugin onDetachedFromEngine资源释放 | dfx_ets.py | 🔴 |
| ETS端Texture register/unregister配对 | dfx_ets.py | 🔴 |
| FlutterEntry生命周期配对（aboutToAppear/Disappear、onPageShow/Hide） | dfx_dart.py + dfx_ets.py | 🟡 |
| 日志规范（Dart print→debugPrint、ETS console.log→移除） | dfx_dart.py + dfx_ets.py | 🟡 |

## C2 性能

（Dart 端 · 脚本 + agent 核对）

| 检查项 | 检测方式 | 级别 |
|--------|---------|:--:|
| addListener空setState反模式 | dfx_dart.py | 🟡 |
| ListView/GridView未用builder构造 | dfx_dart.py | 🟡 |
| 大图未用ResizeImage或cacheWidth | dfx_dart.py | 🟡 |
| ListView.builder缺addAutomaticKeepAlives:false | dfx_dart.py | 🟢 |
| deactivate中未stop动画 | dfx_dart.py | 🟡 |

## C3 功耗

（Dart+ETS 双端 · 脚本 + agent 核对）

| 检查项 | 检测方式 | 级别 |
|--------|---------|:--:|
| Timer/StreamSubscription未cancel | dfx_dart.py | 🔴 |
| EngineBindings.attach()未detach() | dfx_ets.py | 🔴 |

## C4 UX

（Dart+ETS 双端 · 脚本 + agent 核对）

| 检查项 | 检测方式 | 级别 |
|--------|---------|:--:|
| 跨层viewType一致（Dart OhosView vs ETS registerViewFactory） | dfx_channel_consistency.py | 🔴 |
| 跨层Channel名称一致（Dart MethodChannel vs ETS MethodChannel） | dfx_channel_consistency.py | 🔴 |
| Dart侧生命周期配对（aboutToAppear/Disappear） | dfx_dart.py | 🟡 |
| TextStyle极端色（Colors.black/white） | dfx_dart.py | 🟢 |

## C5 兼容性

（ETS 端 · agent 核对）

| 检查项 | 检测方式 | 级别 |
|--------|---------|:--:|
| compatibleSdkVersion 与 API 用法一致（无 canIUse 守护的高版本 API 调用） | agent 核对 | 🔴 |
| canIUse/syscap 守护（受限 API 有运行时探测与降级路径） | agent 核对 | 🟡 |
| deviceTypes 与实现一致（声明支持的设备形态与实际能力相符） | agent 核对 | 🟡 |
| version 遵循 SemVer（破坏性变更经 @deprecated 过渡） | agent 核对 | 🟡 |
