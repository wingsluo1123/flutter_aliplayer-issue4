
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

/// 测试用例详情（三级页）- F06-001：能查询媒体轨道信息并返回轨道列表
class TestCaseF06001Page extends StatefulWidget {
  const TestCaseF06001Page({Key? key}) : super(key: key);

  @override
  State<TestCaseF06001Page> createState() => _TestCaseF06001PageState();
}

class _TestCaseF06001PageState extends State<TestCaseF06001Page> {
  String _result = '';
  FlutterAliplayer? _player;
  bool _isPrepared = false;

  static const String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _isPrepared = true;
        _result = '播放器已准备 (onPrepared 触发)\n可点击【查询轨道】查看媒体轨道信息';
      });
    });
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _result = '错误: [$errorCode] ${errorMsg ?? ''}';
      });
    });
    _player!.setOnTrackReady((String playerId) {
      setState(() {
        _result = '轨道就绪 (OnTrackReady 触发)\n可点击【查询轨道】查看轨道列表';
      });
    });
  }

  void _onViewCreated(int viewId) {
    _player!.setPlayerView(viewId);
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  String _trackTypeName(dynamic trackType) {
    final int? t = trackType is int ? trackType : int.tryParse('$trackType');
    switch (t) {
      case 0:
        return 'video';
      case 1:
        return 'audio';
      case 2:
        return 'subtitle';
      default:
        return 'unknown($trackType)';
    }
  }

  Future<void> _queryTracks() async {
    try {
      final dynamic info = await _player!.getMediaInfo();
      final StringBuffer sb = StringBuffer();
      sb.writeln('getMediaInfo 返回:');
      if (info is Map) {
        final dynamic tracks = info['tracks'];
        if (tracks is List) {
          sb.writeln('轨道数量: ${tracks.length}');
          for (int i = 0; i < tracks.length; i++) {
            final dynamic t = tracks[i];
            if (t is Map) {
              final dynamic trackType = t['trackType'];
              final dynamic trackIndex = t['trackIndex'];
              final dynamic bitrate = t['trackBitrate'];
              final dynamic lang = t['audioLanguage'] ??
                  t['subtitleLanguage'] ??
                  t['language'];
              final dynamic definition = t['trackDefinition'];
              sb.writeln('  [$i] type=${_trackTypeName(trackType)}'
                  ' index=$trackIndex'
                  '${bitrate != null ? ' bitrate=$bitrate' : ''}'
                  '${lang != null ? ' lang=$lang' : ''}'
                  '${definition != null ? ' def=$definition' : ''}');
            } else {
              sb.writeln('  [$i] $t');
            }
          }
        } else {
          sb.writeln('tracks: $tracks');
        }
      } else {
        sb.writeln('$info');
      }
      setState(() {
        _result = sb.toString();
      });
    } catch (e) {
      setState(() {
        _result = '查询轨道失败: $e';
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
      appBar: AppBar(title: const Text('F06-001 能查询媒体轨道信息并返回轨道列表')),
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
                          Text('前置条件: 应用已启动；播放器已进入 prepared 状态；视频包含多轨道'),
                          const SizedBox(height: 4),
                          Text('测试步骤: 1. 点击【查询轨道】按钮 (API: getMediaInfo) [验证点: 验证【轨道列表】区域显示轨道条目]; 2. 观察【轨道列表】中的条目 [验证点: 验证列表包含 video/audio/subtitle 类型的轨道]'),
                          const SizedBox(height: 4),
                          Text('预期结果: 查询返回轨道列表，包含 video/audio/subtitle 类型'),
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
                  ElevatedButton(
                    key: const Key('btn_query_tracks'),
                    onPressed: _isPrepared ? _queryTracks : null,
                    child: const Text('查询轨道'),
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
