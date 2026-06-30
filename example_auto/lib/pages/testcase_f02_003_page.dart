
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F02-003：能切换播放流地址并平滑切换到新流
class TestCaseF02003Page extends StatefulWidget {
  const TestCaseF02003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF02003Page> createState() => _TestCaseF02003PageState();
}

class _TestCaseF02003PageState extends State<TestCaseF02003Page> {
  String _result = '';
  FlutterAliplayer? _player;
  String _statusText = '未创建';
  bool _isSwitching = false;

  static const String _initialUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';
  static const String _newStreamUrl =
      'http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _newStreamUrl);
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((playerId) {
      setState(() {
        if (_isSwitching) {
          _statusText = '播放中(新流)';
          _result = '切换流完成，新流已准备并起播';
          _isSwitching = false;
        } else {
          _statusText = '已准备';
          _result = 'onPrepared 回调触发，播放源已准备完成';
        }
      });
      _player!.play();
    });
    _player!.setOnRenderingStart((playerId) {
      setState(() {
        _statusText = _isSwitching ? '播放中(新流)' : '播放中';
        _result = '首帧渲染完成，画面已切换为新流内容';
      });
    });
    _player!.setOnError((code, extra, msg, playerId) {
      setState(() {
        _statusText = '错误';
        _result = 'onError: [$code] $msg (playerId=$playerId)';
        _isSwitching = false;
      });
    });
    _player!.setOnLoadingStatusListener(
      loadingBegin: (playerId) {
        setState(() {
          _statusText = '缓冲中';
          _result = _isSwitching ? '切换中：缓冲开始' : 'loadingBegin: 缓冲开始';
        });
      },
      loadingProgress: (percent, netSpeed, playerId) {
        setState(() {
          _statusText = '缓冲中';
          _result = '缓冲进度: $percent%  网速: $netSpeed';
        });
      },
      loadingEnd: (playerId) {
        setState(() {
          _statusText = '缓冲完成';
          _result = '缓冲结束';
        });
      },
    );
  }

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
  }

  Future<void> _setUrl() async {
    try {
      setState(() {
        _statusText = '准备中';
        _result = '正在设置初始播放源: $_initialUrl\n调用 setUrl + prepare';
      });
      await _player!.setUrl(_initialUrl);
      await _player!.prepare();
      setState(() {
        _result = '已设置初始源并调用 prepare\n初始源: $_initialUrl\n等待 onPrepared 回调后即播放';
      });
    } catch (e) {
      setState(() {
        _statusText = '错误';
        _result = '设置播放源失败: $e';
      });
    }
  }

  Future<void> _switchStream() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = '请在输入框中输入要切换的新流地址';
      });
      return;
    }
    try {
      _isSwitching = true;
      setState(() {
        _statusText = '切换中';
        _result = '正在切换流地址: $url\n调用 switchStream';
      });
      await _player!.switchStream(url);
      setState(() {
        _result = '已调用 switchStream\n新流地址: $url\n等待切换完成...';
      });
    } catch (e) {
      setState(() {
        _statusText = '错误';
        _result = '切换流失败: $e';
        _isSwitching = false;
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
      appBar: AppBar(title: const Text('F02-003 能切换播放流地址并平滑切换到新流')),
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
                          Text('前置条件: 应用已启动；播放器正在播放某一流；有备用流地址'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【URL 输入框】中输入新流地址 (API: switchStream, url: 新流地址) [验证点: 验证输入框显示新流地址]; 2. 点击【切换流】按钮 (API: switchStream) [验证点: 验证【播放状态】文本短暂显示"切换中"后恢复"播放中"]; 3. 观察【播放器容器】区域 [验证点: 验证画面切换为新流内容且无崩溃]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 切换流地址后播放器平滑切换到新流，画面内容更新为新流且无中断崩溃'),
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
                      labelText: '新流地址',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('播放状态: $_statusText'),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('btn_set_url'),
                          onPressed: _setUrl,
                          child: const Text('设置播放源'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('btn_switch_stream'),
                          onPressed: _switchStream,
                          child: const Text('切换流'),
                        ),
                      ),
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
