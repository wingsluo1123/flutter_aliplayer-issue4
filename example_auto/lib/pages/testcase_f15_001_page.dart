import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer/flutter_aliliveshiftplayer.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F15-001：设置直播时移数据源
class TestCaseF15001Page extends StatefulWidget {
  const TestCaseF15001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF15001Page> createState() => _TestCaseF15001PageState();
}

class _TestCaseF15001PageState extends State<TestCaseF15001Page> {
  FlutterAliLiveShiftPlayer? _player; String _result = '';
  final TextEditingController _timelineCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _createPlayer(); }

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliLiveShiftPlayer();
      await _player!.create();
      setState(() { _result = '时移播放器已创建'; });
    } catch (e) { }
  }

  Future<void> _setDataSource() async {
    try {
      await _player!.setDataSource(_timelineCtrl.text.trim(), _urlCtrl.text.trim());
      setState(() { _result = '时移数据源已设置'; });
    } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  Future<void> _seekToLiveTime() async {
    try {
      final time = int.tryParse(_timeCtrl.text.trim()) ?? 0;
      await _player!.seekToLiveTime(time);
      setState(() { _result = '已跳转到时移位置: $time'; });
    } catch (e) { setState(() { _result = '跳转失败: $e'; }); }
  }

  @override
  void dispose() { _player?.release(); _timelineCtrl.dispose(); _urlCtrl.dispose(); _timeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F15-001 设置直播时移数据源')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，已创建时移播放器实例'), Text('预期结果: 时移数据源加载成功，可进行时移操作'),
        ]))),
        TextField(controller: _timelineCtrl, decoration: const InputDecoration(labelText: '时移时间轴URL', isDense: true)),
        TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '直播URL', isDense: true)),
        ElevatedButton(key: const Key('btn_set_datasource'), onPressed: _setDataSource, child: const Text('设置时移数据源')),
        const SizedBox(height: 8),
        TextField(controller: _timeCtrl, decoration: const InputDecoration(labelText: '时移目标时间', isDense: true)),
        ElevatedButton(key: const Key('btn_seek_live_time'), onPressed: _seekToLiveTime, child: const Text('时移跳转')),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
