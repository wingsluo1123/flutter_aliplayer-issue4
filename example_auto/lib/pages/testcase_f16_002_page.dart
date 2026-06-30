
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_global_setting.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F16-002：能查询系统亮度并返回当前亮度值
class TestCaseF16002Page extends StatefulWidget {
  const TestCaseF16002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF16002Page> createState() => _TestCaseF16002PageState();
}

class _TestCaseF16002PageState extends State<TestCaseF16002Page> {
  String _result = '';

  Future<void> _queryBrightness() async {
    try {
      final double? brightness = await FlutterAliPlayerGlobalSettings.getSystemBrightness();
      final String valueStr = brightness?.toStringAsFixed(2) ?? 'null';
      setState(() {
        _result = 'getSystemBrightness 调用成功\n'
            '当前亮度值: $valueStr (0.0~1.0)\n'
            '对应 0~255: ${brightness != null ? (brightness * 255).round().toString() : 'null'}\n'
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
      appBar: AppBar(title: const Text('F16-002 能查询系统亮度并返回当前亮度值')),
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
                          Text('前置条件: 应用已启动；全局设置演示页面已打开'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【查询亮度】按钮 (API: getSystemBrightness) [验证点: 验证【当前亮度】文本显示一个数值]; 2. 查看数值详情 [验证点: 验证返回的亮度值与实际屏幕亮度一致]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 查询系统亮度返回与实际屏幕亮度一致的数值'),
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
                    key: const Key('btn_query_brightness'),
                    onPressed: _queryBrightness,
                    child: const Text('查询亮度'),
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
