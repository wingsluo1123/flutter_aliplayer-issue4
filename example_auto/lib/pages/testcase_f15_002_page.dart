
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F15-002：能取消预加载任务并停止预取
class TestCaseF15002Page extends StatefulWidget {
  const TestCaseF15002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF15002Page> createState() => _TestCaseF15002PageState();
}

class _TestCaseF15002PageState extends State<TestCaseF15002Page> {
  String _result = '';
  final TextEditingController _taskUrlController = TextEditingController(
    text:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  );
  late final FlutterAliPlayerMediaLoader _mediaLoader;

  @override
  void initState() {
    super.initState();
    _mediaLoader = FlutterAliPlayerMediaLoader();
    _mediaLoader.setOnCancel((String url) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _result = 'onCancel 回调触发\nurl: $url\n任务状态: 已取消';
        });
      });
    });
  }

  @override
  void dispose() {
    _taskUrlController.dispose();
    super.dispose();
  }

  void _cancelTask() {
    final String url = _taskUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = '请输入任务 URL';
      });
      return;
    }
    try {
      _mediaLoader.load(url, 10000);
      _mediaLoader.cancel(url);
      setState(() {
        _result = 'cancel 调用成功\n'
            '任务 URL: $url\n'
            '任务状态: 已取消\n'
            '等待 onCancel 回调触发以确认预取已停止';
      });
    } catch (e) {
      setState(() {
        _result = 'error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F15-002 能取消预加载任务并停止预取')),
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
                          Text('前置条件: 应用已启动；已有正在进行的预加载任务'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【任务列表】中选择目标任务 (API: cancel/cancelTask, taskId: 目标任务) [验证点: 验证目标任务被高亮选中]; 2. 点击【取消任务】按钮 (API: cancel/cancelTask) [验证点: 验证任务状态变为"已取消"且 onCancel 回调触发]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 取消预加载任务后预取停止，onCancel 回调触发'),
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
                  TextField(
                    key: const Key('input_task_url'),
                    controller: _taskUrlController,
                    decoration: const InputDecoration(
                      labelText: '任务 URL 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_cancel_task'),
                    onPressed: _cancelTask,
                    child: const Text('取消任务'),
                  ),
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
