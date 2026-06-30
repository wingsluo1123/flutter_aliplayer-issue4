
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F01-003：能释放播放器实例并回收资源
class TestCaseF01003Page extends StatefulWidget {
  const TestCaseF01003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01003Page> createState() => _TestCaseF01003PageState();
}

class _TestCaseF01003PageState extends State<TestCaseF01003Page> {
  String _result = '';
  FlutterAliplayer? _player;
  String _statusText = '未创建';
  String? _createdPlayerId;

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
  }

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      _createdPlayerId = _player!.playerId;
      _player!.setOnError((code, extra, msg, playerId) {
        setState(() {
          _statusText = '错误';
          _result = 'onError: [$code] $msg (playerId=$playerId)';
        });
      });
      setState(() {
        _statusText = '已创建';
        _result = '播放器实例创建成功\nplayerId=$_createdPlayerId\n实例状态: 已创建';
      });
    } catch (e) {
      setState(() {
        _statusText = '创建失败';
        _result = '创建播放器失败: $e';
      });
    }
  }

  Future<void> _releasePlayer() async {
    if (_player == null) {
      setState(() {
        _result = '当前没有可释放的播放器实例';
      });
      return;
    }
    final String id = _createdPlayerId ?? _player!.playerId;
    try {
      await _player!.release();
      final bool removed = !FlutterAliPlayerFactory.instanceMap.containsKey(id);
      setState(() {
        _statusText = '已释放';
        _result = '播放器实例已释放\nplayerId=$id\n从 instanceMap 移除: $removed\n实例状态: 已释放';
      });
      _player = null;
      _createdPlayerId = null;
    } catch (e) {
      setState(() {
        _statusText = '释放失败';
        _result = '释放播放器失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F01-003 能释放播放器实例并回收资源')),
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
                          Text('前置条件: 应用已启动；已创建至少一个播放器实例'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【实例列表】中选择目标实例 [验证点: 验证目标实例条目被高亮选中]; 2. 点击【释放播放器】按钮 (API: release) [验证点: 验证【实例状态】文本变为"已释放"]; 3. 观察【实例列表】 [验证点: 验证目标实例条目从列表中移除]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 播放器实例被释放，状态变为已释放，实例从列表中移除且无残留资源'),
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
                  Container(
                    key: const Key('player_container'),
                    height: 200,
                    color: Colors.black,
                    child: _player != null
                        ? AliPlayerView(
                            onCreated: _onViewCreated,
                            x: 0,
                            y: 0,
                            width: double.infinity,
                            height: 200,
                          )
                        : const Center(
                            child: Text(
                              '请先创建播放器',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text('实例状态: $_statusText'),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('btn_create_player'),
                          onPressed: _createPlayer,
                          child: const Text('创建播放器'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('btn_release_player'),
                          onPressed: _releasePlayer,
                          child: const Text('释放播放器'),
                        ),
                      ),
                    ],
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
