
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F03-002：自定义资源可加入列表并被点选播放
class TestCaseF03002Page extends StatefulWidget {
  const TestCaseF03002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF03002Page> createState() => _TestCaseF03002PageState();
}

class _TestCaseF03002PageState extends State<TestCaseF03002Page> {
  String _result = '';

  // TODO(import): 添加插件 import，例如 import 'package:xxx/xxx.dart';

  // TODO(init): 如果本模块需要初始化实例（如 FToast().init(context)），在此声明并初始化。

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F03-002 自定义资源可加入列表并被点选播放')),
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
                          Text('前置条件: 应用已启动；【列表播放器】页签已打开；列表播放器已创建。'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【视频URL地址】输入框中输入有效地址，在【资源UID】输入框中输入自定义标识 [验证点: 验证两个输入框都显示刚输入的内容。]; 2. 点击【添加到列表】按钮 (API: addUrlSource) [验证点: 验证【播放列表】区域新增一条与输入内容对应的资源记录。]; 3. 点击新增的资源记录 [验证点: 验证该记录进入选中状态，并开始准备或进入播放状态。]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 列表播放器可以接收用户添加的自定义播放源，并支持点选播放。'),
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
