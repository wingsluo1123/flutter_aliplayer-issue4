import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F02-003：通过VID+Auth方式设置授权播放源
class TestCaseF02003Page extends StatefulWidget {
  const TestCaseF02003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF02003Page> createState() => _TestCaseF02003PageState();
}

class _TestCaseF02003PageState extends State<TestCaseF02003Page> {
  FlutterAliplayer? _player;
  String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _vidCtrl = TextEditingController();
  final TextEditingController _akIdCtrl = TextEditingController();
  final TextEditingController _akSecretCtrl = TextEditingController();
  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _authCtrl = TextEditingController();
  final TextEditingController _mpsCtrl = TextEditingController();

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
    } catch (e) {
      setState(() { _result = '创建播放器失败: $e'; });
    }
  }

  Future<void> _setUrl() async {
    if (_player == null) return;
    try {
      final url = _urlCtrl.text.trim();
      if (url.isEmpty) { setState(() { _result = '请输入URL'; }); return; }
      await _player!.setUrl(url);
      setState(() { _result = 'URL源已设置'; });
    } catch (e) { setState(() { _result = '设置URL失败: $e'; }); }
  }

  Future<void> _setVidSts() async {
    if (_player == null) return;
    try {
      await _player!.setVidSts(
        vid: _vidCtrl.text.trim(),
        accessKeyId: _akIdCtrl.text.trim(),
        accessKeySecret: _akSecretCtrl.text.trim(),
        securityToken: _tokenCtrl.text.trim(),
      );
      setState(() { _result = 'VID+STS源已设置'; });
    } catch (e) { setState(() { _result = '设置VID+STS失败: $e'; }); }
  }

  Future<void> _setVidAuth() async {
    if (_player == null) return;
    try {
      await _player!.setVidAuth(
        vid: _vidCtrl.text.trim(),
        playAuth: _authCtrl.text.trim(),
      );
      setState(() { _result = 'VID+Auth源已设置'; });
    } catch (e) { setState(() { _result = '设置VID+Auth失败: $e'; }); }
  }

  Future<void> _setVidMps() async {
    if (_player == null) return;
    try {
      final mpsInfo = <String, dynamic>{'vid': _vidCtrl.text.trim()};
      if (_mpsCtrl.text.trim().isNotEmpty) {
        mpsInfo['mpsConfig'] = _mpsCtrl.text.trim();
      }
      await _player!.setVidMps(mpsInfo);
      setState(() { _result = 'VID+MPS源已设置'; });
    } catch (e) { setState(() { _result = '设置VID+MPS失败: $e'; }); }
  }

  Future<void> _prepare() async {
    if (_player == null) return;
    try {
      await _player!.prepare();
      setState(() { _result = '准备就绪'; });
    } catch (e) { setState(() { _result = '准备失败: $e'; }); }
  }

  @override
  void dispose() {
    _player?.release();
    _urlCtrl.dispose(); _vidCtrl.dispose();
    _akIdCtrl.dispose(); _akSecretCtrl.dispose(); _tokenCtrl.dispose();
    _authCtrl.dispose(); _mpsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F02-003 通过VID+Auth方式设置授权播放源')),
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
                          Text('前置条件: 应用已启动，已创建播放器实例'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 在【VID】输入框中输入有效视频ID，在【PlayAuth】输入框中输入有效的PlayAuth授权凭证，点击【设置VID+Auth源】按钮 (API: setVidAuth)'),
                          const SizedBox(height: 4),
                          Text('预期结果: 播放器使用PlayAuth授权成功获取视频流，播放正常'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // URL source
                  TextField(
                    key: const Key('input_video_url'),
                    controller: _urlCtrl,
                    decoration: const InputDecoration(labelText: '视频URL', isDense: true),
                  ),
                  ElevatedButton(
                    key: const Key('btn_set_url'),
                    onPressed: _setUrl,
                    child: const Text('设置URL源'),
                  ),
                  const SizedBox(height: 8),
                  // VID + STS
                  TextField(
                    controller: _vidCtrl,
                    decoration: const InputDecoration(labelText: 'VID', isDense: true),
                  ),
                  TextField(
                    controller: _akIdCtrl,
                    decoration: const InputDecoration(labelText: 'AccessKeyId', isDense: true),
                  ),
                  TextField(
                    controller: _akSecretCtrl,
                    decoration: const InputDecoration(labelText: 'AccessKeySecret', isDense: true),
                  ),
                  TextField(
                    controller: _tokenCtrl,
                    decoration: const InputDecoration(labelText: 'SecurityToken', isDense: true),
                  ),
                  ElevatedButton(
                    key: const Key('btn_set_vid_sts'),
                    onPressed: _setVidSts,
                    child: const Text('设置VID+STS源'),
                  ),
                  const SizedBox(height: 8),
                  // VID + Auth
                  TextField(
                    controller: _authCtrl,
                    decoration: const InputDecoration(labelText: 'PlayAuth', isDense: true),
                  ),
                  ElevatedButton(
                    key: const Key('btn_set_vid_auth'),
                    onPressed: _setVidAuth,
                    child: const Text('设置VID+Auth源'),
                  ),
                  const SizedBox(height: 8),
                  // VID + MPS
                  TextField(
                    controller: _mpsCtrl,
                    decoration: const InputDecoration(labelText: 'MPS配置', hintText: 'JSON格式', isDense: true),
                  ),
                  ElevatedButton(
                    key: const Key('btn_set_vid_mps'),
                    onPressed: _setVidMps,
                    child: const Text('设置VID+MPS源'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_prepare'),
                    onPressed: _prepare,
                    child: const Text('准备'),
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
