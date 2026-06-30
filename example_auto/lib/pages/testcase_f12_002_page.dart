
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_alilistplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F12-002：能切换到下一个播放源并播放下一项内容
class TestCaseF12002Page extends StatefulWidget {
  const TestCaseF12002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF12002Page> createState() => _TestCaseF12002PageState();
}

class _TestCaseF12002PageState extends State<TestCaseF12002Page> {
  String _result = '';
  late final FlutterAliListPlayer _listPlayer;
  final List<Map<String, String>> _sourceList = <Map<String, String>>[];
  bool _prepared = false;

  static const String _url1 =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';
  static const String _url2 =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _listPlayer = FlutterAliPlayerFactory.createAliListPlayer(playerId: 'f12_002');
    _listPlayer.setOnPrepared((String playerId) {
      if (!_prepared) {
        _prepared = true;
        _listPlayer.play();
      }
    });
  }

  @override
  void dispose() {
    _listPlayer.release();
    super.dispose();
  }

  Future<void> _initList(int viewId) async {
    try {
      await _listPlayer.setPlayerView(viewId);
      await _listPlayer.addUrlSource(url: _url1, uid: 'list_uid_1');
      _sourceList.add(<String, String>{'uid': 'list_uid_1', 'url': _url1});
      await _listPlayer.addUrlSource(url: _url2, uid: 'list_uid_2');
      _sourceList.add(<String, String>{'uid': 'list_uid_2', 'url': _url2});
      await _listPlayer.prepare();
      setState(() {
        _result = '列表已初始化 ${_sourceList.length} 项，已 prepare 并播放第一项\n'
            '1. list_uid_1\n2. list_uid_2\n'
            '点击【下一个】按钮验证 moveToNext';
      });
    } catch (e) {
      setState(() {
        _result = 'init error: $e';
      });
    }
  }

  Future<void> _moveNext() async {
    try {
      await _listPlayer.moveToNext();
      final dynamic currentUid = await _listPlayer.getCurrentUid();
      setState(() {
        _result = 'moveToNext 调用成功\n'
            '当前项 uid: ${currentUid?.toString() ?? 'null'}\n'
            '列表项: 1.list_uid_1  2.list_uid_2';
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
      appBar: AppBar(title: const Text('F12-002 能切换到下一个播放源并播放下一项内容')),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 200,
            width: double.infinity,
            child: AliPlayerView(
              onCreated: (int viewId) {
                _initList(viewId);
              },
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
                          Text('前置条件: 应用已启动；列表中已有至少 2 项；当前正在播放第一项'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【下一个】按钮 (API: moveToNext) [验证点: 验证【当前项】文本显示为列表中第二项]; 2. 观察【播放器容器】区域 [验证点: 验证画面切换为下一项内容且列表指针前移]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 切换到下一个播放源后播放下一项内容，列表指针前移'),
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
                    key: const Key('btn_move_next'),
                    onPressed: _moveNext,
                    child: const Text('下一个'),
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
