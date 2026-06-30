
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F10-002：能调节播放倍速并改变播放速度
class TestCaseF10002Page extends StatefulWidget {
  const TestCaseF10002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF10002Page> createState() => _TestCaseF10002PageState();
}

class _TestCaseF10002PageState extends State<TestCaseF10002Page> {
  String _result = '';
  FlutterAliplayer? _player;
  double _speed = 1.0;
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
      _result = '播放中, 当前倍速=${_speed.toStringAsFixed(1)}x';
    });
  }

  Future<void> _onSpeedChanged(double value) async {
    setState(() {
      _speed = value;
    });
    await _player!.setSpeed(value);
    setState(() {
      _result = 'setSpeed(${value.toStringAsFixed(1)}) 已调用, 当前倍速=${_speed.toStringAsFixed(1)}x';
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
      appBar: AppBar(title: const Text('F10-002 能调节播放倍速并改变播放速度')),
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
                          Text('测试步骤: 1. 在【倍速】下拉菜单中选择"2.0x" (API: setSpeed, speed: 2.0) [验证点: 验证下拉菜单显示"2.0x"]; 2. 观察【当前时间】文本与画面 [验证点: 验证播放速度明显加快且画面与音频同步]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 倍速设置后播放速度变化，画面与音频同步'),
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
                  const Text('倍速'),
                  DropdownButton<double>(
                    key: const Key('dropdown_speed'),
                    value: _speed,
                    isExpanded: true,
                    items: const <DropdownMenuItem<double>>[
                      DropdownMenuItem<double>(value: 0.5, child: Text('0.5x')),
                      DropdownMenuItem<double>(value: 1.0, child: Text('1.0x')),
                      DropdownMenuItem<double>(value: 1.5, child: Text('1.5x')),
                      DropdownMenuItem<double>(value: 2.0, child: Text('2.0x')),
                    ],
                    onChanged: _isPrepared
                        ? (double? value) {
                            if (value != null) {
                              _onSpeedChanged(value);
                            }
                          }
                        : null,
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
