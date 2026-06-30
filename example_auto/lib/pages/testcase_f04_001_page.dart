
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F04-001：能嵌入视频渲染面并显示视频画面
class TestCaseF04001Page extends StatefulWidget {
  const TestCaseF04001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF04001Page> createState() => _TestCaseF04001PageState();
}

class _TestCaseF04001PageState extends State<TestCaseF04001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  String _statusText = '未创建';

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((playerId) {
      setState(() {
        _statusText = '已准备';
        _result = 'onPrepared 回调触发，播放器已准备';
      });
      _player!.play();
    });
    _player!.setOnRenderingStart((playerId) {
      setState(() {
        _statusText = '画面可见';
        _result = '首帧渲染完成，渲染面已显示视频画面';
      });
    });
    _player!.setOnError((code, extra, msg, playerId) {
      setState(() {
        _statusText = '错误';
        _result = 'onError: [$code] $msg (playerId=$playerId)';
      });
    });
    _player!.setOnVideoSizeChanged((width, height, rotation, playerId) {
      setState(() {
        _result = '视频尺寸变化: ${width}x$height rotation=$rotation';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _result = '渲染面已挂载，viewId=$viewId';
      });
    });
  }

  Future<void> _play() async {
    try {
      setState(() {
        _statusText = '准备中';
        _result = '正在设置播放源并准备...';
      });
      await _player!.setUrl(_testUrl);
      await _player!.prepare();
      setState(() {
        _result = '已调用 setUrl + prepare\n等待 onPrepared 后自动播放';
      });
    } catch (e) {
      setState(() {
        _statusText = '错误';
        _result = '播放失败: $e';
      });
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
      appBar: AppBar(title: const Text('F04-001 能嵌入视频渲染面并显示视频画面')),
      body: Column(
        children: <Widget>[
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
                          Text('前置条件: 应用已启动；播放器演示页面已打开'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 进入【播放器演示】页面 [验证点: 验证页面显示【播放器容器】区域]; 2. 设置播放源后点击【播放】按钮 (API: play) [验证点: 验证【播放器容器】区域内显示视频画面]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 渲染面在页面正确显示，播放视频后画面可见'),
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
                  Container(
                    key: const Key('player_container'),
                    height: 200,
                    color: Colors.black,
                    child: _player != null
                        ? AliPlayerView(
                            onCreated: _onViewCreated,
                            x: 0,
                            y: 0,
                            width: double.infinity,
                            height: 200,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  Text('渲染状态: $_statusText'),
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
