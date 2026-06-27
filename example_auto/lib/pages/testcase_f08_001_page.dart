import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

import 'dart:io' show Platform;

/// 测试用例详情 - F08-001：开启控制台日志输出
class TestCaseF08001Page extends StatefulWidget {
  const TestCaseF08001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF08001Page> createState() => _TestCaseF08001PageState();
}

class _TestCaseF08001PageState extends State<TestCaseF08001Page> {
  String _result = '';
  bool _consoleLog = false;

  Future<void> _toggleConsoleLog(bool v) async {
    try {
      await FlutterAliplayer.enableConsoleLog(v);
      setState(() { _consoleLog = v; _result = '控制台日志: $v'; });
    } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  Future<void> _getSdkVersion() async {
    try {
      final v = await FlutterAliplayer.getSDKVersion();
      setState(() { _result = 'SDK版本: $v'; });
    } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F08-001 开启控制台日志输出')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('前置条件: 应用已启动，播放器已创建'),
                          Text('预期结果: 控制台能够看到播放器相关日志输出'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('控制台日志:'),
                      Switch(
                        key: const Key('switch_console_log'),
                        value: _consoleLog,
                        onChanged: _toggleConsoleLog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_get_sdk_version'),
                    onPressed: _getSdkVersion,
                    child: const Text('查询SDK版本'),
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
