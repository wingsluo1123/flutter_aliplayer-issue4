
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F09-004：能设置水平镜像并使画面水平翻转
class TestCaseF09004Page extends StatefulWidget {
  const TestCaseF09004Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF09004Page> createState() => _TestCaseF09004PageState();
}

class _TestCaseF09004PageState extends State<TestCaseF09004Page> {
  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  FlutterAliplayer? _player;
  int _mirrorMode = MirrorMode.MIRROR_MODE_HORIZONTAL;
  String _statusText = 'idle';
  String _result = '';

  static const List<int> _modes = <int>[
    MirrorMode.MIRROR_MODE_NONE,
    MirrorMode.MIRROR_MODE_HORIZONTAL,
    MirrorMode.MIRROR_MODE_VERTICAL,
  ];

  String _modeName(int mode) {
    switch (mode) {
      case MirrorMode.MIRROR_MODE_NONE:
        return '无';
      case MirrorMode.MIRROR_MODE_HORIZONTAL:
        return '水平镜像';
      case MirrorMode.MIRROR_MODE_VERTICAL:
        return '垂直镜像';
      default:
        return '未知';
    }
  }

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '已准备';
      });
      _player?.setMirrorMode(_mirrorMode);
      _player?.play();
    });
    _player!.setOnRenderingStart((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '播放中';
        _result = '首帧已渲染，当前镜像模式: ${_modeName(_mirrorMode)} (setMirrorMode($_mirrorMode))';
      });
    });
    _player!.setOnError((int errorCode, String? errorExtra, String? errorMsg,
        String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '错误';
        _result = 'onError: [$errorCode] ${errorMsg ?? ''}';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
    _player?.setUrl(_testUrl);
    _player?.prepare();
  }

  Future<void> _play() async {
    await _player?.play();
    setState(() {
      _statusText = '播放中';
      _result = '调用 play()，当前镜像模式: ${_modeName(_mirrorMode)}';
    });
  }

  Future<void> _onModeChanged(int? mode) async {
    if (mode == null) return;
    _mirrorMode = mode;
    await _player?.setMirrorMode(mode);
    setState(() {
      _statusText = '播放中';
      _result = '当前镜像模式: ${_modeName(mode)} (setMirrorMode($mode))';
    });
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F09-004 能设置水平镜像并使画面水平翻转')),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                const Text('播放状态: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_statusText, key: const Key('txt_status')),
                const Spacer(),
                Text('镜像模式: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_modeName(_mirrorMode)),
              ],
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
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
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
                          Text('前置条件: 应用已启动；播放器正在播放视频'),
                          const SizedBox(height: 4),
                          Text(
                              '测试步骤: 1. 在【镜像模式】下拉菜单中选择"水平镜像" (API: setMirrorMode, mode: H) [验证点: 验证下拉菜单显示"水平镜像"]; 2. 观察【播放器容器】区域 [验证点: 验证画面水平翻转显示]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 设置水平镜像后画面水平翻转显示'),
                          const SizedBox(height: 4),
                          Text('后置条件: '),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Actions',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('dropdown_mirror_mode'),
                    value: _mirrorMode,
                    decoration: const InputDecoration(
                      labelText: '镜像模式',
                      border: OutlineInputBorder(),
                    ),
                    items: _modes
                        .map((int m) => DropdownMenuItem<int>(
                              value: m,
                              child: Text(_modeName(m)),
                            ))
                        .toList(),
                    onChanged: _onModeChanged,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_play'),
                    onPressed: _play,
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
