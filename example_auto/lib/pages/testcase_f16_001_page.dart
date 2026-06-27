import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer/flutter_alilistplayer.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F16-001：向播放列表添加URL视频资源
class TestCaseF16001Page extends StatefulWidget {
  const TestCaseF16001Page({Key? key}) : super(key: key);
  @override
  State<TestCaseF16001Page> createState() => _TestCaseF16001PageState();
}

class _TestCaseF16001PageState extends State<TestCaseF16001Page> {
  FlutterAliListPlayer? _player; String _result = '';
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _uidCtrl = TextEditingController();
  final TextEditingController _vidCtrl = TextEditingController();
  int _sourceCount = 0;

  @override
  void initState() { super.initState(); _createPlayer(); }

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliListPlayer();
      await _player!.create();
      setState(() { _result = '列表播放器已创建'; });
    } catch (e) { }
  }

  Future<void> _addUrlSource() async {
    try {
      await _player!.addUrlSource(url: _urlCtrl.text.trim(), uid: _uidCtrl.text.trim());
      _sourceCount++;
      setState(() { _result = 'URL资源已添加, 共$_sourceCount个'; });
    } catch (e) { setState(() { _result = '添加失败: $e'; }); }
  }

  Future<void> _addVidSource() async {
    try {
      await _player!.addVidSource(vid: _vidCtrl.text.trim(), uid: _uidCtrl.text.trim());
      _sourceCount++;
      setState(() { _result = 'VID资源已添加, 共$_sourceCount个'; });
    } catch (e) { setState(() { _result = '添加失败: $e'; }); }
  }

  Future<void> _moveToNext() async {
    try { await _player!.moveToNext(); setState(() { _result = '已切换到下一个'; }); } catch (e) { }
  }

  Future<void> _moveToPre() async {
    try { await _player!.moveToPre(); setState(() { _result = '已切换到上一个'; }); } catch (e) { }
  }

  @override
  void dispose() { _player?.release(); _urlCtrl.dispose(); _uidCtrl.dispose(); _vidCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('F16-001 向播放列表添加URL视频资源')),
    body: Column(children: [
      Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('前置条件: 应用已启动，已创建列表播放器实例'), Text('预期结果: 视频资源成功添加到播放列表中'),
        ]))),
        TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: '视频URL', isDense: true)),
        TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: '资源标识', isDense: true)),
        ElevatedButton(key: const Key('btn_add_url'), onPressed: _addUrlSource, child: const Text('添加URL资源')),
        const SizedBox(height: 8),
        TextField(controller: _vidCtrl, decoration: const InputDecoration(labelText: 'VID', isDense: true)),
        ElevatedButton(key: const Key('btn_add_vid'), onPressed: _addVidSource, child: const Text('添加VID资源')),
        const SizedBox(height: 8),
        Wrap(children: [
          ElevatedButton(key: const Key('btn_prev'), onPressed: _moveToPre, child: const Text('上一个')),
          ElevatedButton(key: const Key('btn_next'), onPressed: _moveToNext, child: const Text('下一个')),
        ]),
      ]))),
      Expanded(flex: 2, child: ResultPanel(result: _result)),
    ]),
  );
}
