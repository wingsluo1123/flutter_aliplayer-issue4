
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_global_setting.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F16-001：能设置系统亮度并改变屏幕亮度
class TestCaseF16001Page extends StatefulWidget {
  const TestCaseF16001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF16001Page> createState() => _TestCaseF16001PageState();
}

class _TestCaseF16001PageState extends State<TestCaseF16001Page> {
  String _result = '';
  double _brightness = 0.5;

  Future<void> _applyBrightness(double value) async {
    setState(() {
      _brightness = value;
      _result = 'setSystemBrightness 调用成功\n'
          '当前亮度值: ${value.toStringAsFixed(2)} (0.0~1.0)\n'
          '对应 0~255: ${(value * 255).round()}';
    });
    try {
      await FlutterAliPlayerGlobalSettings.setSystemBrightness(value);
      setState(() {
        _result = 'setSystemBrightness 调用成功\n'
            '当前亮度值: ${value.toStringAsFixed(2)} (0.0~1.0)\n'
            '对应 0~255: ${(value * 255).round()}\n'
            '屏幕亮度应随设置值变化';
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
      appBar: AppBar(title: const Text('F16-001 能设置系统亮度并改变屏幕亮度')),
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
                          Text('前置条件: 应用已启动；全局设置演示页面已打开；设备支持亮度调节'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 拖动【亮度滑块】到中间位置 (API: setSystemBrightness, brightness: 128) [验证点: 验证滑块位置在中间]; 2. 观察屏幕亮度 [验证点: 验证屏幕亮度随设置值变化]; 3. 拖动【亮度滑块】到最右端 (API: setSystemBrightness, brightness: 255) [验证点: 验证屏幕亮度达到最亮]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 设置系统亮度后屏幕亮度随设置值变化'),
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
                  Text('当前亮度: ${_brightness.toStringAsFixed(2)} (0~255: ${(_brightness * 255).round()})'),
                  Slider(
                    key: const Key('slider_brightness'),
                    value: _brightness,
                    min: 0.0,
                    max: 1.0,
                    divisions: 255,
                    label: '${(_brightness * 255).round()}',
                    onChanged: _applyBrightness,
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
