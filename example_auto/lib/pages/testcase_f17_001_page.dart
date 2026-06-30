
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F17-001：能查询 SDK 版本号并返回非空版本字符串
class TestCaseF17001Page extends StatefulWidget {
  const TestCaseF17001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF17001Page> createState() => _TestCaseF17001PageState();
}

class _TestCaseF17001PageState extends State<TestCaseF17001Page> {
  String _result = '';

  Future<void> _queryVersion() async {
    try {
      final dynamic version = await FlutterAliplayer.getSDKVersion();
      final String versionStr = version?.toString() ?? 'null';
      final bool nonEmpty = versionStr.isNotEmpty && versionStr != 'null';
      setState(() {
        _result = 'getSDKVersion 调用成功\n'
            '版本号: $versionStr\n'
            '非空: ${nonEmpty ? "是" : "否"}\n'
            '查询时间: ${DateTime.now().toIso8601String()}';
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
      appBar: AppBar(title: const Text('F17-001 能查询 SDK 版本号并返回非空版本字符串')),
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
                          Text('前置条件: 应用已启动；全局播放器设置演示页面已打开'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【查询版本】按钮 (API: getSDKVersion) [验证点: 验证【版本号】文本显示一个字符串]; 2. 查看版本号字符串详情 [验证点: 验证字符串非空且格式合理（如 x.y.z）]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 查询 SDK 版本号返回非空且格式合理的版本字符串'),
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
                  ElevatedButton(
                    key: const Key('btn_query_version'),
                    onPressed: _queryVersion,
                    child: const Text('查询版本'),
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
