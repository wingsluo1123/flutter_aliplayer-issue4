
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F05-001：能配置缓冲水位并影响起播与卡顿恢复行为
class TestCaseF05001Page extends StatefulWidget {
  const TestCaseF05001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF05001Page> createState() => _TestCaseF05001PageState();
}

class _TestCaseF05001PageState extends State<TestCaseF05001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;

  final TextEditingController _startBufferCtrl =
      TextEditingController(text: '1000');
  final TextEditingController _maxBufferCtrl =
      TextEditingController(text: '30000');

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _isPrepared = true;
        _result = '播放器已准备 (onPrepared 触发)';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = '错误: [$errorCode] ${errorMsg ?? ''}';
      });
    });
    _player!.setOnRenderingStart((String playerId) {
      setState(() {
        _result = '首帧渲染开始 (onRenderingStart)';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _applyConfig() async {
    try {
      final int startBuffer = int.tryParse(_startBufferCtrl.text) ?? 1000;
      final int maxBuffer = int.tryParse(_maxBufferCtrl.text) ?? 30000;
      final AVPConfig config = AVPConfig();
      config.startBufferDuration = startBuffer;
      config.maxBufferDuration = maxBuffer;
      await _player!.setConfig(config.convertToMap());
      setState(() {
        _result = '已应用配置\n'
            'startBufferDuration: $startBuffer ms\n'
            'maxBufferDuration: $maxBuffer ms';
      });
    } catch (e) {
      setState(() {
        _result = '应用配置失败: $e';
      });
    }
  }

  Future<void> _play() async {
    try {
      await _player!.play();
      setState(() {
        _result = '播放已触发 (play)\n当前缓冲配置影响起播与卡顿恢复行为';
      });
    } catch (e) {
      setState(() {
        _result = '播放失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _startBufferCtrl.dispose();
    _maxBufferCtrl.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F05-001 能配置缓冲水位并影响起播与卡顿恢复行为')),
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
                          Text('前置条件: 应用已启动；播放器实例已创建；尚未设置播放源'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【起始缓冲】输入框中输入"1000" (API: setConfig, startBuffer: 1000) [验证点: 验证输入框显示"1000"]; 2. 在【最大缓冲】输入框中输入"30000"后点击【应用配置】按钮 (API: setConfig, maxBuffer: 30000) [验证点: 验证【配置状态】文本显示"已应用"]; 3. 设置播放源后点击【播放】按钮 (API: play) [验证点: 验证起播速度与卡顿恢复行为符合配置]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 缓冲水位配置生效，起播与卡顿恢复行为符合配置值'),
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
                    key: const Key('input_start_buffer'),
                    controller: _startBufferCtrl,
                    decoration: const InputDecoration(
                      labelText: '起始缓冲 (ms)',
                      hintText: '1000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_max_buffer'),
                    controller: _maxBufferCtrl,
                    decoration: const InputDecoration(
                      labelText: '最大缓冲 (ms)',
                      hintText: '30000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_apply_config'),
                    onPressed: _applyConfig,
                    child: const Text('应用配置'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_play'),
                    onPressed: _isPrepared ? _play : null,
                    child: const Text('播放'),
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
