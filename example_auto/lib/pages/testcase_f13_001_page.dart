import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F13-001：获取视频媒体信息包含Track列表
class TestCaseF13001Page extends StatefulWidget {
  const TestCaseF13001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF13001Page> createState() => _TestCaseF13001PageState();
}

class _TestCaseF13001PageState extends State<TestCaseF13001Page> {
  FlutterAliplayer? _player; String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _createPlayer(); }

  Future<void> _createPlayer() async {
    try { _player = FlutterAliPlayerFactory.createAliPlayer(); await _player!.create(); setState(() { _result = '播放器已创建'; }); } catch (e) { }
  }

  Future<void> _setupAndPlay() async {
    try { await _player!.setUrl(_urlCtrl.text.trim()); await _player!.prepare(); await _player!.play(); setState(() { _result = '播放中'; }); } catch (e) { }
  }

  Future<void> _getMediaInfo() async {
    try {
      final info = await _player!.getMediaInfo();
      setState(() { _result = '媒体信息: $info'; });
    } catch (e) { setState(() { _result = '获取媒体信息失败: $e'; }); }
  }

  Future<void> _selectTrack(int trackIdx) async {
    try {
      await _player!.selectTrack(trackIdx);
      setState(() { _result = '已切换到轨道: $trackIdx'; });
    } catch (e) { setState(() { _result = '切换轨道失败: $e'; }); }
  }

  @override
  void dispose() { _player?.release(); _urlCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F13-001 获取视频媒体信息包含Track列表')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，播放器正在播放多码率视频'), Text('预期结果: 媒体信息中包含视频、音频、字幕等Track信息'),
        ]))),
        TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '视频URL', isDense: true)),
        ElevatedButton(key: const Key('btn_setup'), onPressed: _setupAndPlay, child: const Text('设置URL并播放')),
        const SizedBox(height: 8),
        ElevatedButton(key: const Key('btn_get_media_info'), onPressed: _getMediaInfo, child: const Text('获取媒体信息')),
        const SizedBox(height: 8),
        ElevatedButton(key: const Key('btn_select_track_0'), onPressed: () => _selectTrack(0), child: const Text('切换到轨道0')),
        ElevatedButton(key: const Key('btn_select_track_1'), onPressed: () => _selectTrack(1), child: const Text('切换到轨道1')),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
