import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliliveshiftplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F01-008：通过工厂类创建时移播放器
class TestCaseF01008Page extends StatefulWidget {
  const TestCaseF01008Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01008Page> createState() => _TestCaseF01008PageState();
}

class _TestCaseF01008PageState extends State<TestCaseF01008Page> {
  FlutterAliLiveShiftPlayer? _player;
  String _result = '';

  Future<void> _createByFactory() async {
    try {
      _player = FlutterAliPlayerFactory.createAliLiveShiftPlayer();
      setState(() { _result = 'FlutterAliLiveShiftPlayer已创建, playerId: ${_player!.playerId}'; });
    } catch (e) {
      setState(() { _result = '创建FlutterAliLiveShiftPlayer失败: $e'; });
    }
  }

  Future<void> _release() async {
    if (_player == null) return;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F01-008 通过工厂类创建时移播放器')),
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
                          Text('测试步骤: 点击【创建时移播放器】按钮 (API: FlutterAliPlayerFactory.createFlutterAliLiveShiftPlayer)'),
                          const SizedBox(height: 4),
                          Text('预期结果: 成功返回FlutterAliLiveShiftPlayer实例，支持时移播放功能'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_create_createAliLiveShiftPlayer'),
                    onPressed: _createByFactory,
                    child: const Text('创建FlutterAliLiveShiftPlayer'),
                  ),
                  const SizedBox(height: 8),
                  if (_player != null) Text('播放器类型: FlutterAliLiveShiftPlayer'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_release'),
                    onPressed: _player == null ? null : _release,
                    child: const Text('释放'),
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
