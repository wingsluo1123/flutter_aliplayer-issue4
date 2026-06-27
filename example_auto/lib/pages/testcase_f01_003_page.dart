import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F01-003：在原生端创建播放器实例
class TestCaseF01003Page extends StatefulWidget {
  const TestCaseF01003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01003Page> createState() => _TestCaseF01003PageState();
}

class _TestCaseF01003PageState extends State<TestCaseF01003Page> {
  FlutterAliplayer? _player;
  String _result = '';
  bool _nativeCreated = false;

  Future<void> _createDartPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      setState(() { _result = 'Dart层播放器已创建, playerId: ${_player!.playerId}'; });
    } catch (e) {
      setState(() { _result = '创建Dart播放器失败: $e'; });
    }
  }

  Future<void> _createNative() async {
    if (_player == null) {
      setState(() { _result = '请先在Dart层创建播放器'; });
      return;
    }
    try {
      await _player!.create();
      _nativeCreated = true;
      setState(() { _result = '原生端播放器已创建'; });
    } catch (e) {
      setState(() { _result = '创建原生播放器失败: $e'; });
    }
  }

  Future<void> _release() async {
    if (_player == null) return;
    try {
      await _player!.release();
      setState(() { _result = '播放器已释放'; _player = null; _nativeCreated = false; });
    } catch (e) {
      setState(() { _result = '释放失败: $e'; });
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
      appBar: AppBar(title: const Text('F01-003 在原生端创建播放器实例')),
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
                          Text('前置条件: 应用已启动，已在Dart层创建播放器实例'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 点击【创建原生播放器】按钮 (API: create)'),
                          const SizedBox(height: 4),
                          Text('预期结果: 原生端成功创建播放器实例，可接收后续指令'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_create_dart'),
                    onPressed: _createDartPlayer,
                    child: const Text('创建Dart播放器'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_create_native'),
                    onPressed: _createNative,
                    child: const Text('创建原生播放器'),
                  ),
                  const SizedBox(height: 8),
                  Text('原生端状态: $_nativeCreated'),
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
