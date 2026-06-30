
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F06-003：能切换音频轨道并改变音轨语言
class TestCaseF06003Page extends StatefulWidget {
  const TestCaseF06003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF06003Page> createState() => _TestCaseF06003PageState();
}

class _TestCaseF06003PageState extends State<TestCaseF06003Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;

  final TextEditingController _trackIndexCtrl =
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
        _result = '播放器已准备 (onPrepared 触发)\n可输入音频轨道索引后点击【切换轨道】';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = '错误: [$errorCode] ${errorMsg ?? ''}';
      });
    });
    _player!.setOnTrackReady((String playerId) {
      setState(() {
        _result = '轨道就绪 (OnTrackReady 触发)';
      });
    });
    _player!.setOnTrackChanged((dynamic value, String playerId) {
      setState(() {
        _result = '音频轨道切换完成 (OnTrackChanged 触发)\nvalue: $value';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _selectTrack() async {
    try {
      final int trackIdx = int.tryParse(_trackIndexCtrl.text) ?? 0;
      setState(() {
        _result = '切换中... (selectTrack trackIdx=$trackIdx)';
      });
      await _player!.selectTrack(trackIdx);
      setState(() {
        _result = 'selectTrack 已调用 (trackIdx=$trackIdx)\n'
            '等待 OnTrackChanged 回调验证音轨语言变化';
      });
    } catch (e) {
      setState(() {
        _result = '切换轨道失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _trackIndexCtrl.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F06-003 能切换音频轨道并改变音轨语言')),
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
                          Text('前置条件: 应用已启动；播放器正在播放；视频包含多音轨'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【轨道列表】中选择一个不同语言的音频轨道 (API: selectTrack, trackIdx: 目标音轨) [验证点: 验证目标音轨被高亮选中]; 2. 点击【切换轨道】按钮 (API: selectTrack) [验证点: 验证【轨道状态】文本显示"切换中"]; 3. 等待 2 秒后观察播放声音 [验证点: 验证播放音轨对应所选轨道的语言]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 切换音频轨道后播放音轨对应所选轨道'),
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
                    key: const Key('input_track_index'),
                    controller: _trackIndexCtrl,
                    decoration: const InputDecoration(
                      labelText: '轨道索引 (trackIdx)',
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_select_track'),
                    onPressed: _isPrepared ? _selectTrack : null,
                    child: const Text('切换轨道'),
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
