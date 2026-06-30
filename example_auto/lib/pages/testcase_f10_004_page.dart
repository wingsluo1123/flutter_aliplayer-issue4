
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F10-004：能开启循环播放并在结束后自动重播
class TestCaseF10004Page extends StatefulWidget {
  const TestCaseF10004Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF10004Page> createState() => _TestCaseF10004PageState();
}

class _TestCaseF10004PageState extends State<TestCaseF10004Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _loop = false;
  bool _isPrepared = false;

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _isPrepared = true;
        _result = 'onPrepared: playerId=$playerId';
      });
    });
    _player!.setOnCompletion((String playerId) {
      setState(() {
        _result = 'onCompletion: playerId=$playerId (循环=$_loop, 将自动重播)';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = 'onError: code=$errorCode, msg=$errorMsg, playerId=$playerId';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _play() async {
    await _player!.play();
    setState(() {
      _result = '播放中, 循环=$_loop';
    });
  }

  Future<void> _onLoopChanged(bool value) async {
    setState(() {
      _loop = value;
    });
    await _player!.setLoop(value);
    setState(() {
      _result = 'setLoop($value) 已调用, 循环播放状态=$_loop';
    });
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F10-004 能开启循环播放并在结束后自动重播')),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.black,
            width: double.infinity,
            height: 200,
            child: AliPlayerView(
              onCreated: _onViewCreated,
              x: 0,
              y: 0,
              width: double.infinity,
              height: 200,
            ),
          ),
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
                          Text('前置条件: 应用已启动；播放器正在播放短视频（便于快速验证）'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【循环播放】开关 (API: setLoop, loop: true) [验证点: 验证开关状态为"已开启"]; 2. 等待视频自然播放结束 [验证点: 验证播放结束后自动从头开始播放]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 开启循环后视频播放结束自动重播'),
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
                  Row(
                    children: <Widget>[
                      const Text('循环播放'),
                      const SizedBox(width: 8),
                      Switch(
                        key: const Key('switch_loop'),
                        value: _loop,
                        onChanged: _isPrepared ? _onLoopChanged : null,
                      ),
                      const SizedBox(width: 8),
                      Text(_loop ? '已开启' : '已关闭'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_play'),
                    onPressed: _isPrepared ? _play : null,
                    child: const Text('播放'),
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
