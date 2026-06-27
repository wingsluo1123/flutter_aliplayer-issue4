import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F11-001：添加外挂字幕文件到播放器
class TestCaseF11001Page extends StatefulWidget {
  const TestCaseF11001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF11001Page> createState() => _TestCaseF11001PageState();
}

class _TestCaseF11001PageState extends State<TestCaseF11001Page> {
  FlutterAliplayer? _player; String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _subtitleUrlCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _createPlayer(); }

  Future<void> _createPlayer() async {
    try { _player = FlutterAliPlayerFactory.createAliPlayer(); await _player!.create(); setState(() { _result = '播放器已创建'; }); } catch (e) { }
  }

  Future<void> _setupAndPlay() async {
    try { await _player!.setUrl(_urlCtrl.text.trim()); await _player!.prepare(); await _player!.play(); setState(() { _result = '播放中'; }); } catch (e) { }
  }

  Future<void> _addSubtitle() async {
    try { await _player!.addExtSubtitle(_subtitleUrlCtrl.text.trim()); setState(() { _result = '字幕加载成功'; }); } catch (e) { setState(() { _result = '添加字幕失败: $e'; }); }
  }

  @override
  void dispose() { _player?.release(); _urlCtrl.dispose(); _subtitleUrlCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F11-001 添加外挂字幕文件到播放器')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，播放器正在播放视频'), Text('预期结果: 字幕加载成功，收到外挂字幕添加回调'),
        ]))),
        TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '视频URL', isDense: true)),
        ElevatedButton(key: const Key('btn_setup'), onPressed: _setupAndPlay, child: const Text('设置URL并播放')),
        const SizedBox(height: 8),
        TextField(controller: _subtitleUrlCtrl, decoration: const InputDecoration(labelText: '字幕URL', isDense: true)),
        ElevatedButton(key: const Key('btn_add_subtitle'), onPressed: _addSubtitle, child: const Text('添加字幕')),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
