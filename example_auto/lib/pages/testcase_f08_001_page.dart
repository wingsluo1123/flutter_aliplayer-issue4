
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F08-001：能截取当前播放帧并生成图片文件
class TestCaseF08001Page extends StatefulWidget {
  const TestCaseF08001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF08001Page> createState() => _TestCaseF08001PageState();
}

class _TestCaseF08001PageState extends State<TestCaseF08001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;
  bool _isPlaying = false;

  final TextEditingController _snapshotPathCtrl =
      TextEditingController(text: 'snapshot.png');

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _isPrepared = true;
        _result = '播放器已准备 (onPrepared 触发)\n点击【播放】开始播放后再截图';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = '错误: [$errorCode] ${errorMsg ?? ''}';
      });
    });
    _player!.setOnRenderingStart((String playerId) {
      setState(() {
        _isPlaying = true;
        _result = '首帧渲染开始 (onRenderingStart)\n可点击【截图】截取当前帧';
      });
    });
    _player!.setOnSnapShot((String path, String playerId) {
      setState(() {
        _result = '截图完成 (OnSnapShot 触发)\npath: $path\nplayerId: $playerId';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _play() async {
    try {
      await _player!.play();
      setState(() {
        _result = '播放已触发 (play)\n等待首帧渲染后可截图';
      });
    } catch (e) {
      setState(() {
        _result = '播放失败: $e';
      });
    }
  }

  Future<void> _snapshot() async {
    final String path = _snapshotPathCtrl.text.trim();
    if (path.isEmpty) {
      setState(() {
        _result = '截图路径不能为空';
      });
      return;
    }
    try {
      setState(() {
        _result = '截图中... (snapshot path=$path)';
      });
      await _player!.snapshot(path);
      setState(() {
        _result = 'snapshot 已调用\npath: $path\n等待 OnSnapShot 回调\n'
            '(注: 鸿蒙侧截图为 P2 安全空实现, 回调可能不触发)';
      });
    } catch (e) {
      setState(() {
        _result = '截图失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _snapshotPathCtrl.dispose();
    _player?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F08-001 能截取当前播放帧并生成图片文件')),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.black,
            width: double.infinity,
            height: 200,
            child: AliPlayerView(
              onCreated: _onViewCreated,
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
                          Text('前置条件: 应用已启动；播放器正在播放视频；有可写的保存路径'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【截图路径输入框】中输入保存路径 (API: snapshot, path: 保存路径) [验证点: 验证输入框显示保存路径]; 2. 点击【截图】按钮 (API: snapshot) [验证点: 验证【截图状态】文本显示"截图中"]; 3. 等待 2 秒 [验证点: 验证 OnSnapShot 回调触发且【截图状态】显示"已完成"]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 截图后 OnSnapShot 回调触发，图片文件生成成功'),
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
                    key: const Key('input_snapshot_path'),
                    controller: _snapshotPathCtrl,
                    decoration: const InputDecoration(
                      labelText: '截图路径',
                      hintText: 'snapshot.png',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('btn_play'),
                    onPressed: _isPrepared && !_isPlaying ? _play : null,
                    child: const Text('播放'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_snapshot'),
                    onPressed: _isPlaying ? _snapshot : null,
                    child: const Text('截图'),
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
