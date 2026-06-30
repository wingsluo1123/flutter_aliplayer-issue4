
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F08-002：能保存截图到指定路径并正确写入
class TestCaseF08002Page extends StatefulWidget {
  const TestCaseF08002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF08002Page> createState() => _TestCaseF08002PageState();
}

class _TestCaseF08002PageState extends State<TestCaseF08002Page> {
  String _result = '';
  FlutterAliplayer? _player;

  final TextEditingController _snapshotPathCtrl =
      TextEditingController(text: 'snapshot.png');

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _result = '播放器已准备 (onPrepared 触发)';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = '错误: [$errorCode] ${errorMsg ?? ''}';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _checkFile() async {
    final String path = _snapshotPathCtrl.text.trim();
    if (path.isEmpty) {
      setState(() {
        _result = '截图路径不能为空';
      });
      return;
    }
    try {
      final File file = File(path);
      final bool exists = await file.exists();
      if (!exists) {
        setState(() {
          _result = '文件检查结果:\n'
              '路径: $path\n'
              '状态: 文件不存在\n'
              '(注: 鸿蒙侧截图为 P2 安全空实现, 不会生成文件)';
        });
        return;
      }
      final int size = await file.length();
      setState(() {
        _result = '文件检查结果:\n'
            '路径: $path\n'
            '存在: 是\n'
            '大小: $size 字节\n'
            '非空: ${size > 0 ? "是" : "否"}';
      });
    } catch (e) {
      setState(() {
        _result = '文件检查失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _snapshotPathCtrl.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F08-002 能保存截图到指定路径并正确写入')),
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
                          Text('前置条件: 截图操作已完成；保存路径有效'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在文件管理器中打开截图保存目录 [验证点: 验证目录中存在截图文件]; 2. 查看截图文件属性 [验证点: 验证文件大小大于 0 且内容非空]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 截图文件存在于指定路径且内容非空，可被其他应用读取'),
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
                    key: const Key('input_snapshot_path'),
                    controller: _snapshotPathCtrl,
                    decoration: const InputDecoration(
                      labelText: '截图路径',
                      hintText: 'snapshot.png',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_check_file'),
                    onPressed: _checkFile,
                    child: const Text('检查文件'),
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
