
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F11-003：能在视频结束时触发播放完成事件
class TestCaseF11003Page extends StatefulWidget {
  const TestCaseF11003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF11003Page> createState() => _TestCaseF11003PageState();
}

class _TestCaseF11003PageState extends State<TestCaseF11003Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;
  final List<String> _eventLog = <String>[];

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      _addEvent('onPrepared: playerId=$playerId');
      setState(() {
        _isPrepared = true;
      });
    });
    _player!.setOnCompletion((String playerId) {
      _addEvent('onCompletion: playerId=$playerId');
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
    _player!.prepare();
  }

  Future<void> _play() async {
    _addEvent('play() 已调用, 等待视频播放结束触发 onCompletion...');
    await _player!.play();
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F11-003 能在视频结束时触发播放完成事件')),
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
                          Text('前置条件: 应用已启动；播放器正在播放短视频'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 等待视频自然播放结束 [验证点: 验证【事件日志】区域出现"onCompletion"事件条目]; 2. 查看【事件日志】中的 onCompletion 条目 [验证点: 验证回调字段正确]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 视频播放结束时 onCompletion 回调触发'),
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
