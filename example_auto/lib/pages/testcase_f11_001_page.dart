
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F11-001：能在 prepare 完成时触发准备完成事件
class TestCaseF11001Page extends StatefulWidget {
  const TestCaseF11001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF11001Page> createState() => _TestCaseF11001PageState();
}

class _TestCaseF11001PageState extends State<TestCaseF11001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isViewCreated = false;
  final List<String> _eventLog = <String>[];

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      _addEvent('onPrepared: playerId=$playerId');
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      _addEvent('onError: code=$errorCode, msg=$errorMsg, playerId=$playerId');
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
    _player!.setUrl(_testUrl);
    setState(() {
      _isViewCreated = true;
    });
  }

  Future<void> _prepare() async {
    _addEvent('prepare() 已调用, 等待 onPrepared 回调...');
    await _player!.prepare();
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F11-001 能在 prepare 完成时触发准备完成事件')),
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
                          Text('前置条件: 应用已启动；播放器实例已创建；已设置播放源'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【准备】按钮 (API: prepare) [验证点: 验证【事件日志】区域出现"onPrepared"事件条目]; 2. 查看【事件日志】中的 onPrepared 条目详情 [验证点: 验证回调字段正确且 playerId 与当前实例一致]'),
                          const SizedBox(height: 4),
                          Text('预期结果: prepare 完成后 onPrepared 回调触发，字段正确'),
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
                  ElevatedButton(
                    key: const Key('btn_prepare'),
                    onPressed: _isViewCreated ? _prepare : null,
                    child: const Text('准备'),
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
