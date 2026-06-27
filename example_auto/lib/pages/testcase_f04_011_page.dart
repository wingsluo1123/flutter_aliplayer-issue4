import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F04-011：播放器信息事件回调
class TestCaseF04011Page extends StatefulWidget {
  const TestCaseF04011Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF04011Page> createState() => _TestCaseF04011PageState();
}

class _TestCaseF04011PageState extends State<TestCaseF04011Page> {
  FlutterAliplayer? _player;
  String _result = '';
  final List<String> _eventLog = [];
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _seekCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _createPlayer();
  }

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      await _player!.create();
      _registerCallbacks();
      setState(() { _result = '播放器已创建，事件监听已注册'; });
    } catch (e) { setState(() { _result = '创建失败: $e'; }); }
  }

  void _registerCallbacks() {
    _player!.setOnPrepared((playerId) {
      _logEvent('onPrepared', 'playerId: $playerId');
    });
    _player!.setOnRenderingStart((playerId) {
      _logEvent('onRenderingStart', 'playerId: $playerId');
    });
    _player!.setOnVideoSizeChanged((width, height, rotation, playerId) {
      _logEvent('onVideoSizeChanged', 'w:$width h:$height rot:$rotation');
    });
    _player!.setOnSeekComplete((playerId) {
      _logEvent('onSeekComplete', 'playerId: $playerId');
    });
    _player!.setOnError((errorCode, errorExtra, errorMsg, playerId) {
      _logEvent('onError', 'code:$errorCode msg:$errorMsg');
    });
    _player!.setOnCompletion((playerId) {
      _logEvent('onCompletion', 'playerId: $playerId');
    });
    _player!.setOnStateChanged((newState, playerId) {
      _logEvent('onStateChanged', 'state:$newState playerId:$playerId');
    });
    _player!.setOnLoadingStatusListener(
      loadingBegin: (playerId) { _logEvent('onLoadingBegin', 'playerId: $playerId'); },
      loadingProgress: (percent, netSpeed, playerId) { _logEvent('onLoadingProgress', '$percent% $netSpeed'); },
      loadingEnd: (playerId) { _logEvent('onLoadingEnd', 'playerId: $playerId'); },
    );
    _player!.setOnVideoRendered((timeMs, pts, playerId) {
      _logEvent('onVideoRendered', 'timeMs:$timeMs pts:$pts');
    });
    _player!.setOnInfo((infoCode, extraValue, extraMsg, playerId) {
      _logEvent('onInfo', 'code:$infoCode val:$extraValue msg:$extraMsg');
    });
  }

  void _logEvent(String event, String details) {
    final log = '$event | $details';
    _eventLog.insert(0, log);
    setState(() { _result = '事件触发: $event'; });
  }

  Future<void> _setUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    try { await _player!.setUrl(url); setState(() { _result = 'URL已设置'; }); } catch (e) { setState(() { _result = '失败: $e'; }); }
  }

  Future<void> _prepare() async { try { await _player!.prepare(); setState(() { _result = '准备完成'; }); } catch (e) { setState(() { _result = '准备失败: $e'; }); } }
  Future<void> _play() async { try { await _player!.play(); setState(() { _result = '播放中'; }); } catch (e) { setState(() { _result = '播放失败: $e'; }); } }
  Future<void> _pause() async { try { await _player!.pause(); setState(() { _result = '已暂停'; }); } catch (e) { setState(() { _result = '暂停失败: $e'; }); } }
  Future<void> _stop() async { try { await _player!.stop(); setState(() { _result = '已停止'; }); } catch (e) { setState(() { _result = '停止失败: $e'; }); } }
  Future<void> _seek() async {
    final pos = int.tryParse(_seekCtrl.text.trim()) ?? 0;
    try { await _player!.seekTo(pos, 1); setState(() { _result = '跳转到: $pos ms'; }); } catch (e) { setState(() { _result = '跳转失败: $e'; }); }
  }

  @override
  void dispose() {
    _player?.release();
    _urlCtrl.dispose(); _seekCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F04-011 播放器信息事件回调')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('前置条件: 应用已启动，播放器正在播放视频，已注册事件监听'),
                          const SizedBox(height: 4),
                          Text('预期结果: onInfo回调携带正确的信息码和额外值'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_url'),
                    controller: _urlCtrl,
                    decoration: const InputDecoration(labelText: '视频URL', isDense: true),
                  ),
                  ElevatedButton(key: const Key('btn_set_url'), onPressed: _setUrl, child: const Text('设置URL')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_prepare'), onPressed: _prepare, child: const Text('准备')),
                      ElevatedButton(key: const Key('btn_play'), onPressed: _play, child: const Text('播放')),
                      ElevatedButton(key: const Key('btn_pause'), onPressed: _pause, child: const Text('暂停')),
                      ElevatedButton(key: const Key('btn_stop'), onPressed: _stop, child: const Text('停止')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(width: 100, child: TextField(
                        controller: _seekCtrl,
                        decoration: const InputDecoration(labelText: '跳转(ms)', isDense: true),
                      )),
                      ElevatedButton(key: const Key('btn_seek'), onPressed: _seek, child: const Text('跳转')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('事件日志', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _eventLog.length,
                      itemBuilder: (_, i) => Text(_eventLog[i], style: const TextStyle(fontSize: 11)),
                    ),
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
