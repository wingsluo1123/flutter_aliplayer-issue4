
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_alilistplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F12-001：能添加 URL 播放源到列表并成功加入
class TestCaseF12001Page extends StatefulWidget {
  const TestCaseF12001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF12001Page> createState() => _TestCaseF12001PageState();
}

class _TestCaseF12001PageState extends State<TestCaseF12001Page> {
  String _result = '';
  final TextEditingController _urlController = TextEditingController(
    text:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  );
  late final FlutterAliListPlayer _listPlayer;
  final List<Map<String, String>> _sourceList = <Map<String, String>>[];
  int _uidSeq = 0;

  @override
  void initState() {
    super.initState();
    _listPlayer = FlutterAliPlayerFactory.createAliListPlayer(playerId: 'f12_001');
  }

  @override
  void dispose() {
    _listPlayer.release();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addToList() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = '请输入 URL';
      });
      return;
    }
    _uidSeq += 1;
    final String uid = 'uid_$_uidSeq';
    try {
      await _listPlayer.addUrlSource(url: url, uid: uid);
      _sourceList.add(<String, String>{'uid': uid, 'url': url});
      final dynamic currentUid = await _listPlayer.getCurrentUid();
      final StringBuffer sb = StringBuffer();
      sb.writeln('addUrlSource 调用成功');
      sb.writeln('本次添加 uid: $uid');
      sb.writeln('当前列表项数: ${_sourceList.length}');
      sb.writeln('getCurrentUid: ${currentUid?.toString() ?? 'null'}');
      sb.writeln('---- 播放列表 ----');
      for (int i = 0; i < _sourceList.length; i++) {
        sb.writeln('${i + 1}. ${_sourceList[i]['uid']} -> ${_sourceList[i]['url']}');
      }
      setState(() {
        _result = sb.toString();
      });
    } catch (e) {
      setState(() {
        _result = 'error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F12-001 能添加 URL 播放源到列表并成功加入')),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 200,
            width: double.infinity,
            child: AliPlayerView(
              onCreated: (int viewId) {
                _listPlayer.setPlayerView(viewId);
              },
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
                          Text('前置条件: 应用已启动；列表播放器演示页面已打开；有多个可用的 URL 播放源'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【URL 输入框】中输入第一个 URL 后点击【添加到列表】按钮 (API: addUrlSource, url: URL1) [验证点: 验证【播放列表】中出现第一个条目]; 2. 重复操作添加第二个 URL (API: addUrlSource, url: URL2) [验证点: 验证【播放列表】中出现第二个条目且 getCurrentUid 返回新项 uid]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 添加 URL 播放源后列表项数增加，getCurrentUid 返回新项 uid'),
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
                    key: const Key('input_url'),
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL 输入框',
                      hintText: '请输入播放源 URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_add_to_list'),
                    onPressed: _addToList,
                    child: const Text('添加到列表'),
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
