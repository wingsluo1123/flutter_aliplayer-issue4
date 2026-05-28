
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F12-001：尝试开启悬浮窗时会给出明确的降级提示
class TestCaseF12001Page extends StatefulWidget {
  const TestCaseF12001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF12001Page> createState() => _TestCaseF12001PageState();
}

class _TestCaseF12001PageState extends State<TestCaseF12001Page> {
  String _result = '';

  // TODO(import): 添加插件 import，例如 import 'package:xxx/xxx.dart';

  // TODO(init): 如果本模块需要初始化实例（如 FToast().init(context)），在此声明并初始化。

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F12-001 尝试开启悬浮窗时会给出明确的降级提示')),
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
                          Text('前置条件: 应用已启动；测试版本包含【悬浮窗播放】演示入口。'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 打开【悬浮窗播放】演示区域，点击【悬浮窗播放】按钮 (API: showFloatViewForAndroid) [验证点: 验证页面出现当前平台不支持悬浮窗或等价提示。]; 2. 观察当前视频区域 [验证点: 验证主界面的播放状态保持不变，没有出现异常中断。]; 3. 关闭提示并再次观察控制区域 [验证点: 验证页面仍可继续进行普通播放操作。]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 当设备不支持悬浮窗能力时，应用会明确告知用户并保持普通播放链路可用。'),
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
