
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliliveshiftplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F13-001：能设置时移数据源并加载时移流
class TestCaseF13001Page extends StatefulWidget {
  const TestCaseF13001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF13001Page> createState() => _TestCaseF13001PageState();
}

class _TestCaseF13001PageState extends State<TestCaseF13001Page> {
  String _result = '';
  final TextEditingController _timelineUrlController = TextEditingController(
    text:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  );
  final TextEditingController _urlController = TextEditingController(
    text:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  );
  late final FlutterAliLiveShiftPlayer _liveShiftPlayer;
  bool _dataSourceSet = false;

  @override
  void initState() {
    super.initState();
    _liveShiftPlayer =
        FlutterAliPlayerFactory.createAliLiveShiftPlayer(playerId: 'f13_001');
  }

  @override
  void dispose() {
    _liveShiftPlayer.release();
    _timelineUrlController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _setDataSource() async {
    final String timelineUrl = _timelineUrlController.text.trim();
    final String url = _urlController.text.trim();
    if (timelineUrl.isEmpty || url.isEmpty) {
      setState(() {
        _result = '请输入 timelineUrl 与播放地址';
      });
      return;
    }
    setState(() {
      _result = '时移状态: 加载中...\ntimeLineUrl: $timelineUrl\nurl: $url';
    });
    try {
      await _liveShiftPlayer.setDataSource(timelineUrl, url);
      _dataSourceSet = true;
      setState(() {
        _result = 'setDataSource 调用成功\n'
            '时移状态: 已加载\n'
            'timeLineUrl: $timelineUrl\n'
            'url: $url\n'
            '可点击【播放】按钮开始播放';
      });
    } catch (e) {
      setState(() {
        _result = 'error: $e';
      });
    }
  }

  Future<void> _play() async {
    try {
      await _liveShiftPlayer.play();
      setState(() {
        _result = 'play 调用成功\n'
            '时移流已请求播放\n'
            'dataSourceSet: $_dataSourceSet';
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
      appBar: AppBar(title: const Text('F13-001 能设置时移数据源并加载时移流')),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 200,
            width: double.infinity,
            child: AliPlayerView(
              onCreated: (int viewId) {
                _liveShiftPlayer.setPlayerView(viewId);
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
                          Text('前置条件: 应用已启动；直播时移播放器实例已创建；有可用的时移数据源'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【timelineUrl 输入框】中输入时间轴地址，在【url 输入框】中输入播放地址 (API: setDataSource, timeLineUrl: 时间轴, url: 播放地址) [验证点: 验证两个输入框分别显示对应地址]; 2. 点击【设置时移源】按钮 (API: setDataSource) [验证点: 验证【时移状态】文本显示"加载中"]; 3. 等待 3 秒后点击【播放】按钮 (API: play) [验证点: 验证时移流加载成功且可播放]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 设置时移数据源后时移流加载成功，可正常播放'),
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
                    key: const Key('input_timeline_url'),
                    controller: _timelineUrlController,
                    decoration: const InputDecoration(
                      labelText: 'timelineUrl 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_url'),
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'url 输入框',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_set_datasource'),
                    onPressed: _setDataSource,
                    child: const Text('设置时移源'),
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
