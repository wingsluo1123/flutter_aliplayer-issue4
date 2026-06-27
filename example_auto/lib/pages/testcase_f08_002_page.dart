import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

import 'dart:io' show Platform;

/// 测试用例详情 - F08-002：查询SDK版本号
class TestCaseF08002Page extends StatefulWidget {
  const TestCaseF08002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF08002Page> createState() => _TestCaseF08002PageState();
}

class _TestCaseF08002PageState extends State<TestCaseF08002Page> {
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
      appBar: AppBar(title: const Text('F08-002 查询SDK版本号')),
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
                          Text('前置条件: 应用已启动'),
                          Text('预期结果: 返回SDK版本号为有效字符串'),
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
