import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterAliplayer? _player;
  int? _viewId;
  bool _isPrepared = false;
  bool _isPlaying = false;
  int _duration = 0;
  int _currentPosition = 0;
  String _statusText = 'idle';
  String _errorMsg = '';

  // 测试视频 URL (HLS)
  final String _testUrl =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnPrepared((String playerId) {
      setState(() {
        _isPrepared = true;
        _statusText = 'prepared';
      });
      _player!.getDuration().then((d) {
        setState(() {
          _duration = (d as num?)?.toInt() ?? 0;
        });
      });
    });
    _player!.setOnError((int errorCode, String? errorExtra, String? errorMsg, String playerId) {
      setState(() {
        _statusText = 'error';
        _errorMsg = '[$errorCode] ${errorMsg ?? ''}';
      });
    });
    _player!.setOnCompletion((String playerId) {
      setState(() {
        _isPlaying = false;
        _statusText = 'completed';
      });
    });
    _player!.setOnLoadingStatusListener(
      loadingBegin: (String playerId) {
        setState(() {
          _statusText = 'loading...';
        });
      },
      loadingProgress: (int percent, double? netSpeed, String playerId) {
        setState(() {
          _statusText = 'buffering $percent%';
        });
      },
      loadingEnd: (String playerId) {
        setState(() {
          _statusText = _isPlaying ? 'playing' : 'prepared';
        });
      },
    );
    _player!.setOnInfo((int? infoCode, int? extraValue, String? extraMsg, String playerId) {
      // CURRENTPOSITION (infoCode=2) 更新进度
      if (infoCode == 2 && extraValue != null) {
        setState(() {
          _currentPosition = (extraValue as num).toInt();
        });
      }
    });
    _player!.setOnRenderingStart((String playerId) {
      setState(() {
        _statusText = 'rendering';
      });
    });
  }

  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    _player!.setPlayerView(viewId);
    // 设置 URL 并 prepare
    _player!.setUrl(_testUrl);
    _player!.prepare();
  }

  Future<void> _play() async {
    await _player!.play();
    setState(() {
      _isPlaying = true;
      _statusText = 'playing';
    });
  }

  Future<void> _pause() async {
    await _player!.pause();
    setState(() {
      _isPlaying = false;
      _statusText = 'paused';
    });
  }

  Future<void> _stop() async {
    await _player!.stop();
    setState(() {
      _isPlaying = false;
      _statusText = 'stopped';
      _currentPosition = 0;
    });
  }

  Future<void> _seekTo(double value) async {
    final pos = value.toInt();
    await _player!.seekTo(pos, SeekMode.ACCURATE);
    setState(() {
      _currentPosition = pos;
    });
  }

  @override
  void dispose() {
    _player?.release();
    super.dispose();
  }

  String _formatTime(int ms) {
    final s = (ms / 1000).floor();
    final m = (s / 60).floor();
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('flutter_aliplayer OHOS Demo'),
        ),
        body: Column(
          children: [
            // 视频渲染面
            Container(
              color: Colors.black,
              width: double.infinity,
              height: 220,
              child: AliPlayerView(
                onCreated: _onPlatformViewCreated,
                x: 0,
                y: 0,
                width: double.infinity,
                height: 220,
              ),
            ),
            // 状态栏
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text('Status: $_statusText',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_formatTime(_currentPosition)} / ${_formatTime(_duration)}'),
                ],
              ),
            ),
            if (_errorMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(_errorMsg,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Slider(
                value: _duration > 0
                    ? _currentPosition.toDouble().clamp(0, _duration.toDouble())
                    : 0,
                max: _duration > 0 ? _duration.toDouble() : 1,
                onChanged: _isPrepared ? _seekTo : null,
              ),
            ),
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isPrepared ? _play : null,
                  child: const Text('Play'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isPlaying ? _pause : null,
                  child: const Text('Pause'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isPrepared ? _stop : null,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 适配说明
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'OHOS 适配说明:\n'
                  '• 播放内核: HarmonyOS AVPlayer (@ohos.multimedia.media)\n'
                  '• 渲染面: XComponent (SURFACE)\n'
                  '• 已支持: URL播放/prepare/play/pause/stop/seek/音量/倍速/静音/循环/缩放/基础事件\n'
                  '• 不支持: VidSts/VidAuth(需应用层解析URL)/ARTC/DRM/FairPlay/HttpDNS/悬浮窗/下载/预加载\n'
                  '• 测试源: Apple HLS bipbop',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
