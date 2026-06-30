
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F01-002：能通过自定义 playerId 创建独立播放器实例
class TestCaseF01002Page extends StatefulWidget {
  const TestCaseF01002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01002Page> createState() => _TestCaseF01002PageState();
}

class _TestCaseF01002PageState extends State<TestCaseF01002Page> {
  String _result = '';
  final TextEditingController _playerIdController = TextEditingController();
  final List<FlutterAliplayer> _players = <FlutterAliplayer>[];
  final List<String> _instanceIds = <String>[];

  Future<void> _createPlayer() async {
    final String id = _playerIdController.text.trim();
    if (id.isEmpty) {
      setState(() {
        _result = '请先在输入框中输入 playerId';
      });
      return;
    }
    try {
      if (FlutterAliPlayerFactory.instanceMap.containsKey(id)) {
        setState(() {
          _result = 'playerId="$id" 已存在，请使用其他 playerId';
        });
        return;
      }
      final FlutterAliplayer player =
          FlutterAliPlayerFactory.createAliPlayer(playerId: id);
      player.setOnError((code, extra, msg, playerId) {
        setState(() {
          _result = 'onError: [$code] $msg (playerId=$playerId)';
        });
      });
      _players.add(player);
      _instanceIds.add(id);
      final String listText =
          _instanceIds.map((e) => '  - $e').join('\n');
      setState(() {
        _result = '创建成功，playerId="$id"\n当前实例列表 (${_instanceIds.length} 个):\n$listText';
      });
    } catch (e) {
      setState(() {
        _result = '创建播放器失败: $e';
      });
    }
  }

  @override
  void dispose() {
    for (final FlutterAliplayer p in _players) {
      p.release();
    }
    _playerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F01-002 能通过自定义 playerId 创建独立播放器实例')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    '测试信息',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('优先级: L0'),
                          const SizedBox(height: 4),
                          Text('前置条件: 应用已启动；播放器演示页面已打开'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【playerId 输入框】中输入"player-A" (API: createAliPlayer, playerId: player-A) [验证点: 验证输入框文本为"player-A"]; 2. 点击【创建播放器】按钮 (API: createAliPlayer) [验证点: 验证【实例列表】中出现"player-A"条目]; 3. 在【playerId 输入框】中输入"player-B"后点击【创建播放器】按钮 (API: createAliPlayer, playerId: player-B) [验证点: 验证【实例列表】中同时存在"player-A"和"player-B"两个独立条目]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 不同 playerId 创建的播放器实例在实例列表中作为独立条目存在，互不干扰'),
                          const SizedBox(height: 4),
                          Text('后置条件: '),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_player_id'),
                    controller: _playerIdController,
                    decoration: const InputDecoration(
                      labelText: 'playerId',
                      hintText: '请输入 playerId，如 player-A',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_create_player'),
                    onPressed: _createPlayer,
                    child: const Text('创建播放器'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '实例列表',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    key: const Key('instance_list'),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _instanceIds.isEmpty
                        ? const Text('（暂无实例）')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _instanceIds
                                .map((e) => Text('• $e'))
                                .toList(),
                          ),
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
