
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F02-003：倍速切换后播放节奏可即时变化
class TestCaseF02003Page extends StatefulWidget {
  const TestCaseF02003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF02003Page> createState() => _TestCaseF02003PageState();
}

class _TestCaseF02003PageState extends State<TestCaseF02003Page> {
  String _result = '';

  // TODO(import): 添加插件 import，例如 import 'package:xxx/xxx.dart';

  // TODO(init): 如果本模块需要初始化实例（如 FToast().init(context)），在此声明并初始化。

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F02-003 倍速切换后播放节奏可即时变化')),
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
                          Text('前置条件: 应用已启动；单播放器已经成功起播。'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【1.5x】选项 (API: setSpeed) [验证点: 验证【1.5x】选项进入选中状态。]; 2. 观察视频播放节奏 [验证点: 验证画面推进速度快于正常速度，日志出现设置倍速成功记录。]; 3. 点击【1.0x】选项 (API: setSpeed) [验证点: 验证视频恢复正常节奏，且【1.0x】重新选中。]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 倍速选项切换后能立即影响播放速度，并支持恢复到正常速率。'),
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
