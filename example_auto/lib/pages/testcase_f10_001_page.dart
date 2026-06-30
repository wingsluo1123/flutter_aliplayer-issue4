
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F10-001：能调节音量并改变播放音量大小
class TestCaseF10001Page extends StatefulWidget {
  const TestCaseF10001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF10001Page> createState() => _TestCaseF10001PageState();
}

class _TestCaseF10001PageState extends State<TestCaseF10001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  double _volume = 1.0;
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
      _result = '播放中, 当前音量=${_volume.toStringAsFixed(2)}';
    });
  }

  Future<void> _onVolumeChanged(double value) async {
    setState(() {
      _volume = value;
    });
    await _player!.setVolume(value);
    setState(() {
      _result = 'setVolume(${value.toStringAsFixed(2)}) 已调用, 当前音量=${_volume.toStringAsFixed(2)}';
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
      appBar: AppBar(title: const Text('F10-001 能调节音量并改变播放音量大小')),
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
                          Text('前置条件: 应用已启动；播放器正在播放视频'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 拖动【音量滑块】到 0.5 位置 (API: setVolume, volume: 0.5) [验证点: 验证【音量滑块】位置在 0.5]; 2. 观察播放声音 [验证点: 验证播放音量较之前降低且无爆音]; 3. 拖动【音量滑块】到 1.0 位置 (API: setVolume, volume: 1.0) [验证点: 验证播放音量恢复正常]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 音量随滑块设置值变化，无爆音'),
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
                  Text('音量: ${_volume.toStringAsFixed(2)}'),
                  Slider(
                    key: const Key('slider_volume'),
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: _volume.toStringAsFixed(2),
                    onChanged: _isPrepared ? _onVolumeChanged : null,
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
