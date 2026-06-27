import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F21-001：设置视频锐化滤镜配置
class TestCaseF21001Page extends StatefulWidget {
  const TestCaseF21001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF21001Page> createState() => _TestCaseF21001PageState();
}

class _TestCaseF21001PageState extends State<TestCaseF21001Page> {
  FlutterAliplayer? _player; String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _filterCtrl = TextEditingController(text: '{"sharp":"enable"}');

  @override
  void initState() { super.initState(); _createPlayer(); }

  Future<void> _createPlayer() async {
    try { _player = FlutterAliPlayerFactory.createAliPlayer(); await _player!.create(); setState(() { _result = '播放器已创建'; }); } catch (e) { }
  }

  Future<void> _setupAndPlay() async {
    try { await _player!.setUrl(_urlCtrl.text.trim()); await _player!.prepare(); await _player!.play(); setState(() { _result = '播放中'; }); } catch (e) { }
  }

  Future<void> _setFilter() async {
    try {
      await _player!.setFilterConfig(_filterCtrl.text.trim());
      setState(() { _result = '滤镜已应用'; });
    } catch (e) { setState(() { _result = '滤镜设置失败: $e'; }); }
  }

  @override
  void dispose() { _player?.release(); _urlCtrl.dispose(); _filterCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F21-001 设置视频锐化滤镜配置')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，播放器正在播放视频'), Text('预期结果: 视频画面应用锐化效果，边缘清晰度提升'),
        ]))),
        TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '视频URL', isDense: true)),
        ElevatedButton(key: const Key('btn_setup'), onPressed: _setupAndPlay, child: const Text('设置URL并播放')),
        const SizedBox(height: 8),
        TextField(controller: _filterCtrl, decoration: const InputDecoration(labelText: '滤镜配置JSON', isDense: true)),
        ElevatedButton(key: const Key('btn_set_filter'), onPressed: _setFilter, child: const Text('应用滤镜')),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
