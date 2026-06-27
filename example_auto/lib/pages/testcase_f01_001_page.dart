import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F01-001：创建播放器实例并指定唯一标识
class TestCaseF01001Page extends StatefulWidget {
  const TestCaseF01001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01001Page> createState() => _TestCaseF01001PageState();
}

class _TestCaseF01001PageState extends State<TestCaseF01001Page> {
  FlutterAliplayer? _player;
  String _result = '';
  final TextEditingController _playerIdCtrl = TextEditingController();

  Future<void> _createPlayer() async {
    try {
      String id = _playerIdCtrl.text.trim();
      if (id.isEmpty) {
        id = 'player_${DateTime.now().millisecondsSinceEpoch}';
        _player = FlutterAliPlayerFactory.createAliPlayer();
      } else {
        _player = FlutterAliPlayerFactory.createAliPlayer(playerId: id);
      }
      setState(() { _result = '播放器已创建, playerId: ${_player!.playerId}'; });
    } catch (e) {
      setState(() { _result = '创建播放器失败: $e'; });
    }
  }

  Future<void> _release() async {
    if (_player == null) {
      setState(() { _result = '请先创建播放器'; });
      return;
    }
    try {
      await _player!.release();
      setState(() { _result = '播放器已释放'; _player = null; });
    } catch (e) {
      setState(() { _result = '释放失败: $e'; });
    }
  }

  @override
  void dispose() {
    _player?.release();
    _playerIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F01-001 创建播放器实例并指定唯一标识')),
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
                          Text('测试步骤: 在【播放器ID】输入框中输入“player_001”，点击【创建播放器】按钮 (API: FlutterAliplayer.init, id: “player_001”)'),
                          const SizedBox(height: 4),
                          Text('预期结果: 播放器实例成功创建，可在实例列表中看到player_001对应的播放器'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('input_player_id'),
                          controller: _playerIdCtrl,
                          decoration: const InputDecoration(
                            labelText: '播放器ID',
                            hintText: '留空自动生成',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_create_player'),
                    onPressed: _createPlayer,
                    child: const Text('创建播放器'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_release'),
                    onPressed: _release,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                    child: const Text('释放播放器'),
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
