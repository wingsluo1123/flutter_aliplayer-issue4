
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F02-001：能设置 HTTP URL 播放源并正常起播
class TestCaseF02001Page extends StatefulWidget {
  const TestCaseF02001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF02001Page> createState() => _TestCaseF02001PageState();
}

class _TestCaseF02001PageState extends State<TestCaseF02001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  String _statusText = '未创建';
  static const String _defaultUrl =
      'http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _defaultUrl);
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((playerId) {
      setState(() {
        _statusText = '已准备';
        _result = 'onPrepared 回调触发，HTTP 播放源已准备完成，可正常起播';
      });
      _player!.play();
    });
    _player!.setOnRenderingStart((playerId) {
      setState(() {
        _statusText = '播放中';
        _result = '首帧渲染完成，HTTP 源已起播';
      });
    });
    _player!.setOnError((code, extra, msg, playerId) {
      setState(() {
        _statusText = '错误';
        _result = 'onError: [$code] $msg (playerId=$playerId)';
      });
    });
    _player!.setOnLoadingStatusListener(
      loadingBegin: (playerId) {
        setState(() {
          _statusText = '缓冲中';
          _result = 'loadingBegin: 缓冲开始';
        });
      },
      loadingProgress: (percent, netSpeed, playerId) {
        setState(() {
          _statusText = '缓冲中';
          _result = 'loadingProgress: $percent%  网速: $netSpeed';
        });
      },
      loadingEnd: (playerId) {
        setState(() {
          _statusText = '缓冲完成';
          _result = 'loadingEnd: 缓冲结束';
        });
      },
    );
  }

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
  }

  Future<void> _setUrl() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = 'URL 不能为空';
      });
      return;
    }
    try {
      setState(() {
        _statusText = '准备中';
        _result = '正在设置 HTTP 播放源: $url\n调用 setUrl + prepare';
      });
      await _player!.setUrl(url);
      await _player!.prepare();
      setState(() {
        _result = '已调用 setUrl + prepare\nURL: $url\n等待 onPrepared 回调...';
      });
    } catch (e) {
      setState(() {
        _statusText = '错误';
        _result = '设置播放源失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _player?.release();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F02-001 能设置 HTTP URL 播放源并正常起播')),
      body: Column(
        children: <Widget>[
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
                          Text('前置条件: 应用已启动；播放器实例已创建；网络可用；有可用的 HTTP 视频源'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【URL 输入框】中输入 HTTP 视频地址 (API: setUrl, url: http://example.com/video.mp4) [验证点: 验证输入框显示完整 HTTP 地址]; 2. 点击【设置播放源】按钮 (API: setUrl) [验证点: 验证【播放状态】文本显示"准备中"]; 3. 等待 3 秒 [验证点: 验证【播放状态】文本显示"已准备"且 onPrepared 事件触发]'),
                          const SizedBox(height: 4),
                          Text('预期结果: HTTP URL 播放源设置后播放器进入 prepared 状态，可正常起播'),
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
                  Container(
                    key: const Key('player_container'),
                    height: 200,
                    color: Colors.black,
                    child: _player != null
                        ? AliPlayerView(
                            onCreated: _onViewCreated,
                            x: 0,
                            y: 0,
                            width: double.infinity,
                            height: 200,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('input_url'),
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'HTTP URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('播放状态: $_statusText'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_set_url'),
                    onPressed: _setUrl,
                    child: const Text('设置播放源'),
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
