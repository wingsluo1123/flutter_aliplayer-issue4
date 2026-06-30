
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F01-001：能创建单个播放器实例并完成初始化
class TestCaseF01001Page extends StatefulWidget {
  const TestCaseF01001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF01001Page> createState() => _TestCaseF01001PageState();
}

class _TestCaseF01001PageState extends State<TestCaseF01001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  String _statusText = '未创建';

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _result = '渲染面已挂载，viewId=$viewId\n$_result';
      });
    });
  }

  Future<void> _createPlayer() async {
    try {
      _player = FlutterAliPlayerFactory.createAliPlayer();
      _player!.setOnPrepared((playerId) {
        setState(() {
          _statusText = '已准备';
          _result = 'onPrepared 回调触发，playerId=$playerId，播放器已准备';
        });
      });
      _player!.setOnError((code, extra, msg, playerId) {
        setState(() {
          _statusText = '错误';
          _result = 'onError: [$code] $msg (playerId=$playerId)';
        });
      });
      _player!.setOnCompletion((playerId) {
        setState(() {
          _statusText = '播放完成';
          _result = 'onCompletion 回调触发，playerId=$playerId';
        });
      });
      _player!.setOnRenderingStart((playerId) {
        setState(() {
          _statusText = '首帧渲染';
          _result = 'onRenderingStart 回调触发，首帧已渲染';
        });
      });
      setState(() {
        _statusText = '已创建';
        _result = '播放器实例创建成功\nplayerId=${_player!.playerId}\n渲染面已挂载到容器区域';
      });
    } catch (e) {
      setState(() {
        _statusText = '创建失败';
        _result = '创建播放器失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F01-001 能创建单个播放器实例并完成初始化')),
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
                          Text('前置条件: 应用已启动；播放器演示页面已打开；网络可用'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【创建播放器】按钮 (API: createAliPlayer) [验证点: 验证【实例状态】文本显示"已创建"]; 2. 观察【播放器容器】区域 [验证点: 验证渲染面已挂载且无异常提示]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 播放器实例创建成功，状态显示为已创建，渲染面挂载到容器区域'),
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
                        : const Center(
                            child: Text(
                              '请先创建播放器',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text('实例状态: $_statusText'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_create_player'),
                    onPressed: _createPlayer,
                    child: const Text('创建播放器'),
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
