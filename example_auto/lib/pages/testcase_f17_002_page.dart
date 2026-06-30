
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F17-002：能开启控制台日志并在控制台看到播放器日志
class TestCaseF17002Page extends StatefulWidget {
  const TestCaseF17002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF17002Page> createState() => _TestCaseF17002PageState();
}

class _TestCaseF17002PageState extends State<TestCaseF17002Page> {
  String _result = '';
  bool _consoleLogEnabled = false;
  FlutterAliplayer? _player;

  static const String _url =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  Future<void> _toggleConsoleLog(bool value) async {
    try {
      await FlutterAliplayer.enableConsoleLog(value);
      _consoleLogEnabled = value;
      setState(() {
        _result = 'enableConsoleLog 调用成功\n'
            '控制台日志开关: ${value ? "已启用" : "已关闭"}\n'
            'enable: $value\n'
            '可点击【播放】按钮触发播放器日志输出';
      });
    } catch (e) {
      setState(() {
        _result = 'error: $e';
      });
    }
  }

  Future<void> _play() async {
    try {
      _player ??= FlutterAliPlayerFactory.createAliPlayer(playerId: 'f17_002');
      await _player!.setUrl(_url);
      await _player!.prepare();
      await _player!.play();
      setState(() {
        _result = 'play 调用成功\n'
            '控制台日志开关: ${_consoleLogEnabled ? "已启用" : "已关闭"}\n'
            '已创建播放器实例并 prepare+play\n'
            '请在控制台查看播放器相关日志输出';
      });
    } catch (e) {
      setState(() {
        _result = 'error: $e';
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
      appBar: AppBar(title: const Text('F17-002 能开启控制台日志并在控制台看到播放器日志')),
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
                          Text('前置条件: 应用已启动；全局播放器设置演示页面已打开；可查看控制台日志输出'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【启用控制台日志】开关 (API: enableConsoleLog, enable: true) [验证点: 验证开关状态为"已启用"]; 2. 返回播放器演示页面并开始播放视频 (API: play) [验证点: 验证控制台输出播放器相关日志]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 启用控制台日志后控制台输出播放器相关日志'),
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
                  SwitchListTile(
                    key: const Key('switch_console_log'),
                    title: const Text('启用控制台日志'),
                    value: _consoleLogEnabled,
                    onChanged: _toggleConsoleLog,
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
