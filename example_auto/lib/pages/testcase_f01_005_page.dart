import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F01-005：异步释放播放器资源
class TestCaseF01005Page extends StatefulWidget {
  const TestCaseF01005Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01005Page> createState() => _TestCaseF01005PageState();
}

class _TestCaseF01005PageState extends State<TestCaseF01005Page> {
  FlutterAliplayer? _player;
  String _result = '';
  bool _released = false;

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      await _player!.create();
      setState(() { _result = '播放器已创建并初始化'; _released = false; });
    } catch (e) {
      setState(() { _result = '创建失败: $e'; });
    }
  }

  Future<void> _releasePlayer() async {
    if (_player == null) {
      setState(() { _result = '请先创建播放器'; });
      return;
    }
    try {
      await _player!.releaseAsync();
      setState(() { _result = '播放器已释放'; _released = true; _player = null; });
    } catch (e) {
      setState(() { _result = 'releaseAsync失败: $e'; });
    }
  }

  @override
  void dispose() {
    if (_player != null) _player!.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F01-005 异步释放播放器资源')),
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
                          Text('前置条件: 应用已启动，播放器已创建并完成视频播放'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 点击【异步释放】按钮 (API: releaseAsync)'),
                          const SizedBox(height: 4),
                          Text('预期结果: 播放器从实例映射中移除，原生端资源被释放'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_create_player'),
                    onPressed: _released ? null : _createPlayer,
                    child: const Text('创建播放器'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_releaseAsync'),
                    onPressed: (_player == null) ? null : _releasePlayer,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                    child: const Text('异步释放'),
                  ),
                  const SizedBox(height: 8),
                  Text('播放器状态: ${_released ? "已释放" : (_player != null ? "活跃" : "未创建")}'),
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
