
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F07-002：能启用外挂字幕并在画面显示字幕内容
class TestCaseF07002Page extends StatefulWidget {
  const TestCaseF07002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF07002Page> createState() => _TestCaseF07002PageState();
}

class _TestCaseF07002PageState extends State<TestCaseF07002Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;

  final TextEditingController _subtitleIndexCtrl =
      TextEditingController(text: '0');

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _isPrepared = true;
        _result = '播放器已准备 (onPrepared 触发)\n可输入字幕轨索引后点击【启用字幕】';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = '错误: [$errorCode] ${errorMsg ?? ''}';
      });
    });
    _player!.setOnSubtitleShow(
        (int trackIndex, int subtitleID, String subtitle, String playerId) {
      setState(() {
        _result = '字幕显示 (OnSubtitleShow 触发)\n'
            'trackIndex: $trackIndex\n'
            'subtitleID: $subtitleID\n'
            'subtitle: $subtitle';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _enableSubtitle() async {
    try {
      final int trackIndex = int.tryParse(_subtitleIndexCtrl.text) ?? 0;
      await _player!.selectExtSubtitle(trackIndex, true);
      setState(() {
        _result = 'selectExtSubtitle 已调用\n'
            'trackIndex: $trackIndex, enable: true\n'
            '等待 OnSubtitleShow 回调显示字幕内容';
      });
    } catch (e) {
      setState(() {
        _result = '启用字幕失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _subtitleIndexCtrl.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F07-002 能启用外挂字幕并在画面显示字幕内容')),
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
                          Text('前置条件: 应用已启动；已添加外挂字幕轨'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【字幕列表】中选择目标字幕轨 (API: selectExtSubtitle, trackIndex: 目标轨) [验证点: 验证目标字幕轨被高亮选中]; 2. 点击【启用字幕】开关 (API: selectExtSubtitle, enable: true) [验证点: 验证开关状态为"已启用"]; 3. 观察【播放器容器】区域 [验证点: 验证画面显示字幕内容且 OnSubtitleShow 回调触发]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 启用字幕后画面显示字幕内容，OnSubtitleShow 回调触发'),
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
                    key: const Key('input_subtitle_index'),
                    controller: _subtitleIndexCtrl,
                    decoration: const InputDecoration(
                      labelText: '字幕轨索引 (trackIndex)',
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_enable_subtitle'),
                    onPressed: _isPrepared ? _enableSubtitle : null,
                    child: const Text('启用字幕'),
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
