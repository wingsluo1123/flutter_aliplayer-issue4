import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F14-001：通过直播URL播放直播流
class TestCaseF14001Page extends StatefulWidget {
  const TestCaseF14001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF14001Page> createState() => _TestCaseF14001PageState();
}

class _TestCaseF14001PageState extends State<TestCaseF14001Page> {
  FlutterAliplayer? _player; String _result = '';
  final TextEditingController _liveUrlCtrl = TextEditingController();
  final TextEditingController _akIdCtrl = TextEditingController();
  final TextEditingController _akSecretCtrl = TextEditingController();
  final TextEditingController _tokenCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _createPlayer(); }

  Future<void> _createPlayer() async {
    try { _player = FlutterAliPlayerFactory.createAliPlayer(); await _player!.create(); setState(() { _result = '播放器已创建'; }); } catch (e) { }
  }

  Future<void> _setLiveUrl() async {
    try {
      await _player!.setUrl(_liveUrlCtrl.text.trim());
      await _player!.prepare();
      await _player!.play();
      setState(() { _result = '直播流播放中'; });
    } catch (e) { setState(() { _result = '直播播放失败: $e'; }); }
  }

  Future<void> _setLiveSts() async {
    try {
      await _player!.setLiveSts(
        url: _liveUrlCtrl.text.trim(),
        accessKeyId: _akIdCtrl.text.trim(),
        accessKeySecret: _akSecretCtrl.text.trim(),
        securityToken: _tokenCtrl.text.trim(),
      );
      await _player!.prepare();
      await _player!.play();
      setState(() { _result = '直播STS播放中'; });
    } catch (e) { setState(() { _result = '直播STS失败: $e'; }); }
  }

  @override
  void dispose() { _player?.release(); _liveUrlCtrl.dispose(); _akIdCtrl.dispose(); _akSecretCtrl.dispose(); _tokenCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F14-001 通过直播URL播放直播流')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，已创建播放器实例'), Text('预期结果: 直播流加载成功，视频画面开始渲染'),
        ]))),
        TextField(controller: _liveUrlCtrl, decoration: const InputDecoration(labelText: '直播URL', isDense: true)),
        ElevatedButton(key: const Key('btn_set_live_url'), onPressed: _setLiveUrl, child: const Text('设置直播源')),
        const SizedBox(height: 8),
        TextField(controller: _akIdCtrl, decoration: const InputDecoration(labelText: 'AccessKeyId', isDense: true)),
        TextField(controller: _akSecretCtrl, decoration: const InputDecoration(labelText: 'AccessKeySecret', isDense: true)),
        TextField(controller: _tokenCtrl, decoration: const InputDecoration(labelText: 'SecurityToken', isDense: true)),
        ElevatedButton(key: const Key('btn_set_live_sts'), onPressed: _setLiveSts, child: const Text('设置直播STS源')),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
