
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F04-002：能绑定渲染面与播放器渲染画面到指定区域
class TestCaseF04002Page extends StatefulWidget {
  const TestCaseF04002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF04002Page> createState() => _TestCaseF04002PageState();
}

class _TestCaseF04002PageState extends State<TestCaseF04002Page> {
  String _result = '';
  FlutterAliplayer? _player;
  int? _viewId;
  String _statusText = '未创建';
  bool _bound = false;

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
        _result = '首帧渲染完成，画面已渲染到指定渲染面区域';
      });
    });
    _player!.setOnError((code, extra, msg, playerId) {
      setState(() {
        _statusText = '错误';
        _result = 'onError: [$code] $msg (playerId=$playerId)';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _viewId = viewId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _result = '渲染面已创建，viewId=$viewId\n请点击【绑定渲染面】按钮调用 setPlayerView';
      });
    });
  }

  Future<void> _bindView() async {
    if (_viewId == null) {
      setState(() {
        _result = '渲染面尚未创建，无法绑定';
      });
      return;
    }
    try {
      await _player!.setPlayerView(_viewId!);
      setState(() {
        _bound = true;
        _statusText = '已绑定';
        _result = '已调用 setPlayerView($_viewId)\n绑定状态: 已绑定';
      });
    } catch (e) {
      setState(() {
        _result = '绑定渲染面失败: $e';
      });
    }
  }

  Future<void> _play() async {
    if (!_bound) {
      setState(() {
        _result = '请先点击【绑定渲染面】按钮完成绑定';
      });
      return;
    }
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
      appBar: AppBar(title: const Text('F04-002 能绑定渲染面与播放器渲染画面到指定区域')),
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
                          Text('前置条件: 应用已启动；播放器实例已创建；渲染面已嵌入'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【绑定渲染面】按钮 (API: setPlayerView, viewId: 当前渲染面) [验证点: 验证【绑定状态】文本显示"已绑定"]; 2. 设置播放源后点击【播放】按钮 (API: play) [验证点: 验证视频画面渲染到指定渲染面区域且位置正确]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 绑定后播放器输出画面到指定渲染面，位置和尺寸正确'),
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
                  Text('绑定状态: $_statusText'),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('btn_bind_view'),
                          onPressed: _bindView,
                          child: const Text('绑定渲染面'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('btn_play'),
                          onPressed: _play,
                          child: const Text('播放'),
                        ),
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
