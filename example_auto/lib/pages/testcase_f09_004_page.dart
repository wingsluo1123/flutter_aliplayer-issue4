import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';


/// 测试用例详情 - F09-004：多个渲染视图分别播放不同视频
class TestCaseF09004Page extends StatefulWidget {
  const TestCaseF09004Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF09004Page> createState() => _TestCaseF09004PageState();
}

class _TestCaseF09004PageState extends State<TestCaseF09004Page> {
  FlutterAliplayer? _player;
  String _result = '';
  int? _viewId;
  final TextEditingController _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _createPlayerWithView();
  }

  Future<void> _createPlayerWithView() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      await _player!.create();
      setState(() { _result = '播放器已创建'; });
    } catch (e) { setState(() { _result = '创建失败: $e'; }); }
  }

  Future<void> _setUrl() async {
    try {
      final url = _urlCtrl.text.trim();
      if (url.isEmpty) return;
      await _player!.setUrl(url);
      setState(() { _result = 'URL已设置'; });
    } catch (e) { setState(() { _result = '失败: $e'; }); }
  }

  Future<void> _prepare() async { try { await _player!.prepare(); setState(() { _result = '准备完成'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }
  Future<void> _play() async { try { await _player!.play(); setState(() { _result = '播放中'; }); } catch (e) { setState(() { _result = '失败: $e'; }); } }

  @override
  void dispose() {
    _player?.release();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F09-004 多个渲染视图分别播放不同视频')),
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
                          Text('前置条件: 应用已启动，已创建两个播放器和两个渲染视图'),
                          Text('预期结果: 每个渲染视图独立显示各自视频画面，互不干扰'),
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  // PlatformView area
                  const Text('渲染视图 (AliPlayerView)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      color: Colors.black,
                    ),
                    child: _player != null
                        ? AliPlayerView(
                            key: const Key('aliplayer_view'),
                            onCreated: (viewId) {
                              _viewId = viewId;
                              _player!.setPlayerView(viewId);
                              setState(() { _result = '渲染视图已创建, viewId: $viewId'; });
                            },
                            x: 0,
                            y: 0,
                            width: MediaQuery.of(context).size.width.toInt(),
                            height: 200,
                          )
                        : const Center(child: Text('请先创建播放器', style: TextStyle(color: Colors.white))),
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
