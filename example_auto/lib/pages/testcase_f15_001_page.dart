
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F15-001：能添加预加载任务并开始预取媒体数据
class TestCaseF15001Page extends StatefulWidget {
  const TestCaseF15001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF15001Page> createState() => _TestCaseF15001PageState();
}

class _TestCaseF15001PageState extends State<TestCaseF15001Page> {
  String _result = '';
  final TextEditingController _urlController = TextEditingController(
    text:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  );
  final TextEditingController _durationController = TextEditingController(text: '10000');
  final List<Map<String, String>> _taskList = <Map<String, String>>[];
  late final FlutterAliPlayerMediaLoader _mediaLoader;

  @override
  void initState() {
    super.initState();
    _mediaLoader = FlutterAliPlayerMediaLoader();
    _mediaLoader.setOnLoadStatusListener(
      (String url) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _result = 'onCompletion 回调触发\nurl: $url\n任务状态: 已完成';
          });
        });
      },
      (String url) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _result = 'onCancel 回调触发\nurl: $url\n任务状态: 已取消';
          });
        });
      },
      (String url, int code, String msg) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _result = 'onError 回调触发\nurl: $url\ncode: $code\nmsg: $msg';
          });
        });
      },
      (String url, String code, String msg) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _result = 'onErrorV2 回调触发\nurl: $url\ncode: $code\nmsg: $msg';
          });
        });
      },
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _addTask() {
    final String url = _urlController.text.trim();
    final String durationStr = _durationController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = '请输入视频 URL';
      });
      return;
    }
    final int duration = int.tryParse(durationStr) ?? 10000;
    try {
      _mediaLoader.load(url, duration);
      _taskList.add(<String, String>{
        'url': url,
        'duration': duration.toString(),
        'status': '预加载中',
      });
      final StringBuffer sb = StringBuffer();
      sb.writeln('load 调用成功');
      sb.writeln('任务状态: 预加载中');
      sb.writeln('url: $url');
      sb.writeln('duration: $duration');
      sb.writeln('---- 任务列表 ----');
      for (int i = 0; i < _taskList.length; i++) {
        sb.writeln('${i + 1}. ${_taskList[i]['url']} (${_taskList[i]['status']})');
      }
      sb.writeln('等待 onCompletion/onCancel/onError 回调触发');
      setState(() {
        _result = sb.toString();
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
      appBar: AppBar(title: const Text('F15-001 能添加预加载任务并开始预取媒体数据')),
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
                          Text('前置条件: 应用已启动；预加载演示页面已打开；有可用的视频 URL'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【URL 输入框】中输入视频地址，在【预取时长输入框】中输入"10000" (API: load, url: 视频URL, duration: 10000) [验证点: 验证两个输入框分别显示对应值]; 2. 点击【添加预加载任务】按钮 (API: load) [验证点: 验证【任务列表】中出现新任务条目且状态为"预加载中"]; 3. 等待 2 秒 [验证点: 验证回调触发且任务状态保持"预加载中"或变为"已完成"]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 添加预加载任务后开始预取媒体数据，任务状态正确且回调触发'),
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
                    key: const Key('input_url'),
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_duration'),
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '预取时长输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_add_task'),
                    onPressed: _addTask,
                    child: const Text('添加预加载任务'),
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
