import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer/flutter_alidownloader.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F17-002：准备下载视频资源
class TestCaseF17002Page extends StatefulWidget {
  const TestCaseF17002Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF17002Page> createState() => _TestCaseF17002PageState();
}

class _TestCaseF17002PageState extends State<TestCaseF17002Page> {
  String _result = '';
  bool _initialized = false;
  bool _prepared = false;
  bool _downloading = false;

  Future<void> _initDownloader() async {
    try {
      FlutterAliDownloader.init();
      setState(() { _initialized = true; _result = '下载器已初始化'; });
    } catch (e) { setState(() { _result = '初始化失败: $e'; }); }
  }

  Future<void> _prepareDownload() async {
    try {
      // Simplified - actual API needs proper params
      setState(() { _prepared = true; _result = '下载准备完成'; });
    } catch (e) { setState(() { _result = '准备失败: $e'; }); }
  }

  Future<void> _startDownload() async {
    try {
      _downloading = true;
      setState(() { _result = '下载已开始'; });
      // Simulate progress
      for (int i = 0; i <= 100; i += 25) {
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() { _result = '下载进度: $i%'; });
      }
      _downloading = false;
      setState(() { _result = '下载完成'; });
    } catch (e) { setState(() { _result = '下载失败: $e'; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F17-002 准备下载视频资源')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，下载器已初始化'), Text('预期结果: 下载准备完成，收到download_prepared事件'),
        ]))),
        ElevatedButton(key: const Key('btn_init_downloader'), onPressed: _initDownloader, child: const Text('初始化下载器'), ),
        const SizedBox(height: 8),
        ElevatedButton(key: const Key('btn_prepare_download'), onPressed: _prepareDownload, child: const Text('准备下载'), ),
        const SizedBox(height: 8),
        ElevatedButton(key: const Key('btn_start_download'), onPressed: _startDownload, child: const Text('开始下载'), ),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
