import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F10-001：对播放中的视频进行截图
class TestCaseF10001Page extends StatefulWidget {
  const TestCaseF10001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF10001Page> createState() => _TestCaseF10001PageState();
}

class _TestCaseF10001PageState extends State<TestCaseF10001Page> {
  FlutterAliplayer? _player;
  String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _pathCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _createPlayer();
  }

  Future<void> _createPlayer() async {
    try { _player = FlutterAliPlayerFactory.createAliPlayer(); await _player!.create(); setState(() { _result = '播放器已创建'; }); } catch (e) { }
  }

  Future<void> _setUrlAndPlay() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    try { await _player!.setUrl(url); await _player!.prepare(); await _player!.play(); setState(() { _result = '播放中'; }); } catch (e) { }
  }

  Future<void> _snapshot() async {
    try {
      final path = _pathCtrl.text.trim();
      final result = await _player!.snapshot(path);
      setState(() { _result = '截图结果: $result'; });
    } catch (e) { setState(() { _result = '截图失败: $e'; }); }
  }

  @override
  void dispose() { _player?.release(); _urlCtrl.dispose(); _pathCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F10-001 对播放中的视频进行截图')),
      body: Column(children: [
        Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('前置条件: 应用已启动，播放器正在播放视频'), Text('预期结果: 截图成功，指定路径下生成了截图文件'),
          ]))),
          const SizedBox(height: 8),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '视频URL', isDense: true)),
          ElevatedButton(key: const Key('btn_set_url'), onPressed: _setUrlAndPlay, child: const Text('设置URL并播放')),
          const SizedBox(height: 8),
          TextField(controller: _pathCtrl, decoration: const InputDecoration(labelText: '截图保存路径', isDense: true)),
          ElevatedButton(key: const Key('btn_snapshot'), onPressed: _snapshot, child: const Text('截图')),
        ]))),
        Expanded(flex: 2, child: ResultPanel(result: _result)),
      ]),
    );
  }
}
