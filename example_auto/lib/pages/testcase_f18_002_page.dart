import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader_v2.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F18-002：通过媒体预加载V2添加URL任务
class TestCaseF18002Page extends StatefulWidget {
  const TestCaseF18002Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF18002Page> createState() => _TestCaseF18002PageState();
}

class _TestCaseF18002PageState extends State<TestCaseF18002Page> {
  String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();

  Future<void> _preloadV1() async {
    try {
      final loader = FlutterAliPlayerMediaLoader();
      final url = _urlCtrl.text.trim();
      loader.load(url, 30000);
      setState(() { _result = 'V1预加载完成'; });
    } catch (e) { setState(() { _result = 'V1预加载失败: $e'; }); }
  }

  Future<void> _preloadV2() async {
    try {
      final loader = FlutterAliMediaLoaderV2();
      loader.addUrlTask(videoSource: _urlCtrl.text.trim());
      setState(() { _result = 'V2预加载任务已添加'; });
    } catch (e) { setState(() { _result = 'V2预加载失败: $e'; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F18-002 通过媒体预加载V2添加URL任务')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，进入预加载V2页面'), Text('预期结果: 预加载任务添加成功，加载正常进行'),
        ]))),
        TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '资源URL', isDense: true)),
        ElevatedButton(key: const Key('btn_preload_v1'), onPressed: _preloadV1, child: const Text('V1预加载')),
        const SizedBox(height: 8),
        ElevatedButton(key: const Key('btn_preload_v2'), onPressed: _preloadV2, child: const Text('V2添加任务')),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
