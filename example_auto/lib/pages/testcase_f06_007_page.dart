import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F06-007：设置播放器音量
class TestCaseF06007Page extends StatefulWidget {
  const TestCaseF06007Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF06007Page> createState() => _TestCaseF06007PageState();
}

class _TestCaseF06007PageState extends State<TestCaseF06007Page> {
  FlutterAliplayer? _player;
  String _result = '';
  bool _loop = false;
  bool _autoPlay = false;
  bool _muted = false;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _hardwareDecode = false;
  final TextEditingController _urlCtrl = TextEditingController();

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
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    try { await _player!.setUrl(url); setState(() { _result = 'URL已设置'; }); } catch (e) { setState(() { _result = '失败: $e'; }); }
  }
  Future<void> _prepare() async { try { await _player!.prepare(); setState(() { _result = '准备完成'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _play() async { try { await _player!.play(); setState(() { _result = '播放中'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _pause() async { try { await _player!.pause(); setState(() { _result = '已暂停'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }

  Future<void> _setLoop(bool v) async { try { await _player!.setLoop(v); setState(() { _loop = v; _result = '循环播放: $v'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _setAutoPlay(bool v) async { try { await _player!.setAutoPlay(v); setState(() { _autoPlay = v; _result = '自动播放: $v'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _setMuted(bool v) async { try { await _player!.setMuted(v); setState(() { _muted = v; _result = '静音: $v'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _setVolume(double v) async { try { await _player!.setVolume(v); setState(() { _volume = v; _result = '音量: $v'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _setSpeed(double v) async { try { await _player!.setSpeed(v); setState(() { _speed = v; _result = '倍速: $v'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _setHardwareDecode(bool v) async { try { await _player!.setEnableHardwareDecoder(v); setState(() { _hardwareDecode = v; _result = '硬件解码: $v'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }

  Future<void> _isLoop() async { try { final v = await _player!.isLoop(); setState(() { _result = '循环播放状态: $v'; }); } catch (e) { setState(() { _result = '查询失败: $e'; }); } }
  Future<void> _isAutoPlay() async { try { final v = await _player!.isAutoPlay(); setState(() { _result = '自动播放状态: $v'; }); } catch (e) { setState(() { _result = '查询失败: $e'; }); } }
  Future<void> _enableHardwareDecoder() async { try { final v = await _player!.enableHardwareDecoder(); setState(() { _result = '硬件解码状态: $v'; }); } catch (e) { setState(() { _result = '查询失败: $e'; }); } }
  Future<void> _getVolume() async { try { final v = await _player!.getVolume(); setState(() { _result = '当前音量: $v'; }); } catch (e) { setState(() { _result = '查询失败: $e'; }); } }

  @override
  void dispose() {
    _player?.release();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F06-007 设置播放器音量')),
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
                          Text('预期结果: 视频音量调整为原始音量的50%'),
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
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_prepare'), onPressed: _prepare, child: const Text('准备')),
                      ElevatedButton(key: const Key('btn_play'), onPressed: _play, child: const Text('播放')),
                      ElevatedButton(key: const Key('btn_pause'), onPressed: _pause, child: const Text('暂停')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('循环播放:'),
                      Switch(key: const Key('switch_loop'), value: _loop, onChanged: _setLoop),
                      const SizedBox(width: 16),
                      const Text('自动播放:'),
                      Switch(key: const Key('switch_auto_play'), value: _autoPlay, onChanged: _setAutoPlay),
                      const SizedBox(width: 16),
                      const Text('静音:'),
                      Switch(key: const Key('switch_mute'), value: _muted, onChanged: _setMuted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('音量:'),
                      SizedBox(
                        width: 100,
                        child: Slider(
                          key: const Key('slider_volume'),
                          value: _volume,
                          min: 0, max: 2,
                          onChanged: (v) => _setVolume(v),
                        ),
                      ),
                      Text('$_volume'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('倍速:'),
                      DropdownButton<double>(
                        key: const Key('dropdown_speed'),
                        value: _speed,
                        items: const [
                          DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                          DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                          DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                        onChanged: (v) => v != null ? _setSpeed(v) : null,
                      ),
                      const SizedBox(width: 16),
                      const Text('硬件解码:'),
                      Switch(key: const Key('switch_hardware_decode'), value: _hardwareDecode, onChanged: _setHardwareDecode),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_is_loop'), onPressed: _isLoop, child: const Text('查询循环状态')),
                      ElevatedButton(key: const Key('btn_is_auto_play'), onPressed: _isAutoPlay, child: const Text('查询自动播放')),
                      ElevatedButton(key: const Key('btn_is_hardware'), onPressed: _enableHardwareDecoder, child: const Text('查询解码状态')),
                      ElevatedButton(key: const Key('btn_get_volume'), onPressed: _getVolume, child: const Text('获取音量')),
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
