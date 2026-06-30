
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F03-004：能停止播放并回到待播状态
class TestCaseF03004Page extends StatefulWidget {
  const TestCaseF03004Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF03004Page> createState() => _TestCaseF03004PageState();
}

class _TestCaseF03004PageState extends State<TestCaseF03004Page> {
  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  FlutterAliplayer? _player;
  bool _autoPlayAfterPrepare = true;
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
        _result = 'onPrepared 回调触发，播放器进入已准备状态';
      });
      if (_autoPlayAfterPrepare) {
        _autoPlayAfterPrepare = false;
        _player?.play();
      }
    });
    _player!.setOnRenderingStart((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '播放中';
        _result = '首帧已渲染，播放器正在播放';
      });
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
    _autoPlayAfterPrepare = false;
    await _player?.play();
    setState(() {
      _statusText = '播放中';
      _result = '调用 play()，继续播放';
    });
  }

  Future<void> _stop() async {
    await _player?.stop();
    setState(() {
      _statusText = '已停止';
      _result = '调用 stop()，播放器回到待播状态，画面已清空';
    });
  }

  Future<void> _prepare() async {
    _autoPlayAfterPrepare = false;
    setState(() {
      _statusText = '准备中';
      _result = '调用 prepare()，等待 onPrepared 回调...';
    });
    _player?.setUrl(_testUrl);
    await _player?.prepare();
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F03-004 能停止播放并回到待播状态')),
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
                          Text('前置条件: 应用已启动；播放器正在播放或已暂停'),
                          const SizedBox(height: 4),
                          Text(
                              '测试步骤: 1. 点击【停止】按钮 (API: stop) [验证点: 验证【播放状态】文本显示"已停止"]; 2. 观察【播放器容器】区域 [验证点: 验证画面清空或显示待播占位图]; 3. 点击【准备】按钮 (API: prepare) [验证点: 验证播放器可重新进入已准备状态]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 停止后播放器回到待播状态，可重新 prepare 进入可播放状态'),
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
                        key: const Key('btn_stop'),
                        onPressed: _stop,
                        child: const Text('停止'),
                      ),
                      ElevatedButton(
                        key: const Key('btn_prepare'),
                        onPressed: _prepare,
                        child: const Text('准备'),
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
