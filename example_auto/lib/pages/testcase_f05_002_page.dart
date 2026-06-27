import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F05-002：设置视频保持比例裁剪填充模式
class TestCaseF05002Page extends StatefulWidget {
  const TestCaseF05002Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF05002Page> createState() => _TestCaseF05002PageState();
}

class _TestCaseF05002PageState extends State<TestCaseF05002Page> {
  FlutterAliplayer? _player;
  String _result = '';
  int _scalingMode = 2; // SCALE_ASPECT_FIT
  int _rotateMode = 0;
  int _mirrorMode = 0;
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

  Future<void> _setScalingMode(int mode) async {
    try { await _player!.setScalingMode(mode); setState(() { _scalingMode = mode; _result = '缩放模式已设置: $mode'; }); } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  Future<void> _setRotateMode(int mode) async {
    try { await _player!.setRotateMode(mode); setState(() { _rotateMode = mode; _result = '旋转模式已设置: $mode'; }); } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  Future<void> _setMirrorMode(int mode) async {
    try { await _player!.setMirrorMode(mode); setState(() { _mirrorMode = mode; _result = '镜像模式已设置: $mode'; }); } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  Future<void> _getScalingMode() async {
    try { final v = await _player!.getScalingMode(); setState(() { _result = '当前缩放模式: $v'; }); } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }
  Future<void> _getRotateMode() async {
    try { final v = await _player!.getRotateMode(); setState(() { _result = '当前旋转模式: $v'; }); } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }
  Future<void> _getMirrorMode() async {
    try { final v = await _player!.getMirrorMode(); setState(() { _result = '当前镜像模式: $v'; }); } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }
  Future<void> _getVideoWidth() async {
    try { final v = await _player!.getVideoWidth(); setState(() { _result = '视频宽度: $v'; }); } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }
  Future<void> _getVideoHeight() async {
    try { final v = await _player!.getVideoHeight(); setState(() { _result = '视频高度: $v'; }); } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }
  Future<void> _getVideoRotation() async {
    try { final v = await _player!.getVideoRotation(); setState(() { _result = '视频旋转角度: $v'; }); } catch (e) { setState(() { _result = '获取失败: $e'; }); }
  }

  Future<void> _setBackgroundColor() async {
    try { await _player!.setVideoBackgroundColor(Colors.red.value); setState(() { _result = '背景色已设为红色'; }); } catch (e) { setState(() { _result = '设置失败: $e'; }); }
  }

  Future<void> _clearScreen() async {
    try { await _player!.clearScreen(); setState(() { _result = '画面已清空'; }); } catch (e) { setState(() { _result = '清空失败: $e'; }); }
  }

  @override
  void dispose() {
    _player?.release();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F05-002 设置视频保持比例裁剪填充模式')),
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
                          Text('预期结果: 视频画面填满显示区域，边缘部分被裁剪'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(labelText: '视频URL', isDense: true),
                  ),
                  ElevatedButton(key: const Key('btn_set_url'), onPressed: _setUrl, child: const Text('设置URL')),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_prepare'), onPressed: _prepare, child: const Text('准备')),
                      ElevatedButton(key: const Key('btn_play'), onPressed: _play, child: const Text('播放')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('缩放模式', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_scale_fit'), onPressed: () => _setScalingMode(2), child: const Text('保持比例(黑边)')),
                      ElevatedButton(key: const Key('btn_scale_fill'), onPressed: () => _setScalingMode(3), child: const Text('保持比例(裁剪)')),
                      ElevatedButton(key: const Key('btn_scale_fill_stretch'), onPressed: () => _setScalingMode(1), child: const Text('拉伸平铺')),
                      ElevatedButton(key: const Key('btn_get_scaling'), onPressed: _getScalingMode, child: const Text('查询缩放模式')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('旋转模式', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_rotate_0'), onPressed: () => _setRotateMode(0), child: const Text('0度')),
                      ElevatedButton(key: const Key('btn_rotate_90'), onPressed: () => _setRotateMode(90), child: const Text('90度')),
                      ElevatedButton(key: const Key('btn_rotate_180'), onPressed: () => _setRotateMode(180), child: const Text('180度')),
                      ElevatedButton(key: const Key('btn_rotate_270'), onPressed: () => _setRotateMode(270), child: const Text('270度')),
                      ElevatedButton(key: const Key('btn_get_rotate'), onPressed: _getRotateMode, child: const Text('查询旋转模式')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('镜像模式', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_mirror_none'), onPressed: () => _setMirrorMode(0), child: const Text('无镜像')),
                      ElevatedButton(key: const Key('btn_mirror_h'), onPressed: () => _setMirrorMode(1), child: const Text('水平镜像')),
                      ElevatedButton(key: const Key('btn_mirror_v'), onPressed: () => _setMirrorMode(2), child: const Text('垂直镜像')),
                      ElevatedButton(key: const Key('btn_get_mirror'), onPressed: _getMirrorMode, child: const Text('查询镜像模式')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(key: const Key('btn_get_width'), onPressed: _getVideoWidth, child: const Text('获取视频宽度')),
                      ElevatedButton(key: const Key('btn_get_height'), onPressed: _getVideoHeight, child: const Text('获取视频高度')),
                      ElevatedButton(key: const Key('btn_get_rotation'), onPressed: _getVideoRotation, child: const Text('获取旋转角度')),
                      ElevatedButton(key: const Key('btn_set_bg_red'), onPressed: _setBackgroundColor, child: const Text('设置红色背景')),
                      ElevatedButton(key: const Key('btn_clear_screen'), onPressed: _clearScreen, child: const Text('清空画面')),
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
