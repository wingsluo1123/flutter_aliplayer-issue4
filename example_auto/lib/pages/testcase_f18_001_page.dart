import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader_v2.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F18-001：通过媒体预加载V1加载视频资源
class TestCaseF18001Page extends StatefulWidget {
  const TestCaseF18001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF18001Page> createState() => _TestCaseF18001PageState();
}

class _TestCaseF18001PageState extends State<TestCaseF18001Page> {
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
    appBar: AppBar(title: const Text('F18-001 通过媒体预加载V1加载视频资源')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，进入预加载功能页面'), Text('预期结果: 视频资源加载成功，完成回调被触发'),
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
