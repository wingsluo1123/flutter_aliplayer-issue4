
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F03-003：能暂停播放并保留当前帧
class TestCaseF03003Page extends StatefulWidget {
  const TestCaseF03003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF03003Page> createState() => _TestCaseF03003PageState();
}

class _TestCaseF03003PageState extends State<TestCaseF03003Page> {
  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  FlutterAliplayer? _player;
  int _currentPosition = 0;
  String _statusText = 'idle';
  String _result = '';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '已准备';
      });
      _player?.play();
    });
    _player!.setOnRenderingStart((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '播放中';
        _result = '首帧已渲染，播放器正在播放';
      });
    });
    _player!.setOnInfo((int? infoCode, int? extraValue, String? extraMsg,
        String playerId) {
      if (infoCode == 2 && extraValue != null) {
        if (!mounted) return;
        setState(() {
          _currentPosition = (extraValue as num).toInt();
        });
      }
    });
    _player!.setOnError((int errorCode, String? errorExtra, String? errorMsg,
        String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '错误';
        _result = 'onError: [$errorCode] ${errorMsg ?? ''}';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
    _player?.setUrl(_testUrl);
    _player?.prepare();
  }

  Future<void> _play() async {
    await _player?.play();
    setState(() {
      _statusText = '播放中';
      _result = '调用 play()，继续播放';
    });
  }

  Future<void> _pause() async {
    final int pauseTime = _currentPosition;
    await _player?.pause();
    setState(() {
      _statusText = '已暂停';
      _result = '已暂停，暂停时 currentTime = $pauseTime ms';
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final dynamic pos = await _player?.getCurrentPosition();
    final int afterTime = (pos as num?)?.toInt() ?? _currentPosition;
    if (!mounted) return;
    setState(() {
      _result = '暂停时 currentTime = $pauseTime ms\n'
          '2 秒后 currentTime = $afterTime ms\n'
          '${afterTime == pauseTime ? "✓ currentTime 未增长，画面定格" : "注意: currentTime 有变化"}';
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
      appBar: AppBar(title: const Text('F03-003 能暂停播放并保留当前帧')),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                const Text('播放状态: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_statusText, key: const Key('txt_status')),
                const Spacer(),
                Text('当前时间: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$_currentPosition ms',
                    key: const Key('txt_current_time')),
              ],
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
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
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
                          Text(
                              '测试步骤: 1. 记录【当前时间】文本的数值 [验证点: 验证记录的 currentTime 数值有效]; 2. 点击【暂停】按钮 (API: pause) [验证点: 验证【播放状态】文本显示"已暂停"]; 3. 等待 2 秒后再次观察【当前时间】文本 [验证点: 验证 currentTime 数值与暂停时一致且画面定格]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 暂停后画面定格，currentTime 不再增长'),
                          const SizedBox(height: 4),
                          Text('后置条件: '),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Actions',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      ElevatedButton(
                        key: const Key('btn_play'),
                        onPressed: _play,
                        child: const Text('播放'),
                      ),
                      ElevatedButton(
                        key: const Key('btn_pause'),
                        onPressed: _pause,
                        child: const Text('暂停'),
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
