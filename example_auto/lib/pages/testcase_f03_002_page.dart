
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F03-002：能开始播放并渲染视频画面
class TestCaseF03002Page extends StatefulWidget {
  const TestCaseF03002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF03002Page> createState() => _TestCaseF03002PageState();
}

class _TestCaseF03002PageState extends State<TestCaseF03002Page> {
  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  FlutterAliplayer? _player;
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
    });
    _player!.setOnRenderingStart((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '播放中';
        _result = 'onRenderingStart 回调触发，首帧已渲染，视频画面开始显示';
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
    setState(() {
      _statusText = '播放中';
      _result = '调用 play()，等待 onRenderingStart 回调...';
    });
    await _player?.play();
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F03-002 能开始播放并渲染视频画面')),
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
                          Text('前置条件: 应用已启动；播放器已进入 prepared 状态'),
                          const SizedBox(height: 4),
                          Text(
                              '测试步骤: 1. 点击【播放】按钮 (API: play) [验证点: 验证【播放状态】文本显示"播放中"]; 2. 观察【播放器容器】区域 [验证点: 验证视频画面开始显示且 onRenderingStart 回调触发]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 点击播放后视频画面开始渲染，onRenderingStart 事件触发'),
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
                  ElevatedButton(
                    key: const Key('btn_play'),
                    onPressed: _play,
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
