
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F11-004：能在播放异常时触发播放错误事件
class TestCaseF11004Page extends StatefulWidget {
  const TestCaseF11004Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF11004Page> createState() => _TestCaseF11004PageState();
}

class _TestCaseF11004PageState extends State<TestCaseF11004Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isViewCreated = false;
  final List<String> _eventLog = <String>[];
  final TextEditingController _urlController = TextEditingController(
    text: 'https://invalid.example.com/video.mp4',
  );

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      _addEvent('onPrepared: playerId=$playerId');
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      _addEvent(
          'onError: code=$errorCode, extra=$errorExtra, msg=$errorMsg, playerId=$playerId');
    });
  }

  void _addEvent(String event) {
    setState(() {
      _eventLog.insert(
          0, '${DateTime.now().toIso8601String().substring(11, 19)} $event');
      _result = event;
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    setState(() {
      _isViewCreated = true;
    });
  }

  Future<void> _setUrl() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      _addEvent('URL 为空, 无法设置');
      return;
    }
    await _player!.setUrl(url);
    _addEvent('setUrl($url) 已调用');
  }

  Future<void> _play() async {
    _addEvent('play() 已调用, 等待 onError 回调...');
    await _player!.prepare();
    await _player!.play();
  }

  @override
  void dispose() {
    _player?.release();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F11-004 能在播放异常时触发播放错误事件')),
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
                          Text('前置条件: 应用已启动；播放器实例已创建；有无效播放源用于触发错误'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【URL 输入框】中输入无效播放源地址 (API: setUrl, url: 无效地址) [验证点: 验证输入框显示无效地址]; 2. 点击【设置播放源】按钮后点击【播放】按钮 (API: setUrl, play) [验证点: 验证【事件日志】区域出现"onError"事件条目]; 3. 查看 onError 事件详情 [验证点: 验证错误码字段正确且 playerId 一致]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 播放异常时 onError 回调触发，错误码字段正确'),
                          const SizedBox(height: 4),
                          Text('后置条件: '),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '事件日志',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _eventLog.isEmpty
                        ? const Center(
                            child: Text('暂无事件',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _eventLog.length,
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                dense: true,
                                title: Text(
                                  _eventLog[index],
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 12),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_url'),
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL 输入框',
                      border: OutlineInputBorder(),
                      hintText: '输入播放源地址',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_set_url'),
                    onPressed: _isViewCreated ? _setUrl : null,
                    child: const Text('设置播放源'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_play'),
                    onPressed: _isViewCreated ? _play : null,
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
