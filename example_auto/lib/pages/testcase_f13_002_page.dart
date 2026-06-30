
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliliveshiftplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F13-002：能查询当前直播时间并返回现实时间
class TestCaseF13002Page extends StatefulWidget {
  const TestCaseF13002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF13002Page> createState() => _TestCaseF13002PageState();
}

class _TestCaseF13002PageState extends State<TestCaseF13002Page> {
  String _result = '';
  late final FlutterAliLiveShiftPlayer _liveShiftPlayer;

  static const String _timelineUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';
  static const String _url =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _liveShiftPlayer =
        FlutterAliPlayerFactory.createAliLiveShiftPlayer(playerId: 'f13_002');
  }

  @override
  void dispose() {
    _liveShiftPlayer.release();
    super.dispose();
  }

  Future<void> _initPlayer(int viewId) async {
    try {
      await _liveShiftPlayer.setPlayerView(viewId);
      await _liveShiftPlayer.setDataSource(_timelineUrl, _url);
      await _liveShiftPlayer.play();
      setState(() {
        _result = '时移播放器已创建并设置数据源，已请求播放\n点击【查询直播时间】按钮验证 getCurrentLiveTime';
      });
    } catch (e) {
      setState(() {
        _result = 'init error: $e';
      });
    }
  }

  Future<void> _queryLiveTime() async {
    try {
      final dynamic liveTime = await _liveShiftPlayer.getCurrentLiveTime();
      final String liveTimeStr = liveTime?.toString() ?? 'null';
      final bool nonZero = liveTime != null && liveTimeStr != '0' && liveTimeStr != 'null';
      setState(() {
        _result = 'getCurrentLiveTime 调用成功\n'
            '当前直播时间: $liveTimeStr\n'
            '非零时间值: ${nonZero ? "是" : "否"}\n'
            '现实时间参考: ${DateTime.now().toIso8601String()}';
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
      appBar: AppBar(title: const Text('F13-002 能查询当前直播时间并返回现实时间')),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 200,
            width: double.infinity,
            child: AliPlayerView(
              onCreated: (int viewId) {
                _initPlayer(viewId);
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
                          Text('前置条件: 应用已启动；时移流正在播放'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【查询直播时间】按钮 (API: getCurrentLiveTime) [验证点: 验证【当前直播时间】文本显示一个时间值]; 2. 查看时间值详情 [验证点: 验证返回的 liveTime 为非零时间值且接近当前现实时间]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 查询当前直播时间返回非零时间值，接近当前现实时间'),
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
                    key: const Key('btn_query_live_time'),
                    onPressed: _queryLiveTime,
                    child: const Text('查询直播时间'),
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
