import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F20-001：开启HTTP/2协议支持
class TestCaseF20001Page extends StatefulWidget {
  const TestCaseF20001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF20001Page> createState() => _TestCaseF20001PageState();
}

class _TestCaseF20001PageState extends State<TestCaseF20001Page> {
  String _result = '';
  bool _http2 = false;

  Future<void> _setHttp2(bool v) async {
    try {
      await FlutterAliplayer.setUseHttp2(v);
      setState(() { _http2 = v; _result = 'HTTP/2: $v'; });
    } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F20-001 开启HTTP/2协议支持')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，进入全局设置页面'), Text('预期结果: 视频播放正常，网络请求使用HTTP/2协议'),
        ]))),
        Row(children: [
          const Text('启用HTTP/2:'),
          Switch(key: const Key('switch_http2'), value: _http2, onChanged: _setHttp2),
        ]),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
