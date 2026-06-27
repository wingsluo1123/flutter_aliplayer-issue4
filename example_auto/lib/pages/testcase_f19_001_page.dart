import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_avpdef.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F19-001：开启本地缓存功能
class TestCaseF19001Page extends StatefulWidget {
  const TestCaseF19001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF19001Page> createState() => _TestCaseF19001PageState();
}

class _TestCaseF19001PageState extends State<TestCaseF19001Page> {
  String _result = '';
  bool _cacheEnabled = false;
  final TextEditingController _cacheDirCtrl = TextEditingController(text: '/data/cache');

  Future<void> _enableLocalCache() async {
    try {
      await FlutterAliplayer.enableLocalCache(true, '50000', _cacheDirCtrl.text.trim(), DocTypeForIOS.documents);
      setState(() { _cacheEnabled = true; _result = '本地缓存已启用'; });
    } catch (e) { setState(() { _result = '启用缓存失败: $e'; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F19-001 开启本地缓存功能')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，播放器已创建'), Text('预期结果: 视频播放时数据被缓存到本地存储'),
        ]))),
        Row(children: [
          Expanded(child: TextField(
            controller: _cacheDirCtrl,
            decoration: const InputDecoration(labelText: '缓存目录', isDense: true),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('启用本地缓存:'),
          Switch(key: const Key('switch_cache'), value: _cacheEnabled, onChanged: (v) => _enableLocalCache()),
        ]),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
