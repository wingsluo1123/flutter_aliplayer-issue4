
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F04-003：能切换渲染面类型并正常显示画面
class TestCaseF04003Page extends StatefulWidget {
  const TestCaseF04003Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF04003Page> createState() => _TestCaseF04003PageState();
}

class _TestCaseF04003PageState extends State<TestCaseF04003Page> {
  String _result = '';
  FlutterAliplayer? _player;
  String _statusText = '未创建';
  AliPlayerViewTypeForAndroid _viewType =
      AliPlayerViewTypeForAndroid.surfaceview;

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  static const Map<AliPlayerViewTypeForAndroid, String> _viewTypeLabels =
      <AliPlayerViewTypeForAndroid, String>{
    AliPlayerViewTypeForAndroid.surfaceview: 'SurfaceView',
    AliPlayerViewTypeForAndroid.textureview: 'TextureView',
    AliPlayerViewTypeForAndroid.displayview: 'DisplayView',
  };

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((playerId) {
      setState(() {
        _statusText = '已准备';
        _result = 'onPrepared 回调触发，播放器已准备';
      });
      _player!.play();
    });
    _player!.setOnRenderingStart((playerId) {
      setState(() {
        _statusText = '画面可见';
        _result = '首帧渲染完成，${_viewTypeLabels[_viewType]} 类型下画面正常显示';
      });
    });
    _player!.setOnError((code, extra, msg, playerId) {
      setState(() {
        _statusText = '错误';
        _result = 'onError: [$code] $msg (playerId=$playerId)';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player?.setPlayerView(viewId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _result = '渲染面已创建，viewId=$viewId\n当前 viewType: ${_viewTypeLabels[_viewType]}';
      });
    });
  }

  Future<void> _play() async {
    try {
      setState(() {
        _statusText = '准备中';
        _result = '正在设置播放源并准备...\n当前 viewType: ${_viewTypeLabels[_viewType]}';
      });
      await _player!.setUrl(_testUrl);
      await _player!.prepare();
      setState(() {
        _result = '已调用 setUrl + prepare\n当前 viewType: ${_viewTypeLabels[_viewType]}\n等待 onPrepared 后自动播放';
      });
    } catch (e) {
      setState(() {
        _statusText = '错误';
        _result = '播放失败: $e';
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
      appBar: AppBar(title: const Text('F04-003 能切换渲染面类型并正常显示画面')),
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
                          Text('前置条件: 应用已启动；播放器正在播放视频'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 在【渲染面类型】下拉菜单中选择"SurfaceView" (API: aliPlayerViewType, type: surfaceview) [验证点: 验证下拉菜单显示"SurfaceView"]; 2. 观察【播放器容器】区域 [验证点: 验证画面在 SurfaceView 类型下正常显示]; 3. 在【渲染面类型】下拉菜单中依次选择"TextureView"与"DisplayView" (API: aliPlayerViewType) [验证点: 验证三种类型切换后画面均能正常显示]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 三种 viewType 切换后画面均能正常显示，无黑屏或崩溃'),
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
                            key: ValueKey<String>(
                                'player_view_${_viewType.name}'),
                            onCreated: _onViewCreated,
                            x: 0,
                            y: 0,
                            width: double.infinity,
                            height: 200,
                            aliPlayerViewType: _viewType,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Text('渲染面类型: '),
                      Expanded(
                        child: DropdownButton<AliPlayerViewTypeForAndroid>(
                          key: const Key('dropdown_view_type'),
                          value: _viewType,
                          isExpanded: true,
                          items: AliPlayerViewTypeForAndroid.values
                              .map((AliPlayerViewTypeForAndroid v) =>
                                  DropdownMenuItem<AliPlayerViewTypeForAndroid>(
                                    value: v,
                                    child: Text(_viewTypeLabels[v]!),
                                  ))
                              .toList(),
                          onChanged: (AliPlayerViewTypeForAndroid? v) {
                            if (v == null) return;
                            setState(() {
                              _viewType = v;
                              _statusText = '已切换';
                              _result =
                                  '已切换渲染面类型为 ${_viewTypeLabels[v]}\n点击【播放】验证画面显示';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('当前 viewType: ${_viewTypeLabels[_viewType]}\n状态: $_statusText'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('btn_play'),
                    onPressed: _play,
                    child: const Text('播放'),
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
