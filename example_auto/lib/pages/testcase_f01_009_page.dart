import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F01-009：创建多个播放器实例并行运行
class TestCaseF01009Page extends StatefulWidget {
  const TestCaseF01009Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01009Page> createState() => _TestCaseF01009PageState();
}

class _TestCaseF01009PageState extends State<TestCaseF01009Page> {
  final Map<String, FlutterAliplayer> _players = {};
  String _result = '';
  final TextEditingController _url1Ctrl = TextEditingController();
  final TextEditingController _url2Ctrl = TextEditingController();

  Future<void> _createPlayer(String id) async {
    try {
      final player = FlutterAliPlayerFactory.createAliPlayer(playerId: id);
      await player.create();
      _players[id] = player;
      setState(() { _result = '播放器 $id 已创建'; });
    } catch (e) {
      setState(() { _result = '创建播放器 $id 失败: $e'; });
    }
  }

  Future<void> _setUrl(String id) async {
    final player = _players[id];
    if (player == null) {
      setState(() { _result = '播放器 $id 未创建'; });
      return;
    }
    try {
      final url = id == 'player_1' ? _url1Ctrl.text.trim() : _url2Ctrl.text.trim();
      if (url.isEmpty) { setState(() { _result = '请输入视频URL'; }); return; }
      await player.setUrl(url);
      setState(() { _result = '$id URL已设置'; });
    } catch (e) {
      setState(() { _result = '设置URL失败: $e'; });
    }
  }

  Future<void> _play(String id) async {
    final player = _players[id];
    if (player == null) return;
    try {
      await player.prepare();
      await player.play();
      setState(() { _result = '$id 播放中'; });
    } catch (e) {
      setState(() { _result = '$id 播放失败: $e'; });
    }
  }

  Future<void> _releaseAll() async {
    for (var entry in _players.entries) {
      try { await entry.value.release(); } catch (_) {}
    }
    _players.clear();
    setState(() { _result = '所有播放器已释放'; });
  }

  @override
  void dispose() {
    for (var p in _players.values) { p.release(); }
    _url1Ctrl.dispose();
    _url2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F01-009 创建多个播放器实例并行运行')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('前置条件: 应用已启动，进入播放器演示页面'),
                          const SizedBox(height: 4),
                          Text('预期结果: 多个播放器实例同时运行正常，各自播放的视频互不影响'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Player 1
                  const Text('播放器 1 (player_1)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    key: const Key('btn_create_p1'),
                    onPressed: () => _createPlayer('player_1'),
                    child: const Text('创建播放器1'),
                  ),
                  TextField(
                    controller: _url1Ctrl,
                    decoration: const InputDecoration(labelText: '视频A URL', isDense: true),
                  ),
                  ElevatedButton(
                    key: const Key('btn_url_p1'),
                    onPressed: () => _setUrl('player_1'),
                    child: const Text('设置URL (播放器1)'),
                  ),
                  ElevatedButton(
                    key: const Key('btn_play_p1'),
                    onPressed: () => _play('player_1'),
                    child: const Text('播放 (播放器1)'),
                  ),
                  const Divider(),
                  // Player 2
                  const Text('播放器 2 (player_2)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    key: const Key('btn_create_p2'),
                    onPressed: () => _createPlayer('player_2'),
                    child: const Text('创建播放器2'),
                  ),
                  TextField(
                    controller: _url2Ctrl,
                    decoration: const InputDecoration(labelText: '视频B URL', isDense: true),
                  ),
                  ElevatedButton(
                    key: const Key('btn_url_p2'),
                    onPressed: () => _setUrl('player_2'),
                    child: const Text('设置URL (播放器2)'),
                  ),
                  ElevatedButton(
                    key: const Key('btn_play_p2'),
                    onPressed: () => _play('player_2'),
                    child: const Text('播放 (播放器2)'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_release_all'),
                    onPressed: _releaseAll,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                    child: const Text('释放所有'),
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
