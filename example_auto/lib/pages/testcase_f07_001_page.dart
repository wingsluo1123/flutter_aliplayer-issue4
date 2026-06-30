
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F07-001：能添加外挂字幕并加载字幕文件
class TestCaseF07001Page extends StatefulWidget {
  const TestCaseF07001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF07001Page> createState() => _TestCaseF07001PageState();
}

class _TestCaseF07001PageState extends State<TestCaseF07001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;

  final TextEditingController _subtitleUrlCtrl =
      TextEditingController(text: '');

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _isPrepared = true;
        _result = '播放器已准备 (onPrepared 触发)\n可输入字幕 URL 后点击【添加字幕】';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = '错误: [$errorCode] ${errorMsg ?? ''}';
      });
    });
    _player!.setOnSubtitleExtAdded(
        (int trackIndex, String url, String playerId) {
      setState(() {
        _result = '外挂字幕已添加 (OnSubtitleExtAdded 触发)\n'
            'trackIndex: $trackIndex\n'
            'url: $url';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _addSubtitle() async {
    final String url = _subtitleUrlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = '字幕 URL 不能为空';
      });
      return;
    }
    try {
      await _player!.addExtSubtitle(url);
      setState(() {
        _result = 'addExtSubtitle 已调用\nurl: $url\n等待 OnSubtitleExtAdded 回调';
      });
    } catch (e) {
      setState(() {
        _result = '添加字幕失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _subtitleUrlCtrl.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F07-001 能添加外挂字幕并加载字幕文件')),
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
                          Text('前置条件: 应用已启动；播放器正在播放；有可用的外挂字幕 URL'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【字幕 URL 输入框】中输入字幕文件地址 (API: addExtSubtitle, url: 字幕地址) [验证点: 验证输入框显示字幕地址]; 2. 点击【添加字幕】按钮 (API: addExtSubtitle) [验证点: 验证【字幕列表】中出现新字幕条目且 OnSubtitleExtAdded 回调触发]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 添加外挂字幕后字幕轨可用，OnSubtitleExtAdded 回调触发'),
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
                    key: const Key('input_subtitle_url'),
                    controller: _subtitleUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: '字幕 URL',
                      hintText: 'https://example.com/subtitle.srt',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_add_subtitle'),
                    onPressed: _isPrepared ? _addSubtitle : null,
                    child: const Text('添加字幕'),
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
