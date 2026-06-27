import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F07-002：设置播放器场景模式为长视频
class TestCaseF07002Page extends StatefulWidget {
  const TestCaseF07002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF07002Page> createState() => _TestCaseF07002PageState();
}

class _TestCaseF07002PageState extends State<TestCaseF07002Page> {
  FlutterAliplayer? _player;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _createPlayer();
  }

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      await _player!.create();
      setState(() { _result = '播放器已创建'; });
    } catch (e) { setState(() { _result = '创建失败: $e'; }); }
  }

  Future<void> _setPlayConfig() async {
    try {
      final config = AVPConfig();
      config.startBufferDuration = 100;
      config.maxBufferDuration = 500;
      config.highBufferDuration = 300;
      await _player!.setPlayConfig(config);
      setState(() { _result = 'AVPConfig配置已应用'; });
    } catch (e) { setState(() { _result = '配置失败: $e'; }); }
  }

  Future<void> _setPlayerScene(String scene) async {
    try {
      final s = scene == 'long' ? PlayerScene.LONG : PlayerScene.SHORT;
      await _player!.setPlayerScene(s);
      setState(() { _result = '场景模式已切换: $scene'; });
    } catch (e) { setState(() { _result = '切换失败: $e'; }); }
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F07-002 设置播放器场景模式为长视频')),
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
                          Text('前置条件: 应用已启动，播放器已创建'),
                          Text('预期结果: 播放器按照长视频场景优化缓存和播放策略'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_set_play_config'),
                    onPressed: _setPlayConfig,
                    child: const Text('应用AVPConfig配置'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_set_scene_long'),
                    onPressed: () => _setPlayerScene('long'),
                    child: const Text('切换为长视频场景'),
                  ),
                  ElevatedButton(
                    key: const Key('btn_set_scene_short'),
                    onPressed: () => _setPlayerScene('short'),
                    child: const Text('切换为短视频场景'),
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
