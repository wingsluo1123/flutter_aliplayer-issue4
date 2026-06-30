
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F10-003：能静音播放并关闭声音输出
class TestCaseF10003Page extends StatefulWidget {
  const TestCaseF10003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF10003Page> createState() => _TestCaseF10003PageState();
}

class _TestCaseF10003PageState extends State<TestCaseF10003Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _muted = false;
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
      _result = '播放中, 静音=$_muted';
    });
  }

  Future<void> _onMutedChanged(bool value) async {
    setState(() {
      _muted = value;
    });
    await _player!.setMuted(value);
    setState(() {
      _result = 'setMuted($value) 已调用, 静音状态=$_muted';
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
      appBar: AppBar(title: const Text('F10-003 能静音播放并关闭声音输出')),
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
                          Text('测试步骤: 1. 点击【静音】开关 (API: setMuted, muted: true) [验证点: 验证开关状态为"已静音"]; 2. 观察播放声音与画面 [验证点: 验证无声音输出且画面正常播放]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 静音后无声音输出，画面正常播放'),
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
                      const Text('静音'),
                      const SizedBox(width: 8),
                      Switch(
                        key: const Key('switch_muted'),
                        value: _muted,
                        onChanged: _isPrepared ? _onMutedChanged : null,
                      ),
                      const SizedBox(width: 8),
                      Text(_muted ? '已静音' : '未静音'),
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
