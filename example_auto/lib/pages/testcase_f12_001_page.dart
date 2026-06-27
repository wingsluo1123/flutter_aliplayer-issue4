import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F12-001：创建缩略图辅助工具
class TestCaseF12001Page extends StatefulWidget {
  const TestCaseF12001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF12001Page> createState() => _TestCaseF12001PageState();
}

class _TestCaseF12001PageState extends State<TestCaseF12001Page> {
  FlutterAliplayer? _player; String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _createPlayer(); }

  Future<void> _createPlayer() async {
    try { _player = FlutterAliPlayerFactory.createAliPlayer(); await _player!.create(); setState(() { _result = '播放器已创建'; }); } catch (e) { }
  }

  Future<void> _createThumbnailHelper() async {
    try {
      final url = _urlCtrl.text.trim();
      final result = await _player!.createThumbnailHelper(url);
      setState(() { _result = '缩略图工具已创建: $result'; });
    } catch (e) { setState(() { _result = '创建缩略图工具失败: $e'; }); }
  }

  @override
  void dispose() { _player?.release(); _urlCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F12-001 创建缩略图辅助工具')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，已设置视频源'), Text('预期结果: 缩略图辅助工具创建成功，准备就绪回调被触发'),
        ]))),
        TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '视频URL或VID', isDense: true)),
        ElevatedButton(key: const Key('btn_create_thumbnail'), onPressed: _createThumbnailHelper, child: const Text('创建缩略图工具')),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
