import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F03-005：停止视频播放
class TestCaseF03005Page extends StatefulWidget {
  const TestCaseF03005Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF03005Page> createState() => _TestCaseF03005PageState();
}

class _TestCaseF03005PageState extends State<TestCaseF03005Page> {
  FlutterAliplayer? _player;
  String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _seekCtrl = TextEditingController();
  final TextEditingController _startTimeCtrl = TextEditingController();
  final TextEditingController _maxDeltaCtrl = TextEditingController();
  int _seekMode = 1;

  @override
  void initState() {
    super.initState();
    _createPlayer();
  }

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      await _player!.create();
      setState(() { _result = '播放器已创建'; });
    } catch (e) { setState(() { _result = '创建失败: $e'; }); }
  }

  Future<void> _setUrl() async {
    try {
      final url = _urlCtrl.text.trim();
      if (url.isEmpty) { setState(() { _result = '请输入URL'; }); return; }
      await _player!.setUrl(url);
      setState(() { _result = 'URL已设置: $url'; });
    } catch (e) { setState(() { _result = '设置URL失败: $e'; }); }
  }

  Future<void> _prepare() async {
    try {
      await _player!.prepare();
      setState(() { _result = '准备完成'; });
    } catch (e) { setState(() { _result = '准备失败: $e'; }); }
  }

  Future<void> _play() async {
    try {
      await _player!.play();
      setState(() { _result = '播放中'; });
    } catch (e) { setState(() { _result = '播放失败: $e'; }); }
  }

  Future<void> _pause() async {
    try {
      await _player!.pause();
      setState(() { _result = '已暂停'; });
    } catch (e) { setState(() { _result = '暂停失败: $e'; }); }
  }

  Future<void> _stop() async {
    try {
      await _player!.stop();
      setState(() { _result = '已停止'; });
    } catch (e) { setState(() { _result = '停止失败: $e'; }); }
  }

  Future<void> _seek() async {
    final pos = int.tryParse(_seekCtrl.text.trim()) ?? 0;
    try {
      await _player!.seekTo(pos, _seekMode);
      setState(() { _result = '已跳转到: $pos ms'; });
    } catch (e) { setState(() { _result = '跳转失败: $e'; }); }
  }

  Future<void> _reload() async {
    try {
      await _player!.reload();
      setState(() { _result = '已重新加载'; });
    } catch (e) { setState(() { _result = '重新加载失败: $e'; }); }
  }

  Future<void> _setStartTime() async {
    final time = int.tryParse(_startTimeCtrl.text.trim()) ?? 0;
    try {
      await _player!.setStartTime(time, _seekMode);
      setState(() { _result = '起播时间已设置: $time ms'; });
    } catch (e) { setState(() { _result = '设置起播时间失败: $e'; }); }
  }

  Future<void> _setMaxDelta() async {
    final delta = int.tryParse(_maxDeltaCtrl.text.trim()) ?? 5000;
    try {
      await _player!.setMaxAccurateSeekDelta(delta);
      setState(() { _result = '精准seek最大间隔已设置: $delta ms'; });
    } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  Future<void> _getDuration() async {
    try {
      final d = await _player!.getDuration();
      setState(() { _result = '视频总时长: $d ms'; });
    } catch (e) { setState(() { _result = '获取时长失败: $e'; }); }
  }

  Future<void> _getPosition() async {
    try {
      final pos = await _player!.getCurrentPosition();
      setState(() { _result = '当前位置: $pos ms'; });
    } catch (e) { setState(() { _result = '获取位置失败: $e'; }); }
  }

  Future<void> _getPlayedDuration() async {
    try {
      final d = await _player!.getPlayedDuration();
      setState(() { _result = '已播放时长: $d ms'; });
    } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }

  Future<void> _getUtcTime() async {
    try {
      final t = await _player!.getCurrentUtcTime();
      setState(() { _result = '当前UTC时间: $t'; });
    } catch (e) { setState(() { _result = '获取UTC时间失败: $e'; }); }
  }

  Future<void> _getBuffered() async {
    try {
      final pos = await _player!.getBufferedPosition();
      setState(() { _result = '已缓存位置: $pos ms'; });
    } catch (e) { setState(() { _result = '获取缓存位置失败: $e'; }); }
  }

  Future<void> _getDownloadSpeed() async {
    try {
      final speed = await _player!.getCurrentDownloadSpeed();
      setState(() { _result = '下载速度: $speed bps'; });
    } catch (e) { setState(() { _result = '获取下载速度失败: $e'; }); }
  }

  @override
  void dispose() {
    _player?.release();
    _urlCtrl.dispose(); _seekCtrl.dispose(); _startTimeCtrl.dispose(); _maxDeltaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F03-005 停止视频播放')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
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
                          Text('前置条件: 应用已启动，播放器正在播放视频'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 点击【停止】按钮 (API: stop)'),
                          const SizedBox(height: 4),
                          Text('预期结果: 播放停止，停止后需要重新准备才能再次播放'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Standard controls for all F-03 tests
                  TextField(
                    key: const Key('input_url'),
                    controller: _urlCtrl,
                    decoration: const InputDecoration(labelText: '视频URL', isDense: true),
                  ),
                  ElevatedButton(
                    key: const Key('btn_set_url'),
                    onPressed: _setUrl,
                    child: const Text('设置URL源'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_prepare'), onPressed: _prepare, child: const Text('准备')),
                      ElevatedButton(key: const Key('btn_play'), onPressed: _play, child: const Text('播放')),
                      ElevatedButton(key: const Key('btn_pause'), onPressed: _pause, child: const Text('暂停')),
                      ElevatedButton(key: const Key('btn_stop'), onPressed: _stop, child: const Text('停止')),
                      ElevatedButton(key: const Key('btn_reload'), onPressed: _reload, child: const Text('重新加载')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(width: 100, child: TextField(
                        key: const Key('input_seek_pos'),
                        controller: _seekCtrl,
                        decoration: const InputDecoration(labelText: '跳转位置(ms)', isDense: true),
                      )),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _seekMode,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('精确模式')),
                          DropdownMenuItem(value: 16, child: Text('非精确模式')),
                        ],
                        onChanged: (v) => setState(() => _seekMode = v ?? 1),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(key: const Key('btn_seek'), onPressed: _seek, child: const Text('跳转')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(width: 120, child: TextField(
                        controller: _startTimeCtrl,
                        decoration: const InputDecoration(labelText: '起播位置(ms)', isDense: true),
                      )),
                      ElevatedButton(key: const Key('btn_set_start_time'), onPressed: _setStartTime, child: const Text('设置起播')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(width: 120, child: TextField(
                        controller: _maxDeltaCtrl,
                        decoration: const InputDecoration(labelText: '精准seek间隔(ms)', isDense: true),
                      )),
                      ElevatedButton(key: const Key('btn_set_max_delta'), onPressed: _setMaxDelta, child: const Text('应用')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_get_duration'), onPressed: _getDuration, child: const Text('获取总时长')),
                      ElevatedButton(key: const Key('btn_get_position'), onPressed: _getPosition, child: const Text('获取当前位置')),
                      ElevatedButton(key: const Key('btn_get_played'), onPressed: _getPlayedDuration, child: const Text('获取已播放时长')),
                      ElevatedButton(key: const Key('btn_get_utc'), onPressed: _getUtcTime, child: const Text('获取UTC时间')),
                      ElevatedButton(key: const Key('btn_get_buffered'), onPressed: _getBuffered, child: const Text('获取缓存位置')),
                      ElevatedButton(key: const Key('btn_get_speed'), onPressed: _getDownloadSpeed, child: const Text('获取下载速度')),
                    ],
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
