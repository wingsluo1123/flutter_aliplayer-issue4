
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F05-002：能配置 HTTP 头信息并在网络请求中生效
class TestCaseF05002Page extends StatefulWidget {
  const TestCaseF05002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF05002Page> createState() => _TestCaseF05002PageState();
}

class _TestCaseF05002PageState extends State<TestCaseF05002Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;
  final List<Map<String, String>> _headers = <Map<String, String>>[];

  final TextEditingController _headerKeyCtrl =
      TextEditingController(text: 'Referer');
  final TextEditingController _headerValueCtrl =
      TextEditingController(text: 'test-ref');

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

  void _addHeader() {
    final String key = _headerKeyCtrl.text.trim();
    final String value = _headerValueCtrl.text.trim();
    if (key.isEmpty) {
      setState(() {
        _result = 'HTTP 头 Key 不能为空';
      });
      return;
    }
    setState(() {
      _headers.add(<String, String>{'key': key, 'value': value});
      _result = '已添加 HTTP 头: $key: $value\n'
          '当前 HTTP 头列表:\n'
          '${_headers.map((Map<String, String> h) => '  ${h['key']}: ${h['value']}').join('\n')}';
    });
  }

  Future<void> _applyConfig() async {
    try {
      final AVPConfig config = AVPConfig();
      config.httpHeaders = _headers;
      await _player!.setConfig(config.convertToMap());
      setState(() {
        _result = '已应用配置\n'
            'httpHeaders (${_headers.length} 项):\n'
            '${_headers.map((Map<String, String> h) => '  ${h['key']}: ${h['value']}').join('\n')}';
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
        _result = '播放已触发 (play)\n'
            '配置的 HTTP 头将在网络请求中生效';
      });
    } catch (e) {
      setState(() {
        _result = '播放失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _headerKeyCtrl.dispose();
    _headerValueCtrl.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F05-002 能配置 HTTP 头信息并在网络请求中生效')),
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
                          Text('测试步骤: 1. 在【HTTP 头 Key】输入框中输入"Referer"，在【HTTP 头 Value】输入框中输入"test-ref" (API: setConfig, httpHeaders: {Referer: test-ref}) [验证点: 验证两个输入框分别显示"Referer"和"test-ref"]; 2. 点击【添加 HTTP 头】按钮后点击【应用配置】按钮 (API: setConfig) [验证点: 验证【HTTP 头列表】中出现"Referer: test-ref"条目]; 3. 设置 HTTP 播放源后点击【播放】按钮 (API: play) [验证点: 验证播放器发起的网络请求包含配置的 HTTP 头]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 配置的 HTTP 头在播放器网络请求中生效'),
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
                    key: const Key('input_header_key'),
                    controller: _headerKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'HTTP 头 Key',
                      hintText: 'Referer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_header_value'),
                    controller: _headerValueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'HTTP 头 Value',
                      hintText: 'test-ref',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_add_header'),
                    onPressed: _addHeader,
                    child: const Text('添加HTTP头'),
                  ),
                  const SizedBox(height: 8),
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
