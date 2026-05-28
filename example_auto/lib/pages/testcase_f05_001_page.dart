
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F05-001：拖动音量并切换静音后声音状态正确变化
class TestCaseF05001Page extends StatefulWidget {
  const TestCaseF05001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF05001Page> createState() => _TestCaseF05001PageState();
}

class _TestCaseF05001PageState extends State<TestCaseF05001Page> {
  String _result = '';

  // TODO(import): 添加插件 import，例如 import 'package:xxx/xxx.dart';

  // TODO(init): 如果本模块需要初始化实例（如 FToast().init(context)），在此声明并初始化。

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F05-001 拖动音量并切换静音后声音状态正确变化')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    '测试信息',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('优先级: L0'),
                          const SizedBox(height: 4),
                          Text('前置条件: 应用已启动；单播放器已成功起播；设备媒体音量可用。'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【音量控制】区域拖动【音量滑块】到中间位置 (API: setVolume) [验证点: 验证滑块右侧的数值文本更新为接近 1.00 的新值。]; 2. 点击【静音】图标按钮 (API: setMuted) [验证点: 验证图标切换为静音状态，视频声音消失。]; 3. 再次点击【静音】图标按钮 [验证点: 验证图标恢复为有声状态，视频声音重新出现。]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 音量滑块与静音开关都能立即影响播放器的声音输出状态。'),
                          const SizedBox(height: 4),
                          Text('后置条件: '),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  // TODO(actions): 根据测试用例的步骤，填充相应的操作按钮：
                  //
                  // ■ API 类操作 → 用 ElevatedButton 包装，按钮文字要表明测试点，
                  //   点击后调用对应 API，并 setState 更新 _result。
                  //
                  // ■ UI 类操作 → 直接在此处放置该 Widget，
                  //   必要时把交互回调/可验证状态写入 _result。
                  //
                  // ■ build 期间的回调中的 setState() 调用时机（重要）：
                  //   如 loadStateChanged、builder 等在 widget build 阶段同步执行的回调，
                  //   若需更新状态，必须使用 WidgetsBinding.instance.addPostFrameCallback
                  //   延迟到帧渲染完成后执行，否则会触发 "setState() called during build" 异常。
                  //
                  // 示例（API 类）:
                  //   ElevatedButton(
                  //     key: const Key('btn_show_toast'),
                  //     onPressed: () async {
                  //       try {
                  //         final res = await SomePlugin.someApi(arg: value);
                  //         setState(() { _result = res.toString(); });
                  //       } catch (e) {
                  //         setState(() { _result = 'error: ' + e.toString(); });
                  //       }
                  //     },
                  //     child: const Text('执行测试'),
                  //   ),
                  //
                  // 示例（UI 类 - build 期间回调）:
                  //   ExtendedImage.network(
                  //     url,
                  //     loadStateChanged: (state) {
                  //       if (state.extendedImageLoadState == LoadState.completed) {
                  //         // ❌ 错误：build 期间直接调用 setState
                  //         // setState(() { _result = '成功'; });
                  //         // ✅ 正确：延迟到帧渲染完成后执行
                  //         WidgetsBinding.instance.addPostFrameCallback((_) {
                  //           setState(() { _result = '成功'; });
                  //         });
                  //       }
                  //     },
                  //   ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ResultPanel(result: _result),
          ),
        ],
      ),
    );
  }
}
