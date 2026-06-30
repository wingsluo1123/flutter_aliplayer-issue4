
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_alidownloader.dart';
import 'package:flutter_aliplayer/flutter_avpdef.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F14-001：能准备下载任务并获取可下载项信息
class TestCaseF14001Page extends StatefulWidget {
  const TestCaseF14001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF14001Page> createState() => _TestCaseF14001PageState();
}

class _TestCaseF14001PageState extends State<TestCaseF14001Page> {
  String _result = '';
  final TextEditingController _vidController = TextEditingController(text: 'test_vid_001');
  final TextEditingController _accessKeyIdController = TextEditingController(text: '');
  final TextEditingController _accessKeySecretController = TextEditingController(text: '');
  final TextEditingController _securityTokenController = TextEditingController(text: '');
  late final FlutterAliDownloader _downloader;

  @override
  void initState() {
    super.initState();
    _downloader = FlutterAliDownloader.init();
  }

  Future<void> _prepareDownload() async {
    final String vid = _vidController.text.trim();
    final String accessKeyId = _accessKeyIdController.text.trim();
    final String accessKeySecret = _accessKeySecretController.text.trim();
    final String securityToken = _securityTokenController.text.trim();
    if (vid.isEmpty) {
      setState(() {
        _result = '请输入视频 ID (vid)';
      });
      return;
    }
    setState(() {
      _result = '下载状态: 准备中...\n'
          'type: ${FlutterAvpdef.DOWNLOADTYPE_STS}\n'
          'vid: $vid';
    });
    try {
      final dynamic res = await _downloader.prepare(
        FlutterAvpdef.DOWNLOADTYPE_STS,
        vid,
        region: 'cn-shanghai',
        accessKeyId: accessKeyId,
        accessKeySecret: accessKeySecret,
        securityToken: securityToken,
      );
      setState(() {
        _result = 'prepare 调用成功\n'
            '下载状态: 已准备\n'
            'type: ${FlutterAvpdef.DOWNLOADTYPE_STS}\n'
            'vid: $vid\n'
            '返回结果: ${res?.toString() ?? 'null'}\n'
            '等待 download_prepared 事件触发以获取可下载项列表';
      });
    } catch (e) {
      setState(() {
        _result = 'error: $e';
      });
    }
  }

  @override
  void dispose() {
    _vidController.dispose();
    _accessKeyIdController.dispose();
    _accessKeySecretController.dispose();
    _securityTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F14-001 能准备下载任务并获取可下载项信息')),
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
                          Text('前置条件: 应用已启动；下载器演示页面已打开；有可用的视频源和凭证'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【vid 输入框】中输入视频 ID，在【凭证输入框】中输入凭证 (API: prepare, vid: 视频ID) [验证点: 验证输入框显示对应值]; 2. 点击【准备下载】按钮 (API: prepare) [验证点: 验证【下载状态】文本显示"准备中"]; 3. 等待 3 秒 [验证点: 验证 download_prepared 事件触发且返回可下载项列表]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 准备下载任务后 download_prepared 事件触发，返回可下载项列表'),
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
                    key: const Key('input_vid'),
                    controller: _vidController,
                    decoration: const InputDecoration(
                      labelText: 'vid 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_access_key_id'),
                    controller: _accessKeyIdController,
                    decoration: const InputDecoration(
                      labelText: 'accessKeyId 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_access_key_secret'),
                    controller: _accessKeySecretController,
                    decoration: const InputDecoration(
                      labelText: 'accessKeySecret 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_security_token'),
                    controller: _securityTokenController,
                    decoration: const InputDecoration(
                      labelText: 'securityToken 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_prepare_download'),
                    onPressed: _prepareDownload,
                    child: const Text('准备下载'),
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
