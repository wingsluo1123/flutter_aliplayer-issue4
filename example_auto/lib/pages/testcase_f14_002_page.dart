
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_alidownloader.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F14-002：能开始下载视频并触发进度与完成回调
class TestCaseF14002Page extends StatefulWidget {
  const TestCaseF14002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF14002Page> createState() => _TestCaseF14002PageState();
}

class _TestCaseF14002PageState extends State<TestCaseF14002Page> {
  String _result = '';
  final TextEditingController _saveDirController =
      TextEditingController(text: '/data/storage/el2/base/haps/entry/files/download');
  final TextEditingController _vidController = TextEditingController(text: 'test_vid_001');
  final TextEditingController _indexController = TextEditingController(text: '0');
  late final FlutterAliDownloader _downloader;
  StreamSubscription<dynamic>? _progressSub;

  @override
  void initState() {
    super.initState();
    _downloader = FlutterAliDownloader.init();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _saveDirController.dispose();
    _vidController.dispose();
    _indexController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final String saveDir = _saveDirController.text.trim();
    final String vid = _vidController.text.trim();
    final String indexStr = _indexController.text.trim();
    if (vid.isEmpty || indexStr.isEmpty) {
      setState(() {
        _result = '请输入 vid 与 index';
      });
      return;
    }
    final int index = int.tryParse(indexStr) ?? 0;
    try {
      _downloader.setSaveDir(saveDir);
      final Stream<dynamic>? progressStream = _downloader.start(vid, index);
      _progressSub?.cancel();
      _progressSub = progressStream?.listen(
        (dynamic event) {
          setState(() {
            _result = '下载进度事件: ${event.toString()}';
          });
        },
        onError: (Object error) {
          setState(() {
            _result = '下载错误: $error';
          });
        },
        onDone: () {
          setState(() {
            _result = '下载完成 (onDone)\nvid: $vid\nindex: $index\nsaveDir: $saveDir';
          });
        },
      );
      setState(() {
        _result = 'start 调用成功\n'
            '下载状态: 进行中\n'
            'vid: $vid\n'
            'index: $index\n'
            'saveDir: $saveDir\n'
            '等待 download_progress 与 download_completion 事件';
      });
    } catch (e) {
      setState(() {
        _result = 'error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F14-002 能开始下载视频并触发进度与完成回调')),
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
                          Text('前置条件: 下载任务已准备完成；已选择下载项；保存目录可写'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【保存目录输入框】中输入路径 (API: setSaveDir, path: 保存路径) [验证点: 验证输入框显示路径]; 2. 在【可下载项列表】中选择一项后点击【开始下载】按钮 (API: start, vid: 视频ID, index: 项索引) [验证点: 验证【下载进度】文本显示百分比且持续增长]; 3. 等待下载完成 [验证点: 验证 download_progress 与 download_completion 事件触发且文件生成]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 开始下载后触发进度回调，最终完成时触发 completion 事件且文件生成'),
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
                  TextField(
                    key: const Key('input_save_dir'),
                    controller: _saveDirController,
                    decoration: const InputDecoration(
                      labelText: '保存目录输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_vid'),
                    controller: _vidController,
                    decoration: const InputDecoration(
                      labelText: 'vid 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_index'),
                    controller: _indexController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'index 项索引输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_start_download'),
                    onPressed: _startDownload,
                    child: const Text('开始下载'),
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
