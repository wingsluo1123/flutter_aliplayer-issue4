
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F03-005：能精准跳转到指定位置
class TestCaseF03005Page extends StatefulWidget {
  const TestCaseF03005Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF03005Page> createState() => _TestCaseF03005PageState();
}

class _TestCaseF03005PageState extends State<TestCaseF03005Page> {
  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  FlutterAliplayer? _player;
  final TextEditingController _seekController =
      TextEditingController(text: '10000');
  int _duration = 0;
  int _currentPosition = 0;
  String _statusText = 'idle';
  String _result = '';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '已准备';
      });
      _player?.getDuration().then((dynamic d) {
        if (!mounted) return;
        setState(() {
          _duration = (d as num?)?.toInt() ?? 0;
          _result = '已准备，视频时长 = $_duration ms，可输入跳转位置后点击精准跳转';
        });
      });
      _player?.play();
    });
    _player!.setOnRenderingStart((String playerId) {
      if (!mounted) return;
      setState(() {
        _statusText = '播放中';
      });
    });
    _player!.setOnSeekComplete((String playerId) {
      _player?.getCurrentPosition().then((dynamic pos) {
        if (!mounted) return;
        final int afterTime = (pos as num?)?.toInt() ?? 0;
        setState(() {
          _statusText = '跳转完成';
          _result = '$_result\nonSeekComplete 回调触发\n跳转后 currentTime = $afterTime ms';
        });
      });
    });
    _player!.setOnInfo((int? infoCode, int? extraValue, String? extraMsg,
        String playerId) {
      if (infoCode == 2 && extraValue != null) {
        if (!mounted) return;
        setState(() {
          _currentPosition = (extraValue as num).toInt();
        });
      }
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

  Future<void> _seek() async {
    final int target = int.tryParse(_seekController.text.trim()) ?? 0;
    final dynamic before = await _player?.getCurrentPosition();
    final int beforeTime = (before as num?)?.toInt() ?? 0;
    setState(() {
      _statusText = '跳转中';
      _result = '跳转前 currentTime = $beforeTime ms\n'
          '目标位置 = $target ms\n'
          '调用 seekTo($target, SeekMode.ACCURATE)，等待 onSeekComplete 回调...';
    });
    await _player?.seekTo(target, SeekMode.ACCURATE);
  }

  @override
  void dispose() {
    _seekController.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F03-005 能精准跳转到指定位置')),
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
                Text('当前时间: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$_currentPosition ms',
                    key: const Key('txt_current_time')),
                const SizedBox(width: 8),
                Text('时长: $_duration ms'),
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
                          Text('前置条件: 应用已启动；播放器正在播放视频；视频时长已知'),
                          const SizedBox(height: 4),
                          Text(
                              '测试步骤: 1. 在【跳转位置输入框】中输入目标位置数值（毫秒） (API: seekTo, position: 目标值, seekMode: Accurate) [验证点: 验证输入框显示目标位置数值]; 2. 点击【精准跳转】按钮 (API: seekTo) [验证点: 验证【播放状态】短暂显示"跳转中"]; 3. 等待 2 秒后观察【当前时间】文本 [验证点: 验证 currentTime 接近目标值且 onSeekComplete 回调触发]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 精准跳转后 currentTime 接近目标值，onSeekComplete 事件触发'),
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
                  TextField(
                    key: const Key('input_seek_position'),
                    controller: _seekController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '跳转位置（毫秒）',
                      hintText: '例如 10000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_seek'),
                    onPressed: _seek,
                    child: const Text('精准跳转'),
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
