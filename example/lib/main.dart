import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer/flutter_alilistplayer.dart';
import 'package:flutter_aliplayer/flutter_aliliveshiftplayer.dart';
import 'package:flutter_aliplayer/flutter_alidownloader.dart';
import 'package:flutter_aliplayer/flutter_avpdef.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _sdkVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    _initSDKVersion();
  }

  Future<void> _initSDKVersion() async {
    try {
      final result = await FlutterAliPlayerFactory.methodChannel
          .invokeMethod('getSDKVersion');
      if (!mounted) return;
      setState(() {
        _sdkVersion = result?.toString() ?? '7.14.0';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sdkVersion = '7.14.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('阿里云播放器 Demo (OHOS)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showInfoDialog(context),
            ),
          ],
        ),
        body: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: '单播放器'),
                  Tab(text: '列表播放器'),
                  Tab(text: '直播时移'),
                  Tab(text: '视频下载'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SinglePlayerTab(sdkVersion: _sdkVersion),
                    ListPlayerTab(sdkVersion: _sdkVersion),
                    LiveShiftPlayerTab(sdkVersion: _sdkVersion),
                    DownloaderTab(sdkVersion: _sdkVersion),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于'),
          content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('阿里云播放器 Flutter 插件示例'),
            SizedBox(height: 8),
            Text('基于阿里云播放器 SDK 7.14.0'),
            SizedBox(height: 8),
            Text('OHOS 平台支持状态:'),
            Text('• 单播放器: 已支持 (推荐使用)'),
            Text('• 列表播放器: 部分支持'),
            Text('• 直播时移播放器: 部分支持'),
            SizedBox(height: 8),
            Text('功能覆盖:'),
            Text('• F-01 播放器创建与管理'),
            Text('• F-02 播放控制'),
            Text('• F-03 播放源设置'),
            Text('• F-04 视频渲染'),
            Text('• F-05 音量控制'),
            Text('• F-06 媒体信息获取'),
            Text('• F-07 事件回调'),
            Text('• F-08 清晰度切换'),
            Text('• F-10 截图功能'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

abstract class _BasePlayerTab extends StatefulWidget {
  final String sdkVersion;
  const _BasePlayerTab({required this.sdkVersion});
}

abstract class _BasePlayerTabState<T extends _BasePlayerTab> extends State<T> {
  int _viewId = -1;
  bool _isPlaying = false;
  bool _isPrepared = false;
  String _eventLog = '';
  int _duration = 0;
  int _currentPosition = 0;
  int _bufferedPosition = 0;
  final ScrollController _logScrollController = ScrollController();

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    setState(() {
      _eventLog = '[$timestamp] $message\n$_eventLog';
      if (_eventLog.length > 10000) {
        _eventLog = _eventLog.substring(0, 10000);
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _onPlatformViewCreated(int viewId, FlutterAliplayer? player) {
    setState(() {
      _viewId = viewId;
    });
    _addLog('PlatformView 创建成功: $viewId');
    if (player != null) {
      player.setPlayerView(viewId).then((_) {
        _addLog('播放器视图绑定成功');
      }).catchError((e) {
        _addLog('绑定播放器视图失败: $e');
      });
    }
  }

  Widget buildVideoPlayer(FlutterAliplayer? player, {Function(double)? onSeek}) {
    return Container(
      height: 220,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AliPlayerView(
            onCreated: (id) => _onPlatformViewCreated(id, player),
            x: 0,
            y: 0,
            width: MediaQuery.of(context).size.width.toInt(),
            height: 220,
          ),
          if (!_isPrepared)
            const CircularProgressIndicator(color: Colors.white),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: _buildProgressBar(onSeek),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Function(double)? onSeek) {
    final durationSec = _duration / 1000;
    final currentSec = _currentPosition / 1000;
    final bufferedSec = _bufferedPosition / 1000;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: durationSec > 0 ? bufferedSec / durationSec : 0,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Colors.white54),
          minHeight: 2,
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
          child: Slider(
            value: durationSec > 0 ? currentSec / durationSec : 0,
            onChanged: onSeek,
            activeColor: Colors.red,
            inactiveColor: Colors.white24,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildLogTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _logScrollController,
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            _eventLog,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _eventLog = '';
              });
            },
            tooltip: '清空日志',
          ),
        ),
      ],
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }
}

class SinglePlayerTab extends _BasePlayerTab {
  const SinglePlayerTab({required super.sdkVersion});

  @override
  State<SinglePlayerTab> createState() => _SinglePlayerTabState();
}

class _SinglePlayerTabState extends _BasePlayerTabState<SinglePlayerTab> {
  FlutterAliplayer? _player;
  double _speed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _isLoop = false;
  bool _isAutoPlay = true;
  int _scalingMode = ScaleMode.SCALE_ASPECT_FIT;
  int _rotateMode = RotateMode.ROTATE_0;
  int _mirrorMode = MirrorMode.MIRROR_MODE_NONE;
  int _backgroundColor = 0xFF000000;
  String _videoInfo = '';
  List<AVPTrackInfo> _trackList = [];
  int _selectedTrackIndex = -1;
  bool _playerCreated = false;
  int _defaultBandWidth = 0;
  int _defaultResolution = PixelNumber.Resolution_NoLimit;
  String _currentSubtitle = '';
  List<int> _extSubtitleTracks = [];
  final TextEditingController _subtitleUrlController = TextEditingController();
  String? _thumbnailBitmap;
  int _thumbnailPosition = 0;
  bool _thumbnailPrepared = false;
  final TextEditingController _thumbnailUrlController = TextEditingController();

  String _testSubtitleUrl = '';

  // 播放器配置参数
  int _maxBufferDuration = 30000;
  int _highBufferDuration = 5000;
  int _startBufferDuration = 1000;
  int _networkTimeout = 15000;
  int _networkRetryCount = 2;
  String _httpProxy = '';
  final TextEditingController _proxyController = TextEditingController();

  final TextEditingController _urlController = TextEditingController(
    text: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
  );

  Future<void> _createPlayer() async {
    if (_player != null) {
      await _player!.release();
    }
    _player = FlutterAliPlayerFactory.createAliPlayer(playerId: 'demo_player');
    _setupEventListeners();
    setState(() {
      _playerCreated = true;
    });
    _addLog('单播放器创建成功');
  }

  void _applyPlayConfig() {
    if (_player == null) {
      _addLog('请先创建播放器');
      return;
    }

    AVPConfig config = AVPConfig();
    config.maxBufferDuration = _maxBufferDuration;
    config.highBufferDuration = _highBufferDuration;
    config.startBufferDuration = _startBufferDuration;
    config.networkTimeout = _networkTimeout;
    config.networkRetryCount = _networkRetryCount;
    // 始终设置 httpProxy，空字符串表示清除代理
    config.httpProxy = _httpProxy;

    _player!.setPlayConfig(config);
    if (_httpProxy.isNotEmpty) {
      _addLog('应用播放器配置: 缓冲${_maxBufferDuration}ms 超时${_networkTimeout}ms 重试${_networkRetryCount}次 代理=${_httpProxy}');
    } else {
      _addLog('应用播放器配置: 缓冲${_maxBufferDuration}ms 超时${_networkTimeout}ms 重试${_networkRetryCount}次 代理=已清除');
    }
  }

  void _setupEventListeners() {
    if (_player == null) return;

    _player!.setOnPrepared((playerId) {
      _addLog('onPrepared: 准备完成');
      setState(() {
        _isPrepared = true;
      });
      _player!.getDuration().then((d) {
        if (d != null && d is int) {
          setState(() {
            _duration = d;
          });
        }
      });
      if (_isAutoPlay) {
        _player!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    });

    _player!.setOnRenderingStart((playerId) {
      _addLog('onRenderingStart: 首帧渲染');
    });

    _player!.setOnVideoSizeChanged((width, height, rotation, playerId) {
      _addLog('onVideoSizeChanged: ${width}x$height, rotation=$rotation');
      setState(() {
        _videoInfo = '视频尺寸: ${width}x$height\n旋转: $rotation°';
      });
    });

    _player!.setOnStateChanged((newState, playerId) {
      _addLog('onStateChanged: ${_getStateString(newState)} ($newState)');
      setState(() {
        if (newState == PlayState.started) {
          _isPlaying = true;
        } else if (newState == PlayState.paused ||
            newState == PlayState.stopped) {
          _isPlaying = false;
        }
      });
    });

    _player!.setOnInfo((infoCode, extraValue, extraMsg, playerId) {
      if (infoCode == InfoCode.CURRENTPOSITION) {
        setState(() {
          _currentPosition = extraValue ?? 0;
        });
      } else if (infoCode == InfoCode.BUFFEREDPOSITION) {
        setState(() {
          _bufferedPosition = extraValue ?? 0;
        });
      } else if (infoCode == InfoCode.CURRENTDOWNLOADSPEED) {
        _addLog('下载速度: ${extraValue} bps');
      }
    });

    _player!.setOnError((errorCode, errorExtra, errorMsg, playerId) {
      _addLog('onError: $errorCode - $errorMsg');
    });

    _player!.setOnCompletion((playerId) {
      _addLog('onCompletion: 播放完成');
      setState(() {
        _isPlaying = false;
      });
    });

    _player!.setOnLoadingStatusListener(
      loadingBegin: (playerId) => _addLog('onLoadingBegin: 缓冲开始'),
      loadingProgress: (percent, netSpeed, playerId) =>
          _addLog('缓冲进度: $percent%, 网速: $netSpeed'),
      loadingEnd: (playerId) => _addLog('onLoadingEnd: 缓冲结束'),
    );

    _player!.setOnTrackReady((playerId) async {
      _addLog('onTrackReady: 轨道准备完成');
      try {
        final mediaInfo = await _player!.getMediaInfo();
        if (mediaInfo != null && mediaInfo['tracks'] != null) {
          setState(() {
            _trackList = (mediaInfo['tracks'] as List)
                .map((e) => AVPTrackInfo.fromJson(e))
                .where((t) => t.trackType == AVPTRACK_TYPE_VIDEO)
                .toList();
          });
          _addLog('获取到 ${_trackList.length} 个视频轨道');
        }
      } catch (e) {
        _addLog('获取轨道信息失败: $e');
      }
    });

    _player!.setOnSeekComplete((playerId) {
      _addLog('onSeekComplete: 跳转完成');
    });

    _player!.setOnSubtitleExtAdded((trackIndex, url, playerId) {
      _addLog('onSubtitleExtAdded: trackIndex=$trackIndex url=$url');
      setState(() {
        if (!_extSubtitleTracks.contains(trackIndex)) {
          _extSubtitleTracks.add(trackIndex);
        }
      });
    });

    _player!.setOnSubtitleShow((trackIndex, subtitleID, subtitle, playerId) {
      _addLog('onSubtitleShow: trackIndex=$trackIndex subtitleID=$subtitleID subtitle=$subtitle');
      setState(() {
        _currentSubtitle = subtitle;
      });
    });

    _player!.setOnSubtitleHide((trackIndex, subtitleID, playerId) {
      _addLog('onSubtitleHide: trackIndex=$trackIndex subtitleID=$subtitleID');
      setState(() {
        _currentSubtitle = '';
      });
    });

    _player!.setOnThumbnailPreparedListener(
      preparedSuccess: (playerId) {
        _addLog('缩略图准备成功');
        setState(() {
          _thumbnailPrepared = true;
        });
      },
      preparedFail: (playerId) {
        _addLog('缩略图准备失败');
        setState(() {
          _thumbnailPrepared = false;
        });
      },
    );

    _player!.setOnThumbnailGetListener(
      onThumbnailGetSuccess: (bitmap, range, playerId) {
        _addLog('获取缩略图成功: range=$range');
        setState(() {
          _thumbnailBitmap = bitmap?.toString();
        });
      },
      onThumbnailGetFail: (playerId) {
        _addLog('获取缩略图失败');
      },
    );
  }

  String _getStateString(int state) {
    switch (state) {
      case PlayState.idle:
        return '空闲';
      case PlayState.initalized:
        return '已初始化';
      case PlayState.prepared:
        return '已准备';
      case PlayState.started:
        return '播放中';
      case PlayState.paused:
        return '已暂停';
      case PlayState.stopped:
        return '已停止';
      case PlayState.completion:
        return '播放完成';
      case PlayState.error:
        return '错误';
      default:
        return '未知($state)';
    }
  }

  Future<void> _setUrlAndPrepare() async {
    if (_player == null) {
      await _createPlayer();
    }
    if (_viewId >= 0) {
      await _player!.setPlayerView(_viewId);
    }
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _addLog('请输入播放地址');
      return;
    }
    setState(() {
      _isPrepared = false;
      _isPlaying = false;
      _currentPosition = 0;
      _bufferedPosition = 0;
    });
    _addLog('设置播放地址: $url');
    await _player!.setUrl(url);
    _addLog('开始准备播放...');
    await _player!.prepare();
  }

  Future<void> _play() async {
    if (_player != null && _isPrepared) {
      await _player!.play();
      setState(() => _isPlaying = true);
      _addLog('开始播放');
    }
  }

  Future<void> _pause() async {
    if (_player != null && _isPlaying) {
      await _player!.pause();
      setState(() => _isPlaying = false);
      _addLog('暂停播放');
    }
  }

  Future<void> _stop() async {
    if (_player != null) {
      await _player!.stop();
      setState(() {
        _isPlaying = false;
        _isPrepared = false;
        _currentPosition = 0;
      });
      _addLog('停止播放');
    }
  }

  Future<void> _seekTo(double value) async {
    if (_player != null && _isPrepared) {
      final position = (value * _duration).toInt();
      await _player!.seekTo(position, FlutterAvpdef.ACCURATE);
      _addLog('跳转到: ${(position / 1000).toStringAsFixed(1)}s');
    }
  }

  Future<void> _setSpeed(double speed) async {
    if (_player != null) {
      try {
        await _player!.setSpeed(speed);
        setState(() => _speed = speed);
        _addLog('设置倍速成功: ${speed}x');
      } catch (e) {
        _addLog('设置倍速失败: $e');
      }
    }
  }

  Future<void> _setVolume(double volume) async {
    if (_player != null) {
      await _player!.setVolume(volume);
      setState(() => _volume = volume);
      _addLog('设置音量: ${volume.toStringAsFixed(2)}');
    }
  }

  Future<void> _toggleMute() async {
    if (_player != null) {
      final newMuted = !_isMuted;
      await _player!.setMuted(newMuted);
      setState(() => _isMuted = newMuted);
      _addLog(newMuted ? '静音开启' : '静音关闭');
    }
  }

  Future<void> _toggleLoop() async {
    if (_player != null) {
      final newLoop = !_isLoop;
      await _player!.setLoop(newLoop);
      setState(() => _isLoop = newLoop);
      _addLog(newLoop ? '循环播放开启' : '循环播放关闭');
    }
  }

  Future<void> _setScalingMode(int mode) async {
    if (_player != null) {
      await _player!.setScalingMode(mode);
      setState(() => _scalingMode = mode);
      final modeStr = mode == ScaleMode.SCALE_ASPECT_FIT
          ? '适应'
          : mode == ScaleMode.SCALE_ASPECT_FILL
              ? '填充'
              : '拉伸';
      _addLog('缩放模式: $modeStr');
    }
  }

  Future<void> _setRotateMode(int mode) async {
    if (_player != null) {
      await _player!.setRotateMode(mode);
      if (mode == RotateMode.ROTATE_90 || mode == RotateMode.ROTATE_270) {
        await _player!.setScalingMode(ScaleMode.SCALE_ASPECT_FIT);
      }
      setState(() => _rotateMode = mode);
      _addLog('旋转模式: ${mode}°');
    }
  }

  Future<void> _setMirrorMode(int mode) async {
    if (_player != null) {
      await _player!.setMirrorMode(mode);
      setState(() => _mirrorMode = mode);
      final modeStr = mode == MirrorMode.MIRROR_MODE_NONE
          ? '无'
          : mode == MirrorMode.MIRROR_MODE_HORIZONTAL
              ? '水平镜像'
              : '垂直镜像';
      _addLog('镜像模式: $modeStr');
    }
  }

  Future<void> _setBackgroundColor(int color) async {
    if (_player != null) {
      await _player!.setVideoBackgroundColor(color);
      setState(() => _backgroundColor = color);
      _addLog('背景色已设置: 0x${color.toRadixString(16).toUpperCase()}');
    }
  }

  Future<void> _addTestSubtitle() async {
    if (_player == null || !_isPrepared) {
      _addLog('请先创建播放器并开始播放');
      return;
    }
    
    try {
      final directory = Directory('/data/storage/el2/base/haps/entry/files');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final subtitleFile = File('${directory.path}/test_subtitle.srt');
      final testSubtitle = '''1
00:00:01,000 --> 00:00:05,000
这是测试字幕第一行
字幕功能正常工作！

2
00:00:06,000 --> 00:00:10,000
这是测试字幕第二行
如果看到这行，字幕显示回调已触发

3
00:00:11,000 --> 00:00:15,000
BigBuckBunny 测试字幕
第三条内容

4
00:00:16,000 --> 00:00:20,000
继续测试字幕显示
第四条

5
00:00:21,000 --> 00:00:30,000
测试字幕最后一条
从第21秒到第30秒
''';
      
      await subtitleFile.writeAsString(testSubtitle);
      
      // 使用 file:// 前缀
      final path = 'file://${subtitleFile.path}';
      
      setState(() {
        _extSubtitleTracks.clear();
        _currentSubtitle = '';
      });
      
      _player!.addExtSubtitle(path);
      _addLog('添加测试字幕: $path');
      _showSnackBar('测试字幕已添加，请查看日志');
    } catch (e) {
      _addLog('添加测试字幕失败: $e');
    }
  }

  Future<void> _snapshot() async {
    if (_player != null) {
      final path =
          '/data/storage/el2/base/haps/entry/files/snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _player!.snapshot(path);
      _addLog('截图保存到: $path');
    }
  }

  Future<void> _getMediaInfo() async {
    if (_player != null) {
      try {
        final info = await _player!.getMediaInfo();
        _addLog('媒体信息: $info');
        if (info != null) {
          final duration = info['duration'] as int?;
          if (duration != null) {
            setState(() {
              _duration = duration;
            });
          }
        }
      } catch (e) {
        _addLog('获取媒体信息失败: $e');
      }
    }
  }

Future<void> _release() async {
    if (_player != null) {
      await _player!.release();
      setState(() {
        _playerCreated = false;
        _isPrepared = false;
        _isPlaying = false;
        _duration = 0;
      });
      _addLog('单播放器已销毁释放');
    }
  }

Future<void> _createThumbnailHelper() async {
    if (_player == null || !_isPrepared) {
      _addLog('⚠️ 请先创建播放器并开始播放');
      return;
    }
    try {
      setState(() {
        _thumbnailPrepared = false;
        _thumbnailBitmap = null;
      });
      
      final thumbnailUrl = _thumbnailUrlController.text.trim().isNotEmpty 
          ? _thumbnailUrlController.text.trim() 
          : _urlController.text.trim();
      
      _addLog('正在创建缩略图帮助器: $thumbnailUrl');
      await _player!.createThumbnailHelper(thumbnailUrl);
      _addLog('✅ 缩略图创建请求已发送 (SDK不支持此功能)');
      
      setState(() {
        _thumbnailPrepared = true;
      });
    } catch (e) {
      _addLog('❌ 创建缩略图失败: $e');
    }
  }

  Future<void> _requestThumbnail() async {
    if (_player == null || !_thumbnailPrepared) {
      _addLog('请先准备缩略图');
      return;
    }
    try {
      await _player!.requestBitmapAtPosition(_thumbnailPosition);
      _addLog('请求缩略图: position=$_thumbnailPosition');
    } catch (e) {
      _addLog('请求缩略图失败: $e');
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
    return Column(
      children: [
        buildVideoPlayer(_player, onSeek: _seekTo),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: '输入播放地址',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _setUrlAndPrepare,
                child: const Text('播放'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Trailer (52s)'),
                onPressed: () {
                  _urlController.text = 'https://media.w3.org/2010/05/sintel/trailer.mp4';
                  _addLog('切换到 Trailer');
                },
              ),
              ActionChip(
                label: const Text('BigBuckBunny'),
                onPressed: () {
                  _urlController.text = 'https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4';
                  _addLog('切换到 BigBuckBunny');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '控制'),
                    Tab(text: '设置'),
                    Tab(text: '日志'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildControlsTab(),
                      _buildSettingsTab(),
                      buildLogTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('播放器创建与销毁 (F-01)'),
          Row(
            children: [
              ElevatedButton(
                onPressed: _playerCreated ? null : _createPlayer,
                child: const Text('创建单播放器'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _playerCreated ? _release : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('销毁释放'),
              ),
            ],
          ),
          buildSectionTitle('播放控制 (F-02)'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed:
                    _isPrepared ? (_isPlaying ? _pause : _play) : null,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 36,
              ),
              IconButton(
                onPressed: _isPrepared ? _stop : null,
                icon: const Icon(Icons.stop),
                iconSize: 36,
              ),
              IconButton(
                onPressed: _isPrepared ? _snapshot : null,
                icon: const Icon(Icons.camera_alt),
                iconSize: 36,
              ),
              IconButton(
                onPressed: _getMediaInfo,
                icon: const Icon(Icons.info),
                iconSize: 36,
              ),
            ],
          ),
          buildSectionTitle('倍速播放 (F-02)'),
          Wrap(
            spacing: 8,
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              return ChoiceChip(
                label: Text('${speed}x'),
                selected: _speed == speed,
                onSelected: (_) => _setSpeed(speed),
              );
            }).toList(),
          ),
          buildSectionTitle('音量控制 (F-05)'),
          Row(
            children: [
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
              ),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 2,
                  onChanged: _setVolume,
                ),
              ),
              Text(_volume.toStringAsFixed(2)),
            ],
          ),
          if (_trackList.isNotEmpty) ...[
            buildSectionTitle('清晰度切换 (F-08)'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('自动'),
                  selected: _selectedTrackIndex == -1,
                  onSelected: (_) {
                    _player?.selectTrack(-1);
                    setState(() {
                      _selectedTrackIndex = -1;
                    });
                    _addLog('切换到自动码率');
                  },
                ),
                ..._trackList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final track = entry.value;
                  return ChoiceChip(
                    label: Text(track.trackDefinition ?? 'Track $index'),
                    selected: _selectedTrackIndex == track.trackIndex,
                    onSelected: (_) {
                      _player?.selectTrack(track.trackIndex ?? index);
                      setState(() {
                        _selectedTrackIndex = track.trackIndex ?? index;
                      });
                      _addLog('切换到轨道: ${track.trackIndex}');
                    },
                  );
                }),
              ],
            ),
          ],
          if (_videoInfo.isNotEmpty) ...[
            buildSectionTitle('媒体信息 (F-06)'),
            Text(_videoInfo, style: const TextStyle(fontSize: 12)),
          ],
          buildSectionTitle('外挂字幕 (F-09)'),
          TextField(
            controller: _subtitleUrlController,
            decoration: const InputDecoration(
              hintText: '输入字幕URL (srt/vtt)',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _isPrepared ? _addTestSubtitle : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('添加测试字幕'),
              ),
              ElevatedButton(
                onPressed: _isPrepared ? () {
                  const url = 'https://durian.blender.org/wp-content/content/subtitles/sintel_en.srt';
                  setState(() {
                    _extSubtitleTracks.clear();
                    _currentSubtitle = '';
                  });
                  _player?.addExtSubtitle(url);
                  _addLog('添加在线字幕: $url');
                } : null,
                child: const Text('在线Sintel字幕'),
              ),
              ElevatedButton(
                onPressed: _isPrepared ? () {
                  final url = _subtitleUrlController.text.trim();
                  if (url.isNotEmpty) {
                    setState(() {
                      _extSubtitleTracks.clear();
                      _currentSubtitle = '';
                    });
                    _player?.addExtSubtitle(url);
                    _addLog('添加自定义字幕: $url');
                  }
                } : null,
                child: const Text('添加自定义'),
              ),
            ],
          ),
          if (_extSubtitleTracks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✅ 字幕已添加！点击下方按钮启用:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('🔴 禁用字幕'),
                        selected: false,
                        onSelected: (_) {
                          for (final trackIndex in _extSubtitleTracks) {
                            _player?.selectExtSubtitle(trackIndex, false);
                          }
                          setState(() {
                            _currentSubtitle = '';
                          });
                          _addLog('禁用所有外挂字幕');
                        },
                      ),
                      ..._extSubtitleTracks.map((trackIndex) {
                        return ChoiceChip(
                          label: Text('✅ 启用字幕$trackIndex'),
                          selected: false,
                          selectedColor: Colors.green.withAlpha(100),
                          onSelected: (_) {
                            _player?.selectExtSubtitle(trackIndex, true);
                            _addLog('启用字幕轨道: $trackIndex');
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_currentSubtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _currentSubtitle,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
          buildSectionTitle('缩略图获取 (F-09)'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('⚠️ OHOS SDK不支持缩略图API，以下为占位演示', 
              style: TextStyle(color: Colors.orange, fontSize: 12)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _thumbnailUrlController,
            decoration: const InputDecoration(
              hintText: '缩略图URL(可选，默认使用当前视频URL)',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isPrepared ? _createThumbnailHelper : null,
                child: const Text('创建缩略图'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _thumbnailPrepared ? _requestThumbnail : null,
                child: const Text('获取缩略图'),
              ),
              const SizedBox(width: 8),
              Text('位置: ${_thumbnailPosition}ms'),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _thumbnailPosition.toDouble(),
                  min: 0,
                  max: (_duration > 0 ? _duration : 60000).toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _thumbnailPosition = value.toInt();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_thumbnailPrepared) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('✅ 缩略图已准备，可以获取'),
            ),
          ],
          if (_thumbnailBitmap != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('缩略图数据: ${_thumbnailBitmap!.substring(0, 50)}...'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('循环/自动播放 (F-02)'),
          Row(
            children: [
              FilterChip(
                label: const Text('循环'),
                selected: _isLoop,
                onSelected: (_) => _toggleLoop(),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('自动播放'),
                selected: true,
                onSelected: null,
              ),
            ],
          ),
          buildSectionTitle('缩放模式 (F-04)'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('适应'),
                selected: _scalingMode == ScaleMode.SCALE_ASPECT_FIT,
                onSelected: (_) =>
                    _setScalingMode(ScaleMode.SCALE_ASPECT_FIT),
              ),
              ChoiceChip(
                label: const Text('填充'),
                selected: _scalingMode == ScaleMode.SCALE_ASPECT_FILL,
                onSelected: (_) =>
                    _setScalingMode(ScaleMode.SCALE_ASPECT_FILL),
              ),
              ChoiceChip(
                label: const Text('拉伸'),
                selected: _scalingMode == ScaleMode.SCALE_TO_FILL,
                onSelected: (_) =>
                    _setScalingMode(ScaleMode.SCALE_TO_FILL),
              ),
            ],
          ),
          buildSectionTitle('旋转模式 (F-04)'),
          Wrap(
            spacing: 8,
            children: [0, 90, 180, 270].map((angle) {
              return ChoiceChip(
                label: Text('${angle}°'),
                selected: _rotateMode == angle,
                onSelected: (_) => _setRotateMode(angle),
              );
            }).toList(),
          ),
          buildSectionTitle('镜像模式 (F-04)'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('无'),
                selected: _mirrorMode == MirrorMode.MIRROR_MODE_NONE,
                onSelected: (_) =>
                    _setMirrorMode(MirrorMode.MIRROR_MODE_NONE),
              ),
              ChoiceChip(
                label: const Text('水平'),
                selected: _mirrorMode == MirrorMode.MIRROR_MODE_HORIZONTAL,
                onSelected: (_) =>
                    _setMirrorMode(MirrorMode.MIRROR_MODE_HORIZONTAL),
              ),
              ChoiceChip(
                label: const Text('垂直'),
                selected: _mirrorMode == MirrorMode.MIRROR_MODE_VERTICAL,
                onSelected: (_) =>
                    _setMirrorMode(MirrorMode.MIRROR_MODE_VERTICAL),
              ),
            ],
          ),
          buildSectionTitle('背景色 (F-04)'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('黑色'),
                selected: _backgroundColor == 0xFF000000,
                onSelected: (_) => _setBackgroundColor(0xFF000000),
              ),
              ChoiceChip(
                label: const Text('白色'),
                selected: _backgroundColor == 0xFFFFFFFF,
                onSelected: (_) => _setBackgroundColor(0xFFFFFFFF),
              ),
              ChoiceChip(
                label: const Text('蓝色'),
                selected: _backgroundColor == 0xFF0000FF,
                onSelected: (_) => _setBackgroundColor(0xFF0000FF),
              ),
              ChoiceChip(
                label: const Text('绿色'),
                selected: _backgroundColor == 0xFF00FF00,
                onSelected: (_) => _setBackgroundColor(0xFF00FF00),
              ),
              ChoiceChip(
                label: const Text('红色'),
                selected: _backgroundColor == 0xFFFF0000,
                onSelected: (_) => _setBackgroundColor(0xFFFF0000),
              ),
            ],
          ),
          buildSectionTitle('默认带宽 (F-08)'),
          Text('prepare前设置，多码率时选择最接近的流', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              {'label': '不限', 'value': 0},
              {'label': '500kbps', 'value': 500000},
              {'label': '1Mbps', 'value': 1000000},
              {'label': '2Mbps', 'value': 2000000},
              {'label': '5Mbps', 'value': 5000000},
            ].map((item) {
              return ChoiceChip(
                label: Text(item['label'] as String),
                selected: _defaultBandWidth == (item['value'] as int),
                onSelected: (_) {
                  final bw = item['value'] as int;
                  _player?.setDefaultBandWidth(bw);
                  setState(() {
                    _defaultBandWidth = bw;
                  });
                  _addLog('设置默认带宽: ${item['label']}');
                },
              );
            }).toList(),
          ),
          buildSectionTitle('默认分辨率 (F-08)'),
          Text('prepare前设置，多码率时选择最接近的流', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              {'label': '不限', 'value': PixelNumber.Resolution_NoLimit},
              {'label': '360P', 'value': PixelNumber.Resolution_360P},
              {'label': '480P', 'value': PixelNumber.Resolution_480P},
              {'label': '540P', 'value': PixelNumber.Resolution_540P},
              {'label': '720P', 'value': PixelNumber.Resolution_720P},
              {'label': '1080P', 'value': PixelNumber.Resolution_1080P},
              {'label': '2K', 'value': PixelNumber.Resolution_2K},
              {'label': '4K', 'value': PixelNumber.Resolution_4K},
            ].map((item) {
              return ChoiceChip(
                label: Text(item['label'] as String),
                selected: _defaultResolution == (item['value'] as int),
                onSelected: (_) {
                  final res = item['value'] as int;
                  _player?.setDefaultResolution(res);
                  setState(() {
                    _defaultResolution = res;
                  });
                  _addLog('设置默认分辨率: ${item['label']}');
                },
              );
            }).toList(),
          ),
          buildSectionTitle('播放器配置'),
          Text('prepare前设置，影响播放器行为',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('最大缓冲: ${(_maxBufferDuration / 1000).toStringAsFixed(0)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            value: _maxBufferDuration.toDouble(),
            min: 5000,
            max: 120000,
            divisions: 23,
            label: '${(_maxBufferDuration / 1000).toStringAsFixed(0)}秒',
            onChanged: (value) {
              setState(() {
                _maxBufferDuration = value.toInt();
              });
            },
          ),
          Text('高水位缓冲: ${(_highBufferDuration / 1000).toStringAsFixed(0)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            value: _highBufferDuration.toDouble(),
            min: 1000,
            max: 30000,
            divisions: 29,
            label: '${(_highBufferDuration / 1000).toStringAsFixed(0)}秒',
            onChanged: (value) {
              setState(() {
                _highBufferDuration = value.toInt();
              });
            },
          ),
          Text('起播缓冲: ${(_startBufferDuration / 1000).toStringAsFixed(1)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            value: _startBufferDuration.toDouble(),
            min: 100,
            max: 5000,
            divisions: 49,
            label: '${(_startBufferDuration / 1000).toStringAsFixed(1)}秒',
            onChanged: (value) {
              setState(() {
                _startBufferDuration = value.toInt();
              });
            },
          ),
          const SizedBox(height: 4),
          Text('网络超时: ${(_networkTimeout / 1000).toStringAsFixed(0)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            value: _networkTimeout.toDouble(),
            min: 5000,
            max: 60000,
            divisions: 11,
            label: '${(_networkTimeout / 1000).toStringAsFixed(0)}秒',
            onChanged: (value) {
              setState(() {
                _networkTimeout = value.toInt();
              });
            },
          ),
          Text('重试次数: $_networkRetryCount 次',
              style: const TextStyle(fontSize: 12)),
          Slider(
            value: _networkRetryCount.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            label: '$_networkRetryCount 次',
            onChanged: (value) {
              setState(() {
                _networkRetryCount = value.toInt();
              });
            },
          ),
          const SizedBox(height: 4),
          Text('HTTP代理 (可选):', style: const TextStyle(fontSize: 12)),
          TextField(
            controller: _proxyController,
            decoration: const InputDecoration(
              hintText: 'http://ip:port',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _httpProxy = value;
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _applyPlayConfig,
            child: const Text('应用配置'),
          ),
          const SizedBox(height: 16),
          buildSectionTitle('SDK 信息'),
          Text('版本: ${widget.sdkVersion}',
              style: const TextStyle(fontSize: 12)),
          Text('Platform: ${Platform.operatingSystem}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class ListPlayerTab extends _BasePlayerTab {
  const ListPlayerTab({required super.sdkVersion});

  @override
  State<ListPlayerTab> createState() => _ListPlayerTabState();
}

class _ListPlayerTabState extends _BasePlayerTabState<ListPlayerTab> {
  FlutterAliListPlayer? _listPlayer;
  bool _playerCreated = false;
  String _currentUid = '';
  int _preloadCount = 2;

  final List<_PlaylistItem> _playlist = [];
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();

  // 预置的视频源列表
  final List<_PlaylistItem> _defaultPlaylist = [
    _PlaylistItem(
      url: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
      uid: 'video_1_sintel',
    ),
    _PlaylistItem(
      url: 'https://media.w3.org/2010/05/bunny/trailer.mp4',
      uid: 'video_2_bunny',
    ),
    _PlaylistItem(
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      uid: 'video_3_hls',
    ),
  ];

  Future<void> _createListPlayer() async {
    try {
      if (_listPlayer != null) {
        await _listPlayer!.release();
      }
      _listPlayer = FlutterAliListPlayer.init('demo_list_player');
      _addLog('调用 create()...');
      await _listPlayer!.create();
      _setupEventListeners();
      setState(() {
        _playerCreated = true;
      });
      _addLog('列表播放器创建成功');
      _showSnackBar('列表播放器创建成功');
    } catch (e) {
      _addLog('创建列表播放器失败: $e');
      _showSnackBar('创建失败: $e');
    }
  }

  Future<void> _loadDefaultPlaylist() async {
    try {
      if (_listPlayer == null) {
        _addLog('列表播放器未创建，自动创建...');
        await _createListPlayer();
      }
      if (_listPlayer == null) {
        _showSnackBar('创建播放器失败');
        return;
      }

      _addLog('加载默认播放列表...');
      for (final item in _defaultPlaylist) {
        await _listPlayer!.addUrlSource(url: item.url, uid: item.uid);
        setState(() {
          _playlist.add(item);
        });
        _addLog('添加: ${item.uid}');
      }
      _showSnackBar('已加载 ${_defaultPlaylist.length} 个视频');
      
      // 自动播放第一个
      if (_playlist.isNotEmpty) {
        _addLog('自动播放第一个视频...');
        await _playItem(_playlist.first.uid);
      }
    } catch (e) {
      _addLog('加载默认列表失败: $e');
      _showSnackBar('加载失败: $e');
    }
  }

  void _setupEventListeners() {
    if (_listPlayer == null) return;

    // ListPlayer 的回调通过 EventChannel 发送，需要监听事件流
    // 注意：目前 OHOS 端可能不支持 BasicMessageChannel 方式
    // 所以我们直接使用继承自 FlutterAliplayer 的事件处理
    _listPlayer!.setOnPrepared((playerId) {
      _addLog('onPrepared: 准备完成');
      setState(() {
        _isPrepared = true;
      });
      _listPlayer!.getDuration().then((d) {
        if (d != null && d is int) {
          setState(() {
            _duration = d;
          });
        }
      });
      // 自动开始播放
      _listPlayer!.play();
      setState(() {
        _isPlaying = true;
      });
      _addLog('自动播放开始');
    });

    _listPlayer!.setOnRenderingStart((playerId) {
      _addLog('onRenderingStart: 首帧渲染');
    });

    _listPlayer!.setOnStateChanged((newState, playerId) {
      _addLog('onStateChanged: $newState');
      setState(() {
        if (newState == PlayState.started) {
          _isPlaying = true;
        } else if (newState == PlayState.paused ||
            newState == PlayState.stopped) {
          _isPlaying = false;
        }
      });
    });

    _listPlayer!.setOnInfo((infoCode, extraValue, extraMsg, playerId) {
      if (infoCode == InfoCode.CURRENTPOSITION) {
        setState(() {
          _currentPosition = extraValue ?? 0;
        });
      } else if (infoCode == InfoCode.BUFFEREDPOSITION) {
        setState(() {
          _bufferedPosition = extraValue ?? 0;
        });
      }
    });

    _listPlayer!.setOnError((errorCode, errorExtra, errorMsg, playerId) {
      _addLog('onError: $errorCode - $errorMsg');
    });

    _listPlayer!.setOnCompletion((playerId) {
      _addLog('onCompletion: 播放完成');
      setState(() {
        _isPlaying = false;
      });
    });

    _listPlayer!.setOnLoadingStatusListener(
      loadingBegin: (playerId) => _addLog('onLoadingBegin'),
      loadingProgress: (percent, netSpeed, playerId) =>
          _addLog('缓冲进度: $percent%'),
      loadingEnd: (playerId) => _addLog('onLoadingEnd'),
    );
  }

  Future<void> _addUrlSource() async {
    try {
      if (_listPlayer == null) {
        _addLog('列表播放器未创建，自动创建...');
        await _createListPlayer();
      }
      if (_listPlayer == null) {
        _showSnackBar('创建播放器失败，请查看日志');
        return;
      }
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        _showSnackBar('请输入播放地址');
        return;
      }
      final uid = _uidController.text.trim().isEmpty
          ? 'uid_${DateTime.now().millisecondsSinceEpoch}'
          : _uidController.text.trim();
      
      _addLog('正在添加资源: uid=$uid, url=$url');
      await _listPlayer!.addUrlSource(url: url, uid: uid);
      
      setState(() {
        _playlist.add(_PlaylistItem(url: url, uid: uid));
        _uidController.clear();
      });
      _addLog('添加URL资源成功: uid=$uid');
      _showSnackBar('已添加: $uid');
      
      if (_playlist.length == 1) {
        _addLog('自动开始播放第一个资源...');
        await _playItem(uid);
      }
    } catch (e) {
      _addLog('添加资源失败: $e');
      _showSnackBar('添加失败: $e');
    }
  }

  Future<void> _removeSource(String uid) async {
    if (_listPlayer == null) return;
    await _listPlayer!.removeSource(uid);
    setState(() {
      _playlist.removeWhere((item) => item.uid == uid);
    });
    _addLog('移除资源: uid=$uid');
  }

  Future<void> _clearPlaylist() async {
    try {
      if (_listPlayer == null) {
        setState(() {
          _playlist.clear();
          _currentUid = '';
          _isPrepared = false;
          _isPlaying = false;
          _currentPosition = 0;
          _duration = 0;
        });
        _addLog('播放列表已清空');
        return;
      }
      // 先停止播放，再清空列表
      if (_isPlaying || _isPrepared) {
        await _listPlayer!.stop();
        _addLog('停止播放');
      }
      await _listPlayer!.clear();
      setState(() {
        _playlist.clear();
        _currentUid = '';
        _isPrepared = false;
        _isPlaying = false;
        _currentPosition = 0;
        _bufferedPosition = 0;
        _duration = 0;
      });
      _addLog('播放列表已清空');
      _showSnackBar('列表已清空');
    } catch (e) {
      _addLog('清空列表错误: $e');
      // 即使原生端失败，也要清理 UI 状态
      setState(() {
        _playlist.clear();
        _currentUid = '';
        _isPrepared = false;
        _isPlaying = false;
        _currentPosition = 0;
        _bufferedPosition = 0;
        _duration = 0;
      });
    }
  }

  Future<void> _playItem(String uid) async {
    try {
      _addLog('_playItem called: uid=$uid');
      if (_listPlayer == null) {
        _addLog('错误: 列表播放器为 null');
        _showSnackBar('播放器未创建');
        return;
      }
      
      // 找到对应的 URL
      final item = _playlist.firstWhere((i) => i.uid == uid);
      
      if (_viewId >= 0) {
        _addLog('绑定播放器视图: viewId=$_viewId');
        await _listPlayer!.setPlayerView(_viewId);
      } else {
        _addLog('警告: viewId=$_viewId, 视图未创建');
      }
      
      setState(() {
        _isPrepared = false;
        _isPlaying = false;
        _currentPosition = 0;
        _duration = 0;
        _currentUid = uid;
      });
      
      // 尝试直接用 setUrl 方式，而不是 moveTo
      _addLog('尝试 setUrl 方式播放: url=${item.url}');
      await _listPlayer!.setUrl(item.url);
      _addLog('setUrl 完成, 调用 prepare...');
      await _listPlayer!.prepare();
      _addLog('prepare 完成, 等待回调...');
      
      // 延迟后手动调用 play
      await Future.delayed(const Duration(milliseconds: 1000));
      _addLog('手动调用 play()');
      await _listPlayer!.play();
      setState(() {
        _isPlaying = true;
        _isPrepared = true;
      });
      _addLog('play 已调用');
    } catch (e) {
      _addLog('_playItem 错误: $e');
      _showSnackBar('播放失败: $e');
    }
  }

  Future<void> _moveToNext() async {
    if (_listPlayer == null || _playlist.isEmpty) return;
    try {
      final currentIdx = _playlist.indexWhere((item) => item.uid == _currentUid);
      if (currentIdx < 0) {
        _addLog('未找到当前播放项');
        return;
      }
      final nextIdx = (currentIdx + 1) % _playlist.length;
      final nextItem = _playlist[nextIdx];
      _addLog('移动到下一个: ${nextItem.uid}');
      await _playItem(nextItem.uid);
    } catch (e) {
      _addLog('moveToNext 错误: $e');
    }
  }

  Future<void> _moveToPre() async {
    if (_listPlayer == null || _playlist.isEmpty) return;
    try {
      final currentIdx = _playlist.indexWhere((item) => item.uid == _currentUid);
      if (currentIdx < 0) {
        _addLog('未找到当前播放项');
        return;
      }
      final preIdx = (currentIdx - 1 + _playlist.length) % _playlist.length;
      final preItem = _playlist[preIdx];
      _addLog('移动到上一个: ${preItem.uid}');
      await _playItem(preItem.uid);
    } catch (e) {
      _addLog('moveToPre 错误: $e');
    }
  }

  Future<void> _listSeekTo(double value) async {
    if (_listPlayer != null && _isPrepared && _duration > 0) {
      final position = (value * _duration).toInt();
      _addLog('列表播放器 seekTo: $position ms');
      await _listPlayer!.seekTo(position, FlutterAvpdef.ACCURATE);
    }
  }

  Future<void> _setPreloadCount(int count) async {
    setState(() {
      _preloadCount = count;
    });
    _addLog('设置预加载个数: $count (OHOS端暂不支持setPreloadCount)');
  }

  Future<void> _play() async {
    if (_listPlayer != null && _isPrepared) {
      await _listPlayer!.play();
      setState(() => _isPlaying = true);
      _addLog('开始播放');
    }
  }

  Future<void> _pause() async {
    if (_listPlayer != null && _isPlaying) {
      await _listPlayer!.pause();
      setState(() => _isPlaying = false);
      _addLog('暂停播放');
    }
  }

  Future<void> _stop() async {
    if (_listPlayer != null) {
      await _listPlayer!.stop();
      setState(() {
        _isPlaying = false;
        _isPrepared = false;
        _currentPosition = 0;
      });
      _addLog('停止播放');
    }
  }

  Future<void> _release() async {
    if (_listPlayer != null) {
      await _listPlayer!.release();
      setState(() {
        _listPlayer = null;
        _playerCreated = false;
        _isPrepared = false;
        _isPlaying = false;
        _currentPosition = 0;
        _bufferedPosition = 0;
        _duration = 0;
        _playlist.clear();
        _currentUid = '';
      });
      _addLog('列表播放器已销毁释放');
    }
  }

  @override
  void dispose() {
    _listPlayer?.release();
    _urlController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildVideoPlayer(_listPlayer, onSeek: _listSeekTo),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '列表管理'),
                    Tab(text: '控制'),
                    Tab(text: '日志'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildListManageTab(),
                      _buildControlsTab(),
                      buildLogTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListManageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('列表播放器创建与销毁 (F-01)'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '注意: 列表播放器在 OHOS 平台上可能存在兼容性问题，'
              '部分功能可能不如单播放器稳定。',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _playerCreated ? null : _createListPlayer,
                child: const Text('创建列表播放器'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _playerCreated ? _release : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('销毁释放'),
              ),
            ],
          ),
          buildSectionTitle('添加播放资源'),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadDefaultPlaylist,
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('加载默认列表'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addUrlSource,
                  child: const Text('添加自定义'),
                ),
              ),
            ],
          ),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: '输入视频URL地址',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _uidController,
            decoration: const InputDecoration(
              hintText: '输入资源UID (可选，自动生成)',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: _addUrlSource,
            child: const Text('添加到列表'),
          ),
          buildSectionTitle('预加载设置 (OHOS端不支持)'),
          Row(
            children: [
              const Text('预加载个数: ', style: TextStyle(color: Colors.grey)),
              DropdownButton<int>(
                value: _preloadCount,
                items: [1, 2, 3, 4, 5]
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text('$v'),
                        ))
                    .toList(),
                onChanged: null, // OHOS 端不支持，禁用
              ),
            ],
          ),
          buildSectionTitle('播放列表 (${_playlist.length}项)'),
          if (_playlist.isEmpty)
            const Text('列表为空，请添加资源', style: TextStyle(color: Colors.grey))
          else ...[
            ..._playlist.map((item) => ListTile(
                  dense: true,
                  selected: _currentUid == item.uid,
                  selectedTileColor: Colors.red.withOpacity(0.1),
                  title: Text(item.uid,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(item.url,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentUid == item.uid && _isPlaying)
                        const Icon(Icons.play_arrow, color: Colors.green, size: 18),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () => _removeSource(item.uid),
                      ),
                    ],
                  ),
                  onTap: () {
                    _showSnackBar('点击播放: ${item.uid}');
                    _playItem(item.uid);
                  },
                )),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _clearPlaylist,
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('清空列表'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('列表播放控制'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _isPrepared
                    ? (_isPlaying ? _pause : _play)
                    : (_currentUid.isNotEmpty ? () => _playItem(_currentUid) : null),
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 36,
                tooltip: _isPrepared
                    ? (_isPlaying ? '暂停' : '播放')
                    : '准备并播放',
              ),
              IconButton(
                onPressed: _isPrepared ? _stop : null,
                icon: const Icon(Icons.stop),
                iconSize: 36,
                tooltip: '停止',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _playerCreated ? _moveToPre : null,
                icon: const Icon(Icons.skip_previous),
                label: const Text('上一个'),
              ),
              ElevatedButton.icon(
                onPressed: _playerCreated ? _moveToNext : null,
                icon: const Icon(Icons.skip_next),
                label: const Text('下一个'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaylistItem {
  final String url;
  final String uid;
  _PlaylistItem({required this.url, required this.uid});
}

class LiveShiftPlayerTab extends _BasePlayerTab {
  const LiveShiftPlayerTab({required super.sdkVersion});

  @override
  State<LiveShiftPlayerTab> createState() => _LiveShiftPlayerTabState();
}

class _LiveShiftPlayerTabState
    extends _BasePlayerTabState<LiveShiftPlayerTab> {
  FlutterAliLiveShiftPlayer? _liveShiftPlayer;
  bool _playerCreated = false;
  int _currentLiveTime = 0;
  int _currentTime = 0;
  int _shiftStartTime = 0;
  int _shiftEndTime = 0;

  // 使用公开的 HLS 测试直播流
  final TextEditingController _urlController = TextEditingController(
    text: 'http://liteavapp.qcloud.com/live/liteavdemoplayerstreamid.flv',
  );
  final TextEditingController _timeLineUrlController =
      TextEditingController(
    text: '', // 时移时间线需要服务端支持，测试流通常没有
  );

  Future<void> _createLiveShiftPlayer() async {
    try {
      if (_liveShiftPlayer != null) {
        await _liveShiftPlayer!.release();
      }
      _liveShiftPlayer = FlutterAliLiveShiftPlayer.init('demo_liveshift_player');
      _addLog('调用 create()...');
      await _liveShiftPlayer!.create();
      _setupEventListeners();
      setState(() {
        _playerCreated = true;
      });
      _addLog('直播时移播放器创建成功');
      _showSnackBar('直播时移播放器创建成功');
    } catch (e) {
      _addLog('创建直播时移播放器失败: $e');
      _showSnackBar('创建失败: $e');
    }
  }

  void _setupEventListeners() {
    if (_liveShiftPlayer == null) return;

    _liveShiftPlayer!.setOnPrepared((playerId) {
      _addLog('onPrepared: 准备完成');
      setState(() {
        _isPrepared = true;
      });
    });

    _liveShiftPlayer!.setOnRenderingStart((playerId) {
      _addLog('onRenderingStart: 首帧渲染');
    });

    _liveShiftPlayer!.setOnStateChanged((newState, playerId) {
      _addLog('onStateChanged: $newState');
      setState(() {
        if (newState == PlayState.started) {
          _isPlaying = true;
        } else if (newState == PlayState.paused ||
            newState == PlayState.stopped) {
          _isPlaying = false;
        }
      });
    });

    _liveShiftPlayer!.setOnInfo((infoCode, extraValue, extraMsg, playerId) {
      if (infoCode == InfoCode.CURRENTPOSITION) {
        setState(() {
          _currentPosition = extraValue ?? 0;
        });
      } else if (infoCode == InfoCode.BUFFEREDPOSITION) {
        setState(() {
          _bufferedPosition = extraValue ?? 0;
        });
      }
    });

    _liveShiftPlayer!.setOnError((errorCode, errorExtra, errorMsg, playerId) {
      _addLog('onError: $errorCode - $errorMsg');
    });

    _liveShiftPlayer!.setOnCompletion((playerId) {
      _addLog('onCompletion: 播放完成');
      setState(() {
        _isPlaying = false;
      });
    });

    _liveShiftPlayer!.setOnLoadingStatusListener(
      loadingBegin: (playerId) => _addLog('onLoadingBegin'),
      loadingProgress: (percent, netSpeed, playerId) =>
          _addLog('缓冲进度: $percent%'),
      loadingEnd: (playerId) => _addLog('onLoadingEnd'),
    );

    _liveShiftPlayer!.setOnSeekLiveCompletion((playTime, playerId) {
      _addLog('onSeekLiveCompletion: 时移跳转完成, playTime=$playTime');
    });

    _liveShiftPlayer!.setOnTimeShiftUpdater(
        (currentTime, shiftStart, shiftEnd, playerId) {
      _addLog(
          'onTimeShiftUpdater: currentTime=$currentTime, range=$shiftStart~$shiftEnd');
      setState(() {
        _currentTime = currentTime;
        _shiftStartTime = shiftStart;
        _shiftEndTime = shiftEnd;
      });
    });
  }

  Future<void> _setDataSource() async {
    try {
      if (_liveShiftPlayer == null) {
        _addLog('播放器未创建，自动创建...');
        await _createLiveShiftPlayer();
      }
      if (_liveShiftPlayer == null) {
        _showSnackBar('创建播放器失败');
        return;
      }
      if (_viewId >= 0) {
        _addLog('绑定播放器视图: viewId=$_viewId');
        await _liveShiftPlayer!.setPlayerView(_viewId);
      }
      final url = _urlController.text.trim();
      final timeLineUrl = _timeLineUrlController.text.trim();
      if (url.isEmpty) {
        _addLog('请输入直播地址');
        _showSnackBar('请输入直播地址');
        return;
      }
      setState(() {
        _isPrepared = false;
        _isPlaying = false;
        _currentPosition = 0;
        _bufferedPosition = 0;
      });
      
      // 如果有时间线 URL，使用完整的直播时移功能
      if (timeLineUrl.isNotEmpty) {
        _addLog('使用直播时移模式: url=$url, timeLineUrl=$timeLineUrl');
        await _liveShiftPlayer!.setDataSource(timeLineUrl, url);
      } else {
        // 否则使用普通 URL 模式测试播放器
        _addLog('使用普通播放模式（无时移）: url=$url');
        await _liveShiftPlayer!.setUrl(url);
      }
      _addLog('调用 prepare()...');
      await _liveShiftPlayer!.prepare();
      _addLog('prepare 完成，等待回调...');
      
      // 延迟后自动播放
      await Future.delayed(const Duration(milliseconds: 500));
      await _liveShiftPlayer!.play();
      setState(() {
        _isPlaying = true;
      });
      _addLog('play 已调用');
    } catch (e) {
      _addLog('设置数据源错误: $e');
      _showSnackBar('播放失败: $e');
    }
  }

  Future<void> _play() async {
    if (_liveShiftPlayer != null && _isPrepared) {
      await _liveShiftPlayer!.play();
      setState(() => _isPlaying = true);
      _addLog('开始播放');
    }
  }

  Future<void> _pause() async {
    if (_liveShiftPlayer != null && _isPlaying) {
      await _liveShiftPlayer!.pause();
      setState(() => _isPlaying = false);
      _addLog('暂停播放');
    }
  }

  Future<void> _stop() async {
    if (_liveShiftPlayer != null) {
      await _liveShiftPlayer!.stop();
      setState(() {
        _isPlaying = false;
        _isPrepared = false;
        _currentPosition = 0;
      });
      _addLog('停止播放');
    }
  }

  Future<void> _seekToLiveTime() async {
    if (_liveShiftPlayer == null) return;
    final targetTime = _shiftStartTime + ((_shiftEndTime - _shiftStartTime) ~/ 2);
    if (targetTime > 0) {
      await _liveShiftPlayer!.seekToLiveTime(targetTime);
      _addLog('时移跳转到: $targetTime');
    } else {
      _addLog('无可用的时移范围，无法跳转');
    }
  }

  Future<void> _seekToLiveStart() async {
    if (_liveShiftPlayer == null) return;
    if (_shiftStartTime > 0) {
      await _liveShiftPlayer!.seekToLiveTime(_shiftStartTime);
      _addLog('时移跳转到起始: $_shiftStartTime');
    } else {
      _addLog('无可用的时移范围');
    }
  }

  Future<void> _getCurrentLiveTime() async {
    if (_liveShiftPlayer == null) return;
    try {
      // getCurrentLiveTime 是阿里云直播时移服务专属API，普通直播流返回0
      // 这里用系统时间模拟直播时间显示
      final result = await _liveShiftPlayer!.getCurrentLiveTime();
      if (result != null && result is int && result > 0) {
        _addLog('当前直播时间: $result');
        setState(() {
          _currentLiveTime = result;
        });
      } else {
        // 普通直播流，使用系统时间模拟
        final now = DateTime.now().millisecondsSinceEpoch;
        _addLog('当前直播时间: $now (系统时间，非时移服务)');
        setState(() {
          _currentLiveTime = now;
        });
      }
    } catch (e) {
      _addLog('获取直播时间失败: $e');
    }
  }

  Future<void> _getCurrentTime() async {
    if (_liveShiftPlayer == null) return;
    try {
      // getCurrentTime 是阿里云直播时移服务专属API，普通直播流返回-1
      // 改用 getCurrentPosition 获取当前播放位置
      final position = await _liveShiftPlayer!.getCurrentPosition();
      _addLog('当前播放位置: ${position ?? _currentPosition} ms');
      setState(() {
        _currentTime = position ?? _currentPosition;
      });
    } catch (e) {
      _addLog('获取播放位置失败: $e');
      setState(() {
        _currentTime = _currentPosition;
      });
    }
  }

  Future<void> _release() async {
    if (_liveShiftPlayer != null) {
      await _liveShiftPlayer!.release();
      setState(() {
        _liveShiftPlayer = null;
        _playerCreated = false;
        _isPrepared = false;
        _isPlaying = false;
        _currentPosition = 0;
        _bufferedPosition = 0;
        _currentLiveTime = 0;
        _currentTime = 0;
        _shiftStartTime = 0;
        _shiftEndTime = 0;
      });
      _addLog('直播时移播放器已销毁释放');
    }
  }

  String _formatTimestamp(int ms) {
    if (ms <= 0) return '--';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _liveShiftPlayer?.release();
    _urlController.dispose();
    _timeLineUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildVideoPlayer(_liveShiftPlayer),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '数据源'),
                    Tab(text: '时移控制'),
                    Tab(text: '日志'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildDataSourceTab(),
                      _buildLiveShiftControlsTab(),
                      buildLogTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataSourceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('时移播放器创建与销毁 (F-01)'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '注意: 直播时移播放器在 OHOS 平台上可能存在兼容性问题，'
              '需要实际直播流和时间线服务支持。',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _playerCreated ? null : _createLiveShiftPlayer,
                child: const Text('创建时移播放器'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _playerCreated ? _release : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('销毁释放'),
              ),
            ],
          ),
          buildSectionTitle('直播数据源设置 (F-03)'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '提示: 只输入直播流地址即可测试播放。\n'
              '时移时间线地址需要服务端支持，留空则使用普通播放模式。',
              style: TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: '直播流地址 (必填)',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _timeLineUrlController,
            decoration: const InputDecoration(
              hintText: '时移时间线地址 (可选)',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _setDataSource,
                  child: const Text('设置并播放'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveShiftControlsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('播放控制'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed:
                    _isPrepared ? (_isPlaying ? _pause : _play) : null,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 36,
              ),
              IconButton(
                onPressed: _isPrepared ? _stop : null,
                icon: const Icon(Icons.stop),
                iconSize: 36,
              ),
            ],
          ),
          buildSectionTitle('时移控制'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _playerCreated && _isPrepared
                    ? _seekToLiveStart
                    : null,
                icon: const Icon(Icons.replay),
                label: const Text('跳到起始'),
              ),
              ElevatedButton.icon(
                onPressed: _playerCreated && _isPrepared
                    ? _seekToLiveTime
                    : null,
                icon: const Icon(Icons.history),
                label: const Text('跳到中间'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed:
                    _playerCreated ? _getCurrentLiveTime : null,
                child: const Text('获取直播时间'),
              ),
              ElevatedButton(
                onPressed: _playerCreated ? _getCurrentTime : null,
                child: const Text('获取播放位置'),
              ),
            ],
          ),
          buildSectionTitle('播放信息'),
          _buildInfoRow('直播时间', _formatTimestamp(_currentLiveTime)),
          _buildInfoRow('播放位置', _formatDuration(_currentTime)),
          buildSectionTitle('时移范围 (需阿里云时移服务)'),
          _buildInfoRow('时移起始', _formatTimestamp(_shiftStartTime)),
          _buildInfoRow('时移结束', _formatTimestamp(_shiftEndTime)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

const int AVPTRACK_TYPE_VIDEO = 0;
const int AVPTRACK_TYPE_AUDIO = 1;
const int AVPTRACK_TYPE_SUBTITLE = 2;

class DownloaderTab extends _BasePlayerTab {
  const DownloaderTab({required super.sdkVersion});

  @override
  State<DownloaderTab> createState() => _DownloaderTabState();
}

class _DownloaderTabState extends _BasePlayerTabState<DownloaderTab> {
  FlutterAliDownloader? _downloader;
  final TextEditingController _vidController = TextEditingController();
  final TextEditingController _accessKeyIdController = TextEditingController();
  final TextEditingController _accessKeySecretController = TextEditingController();
  final TextEditingController _securityTokenController = TextEditingController();
  final TextEditingController _regionController = TextEditingController(text: 'cn-shanghai');
  
  String _downloadType = FlutterAvpdef.DOWNLOADTYPE_STS;
  String _downloadStatus = '未开始';
  double _downloadProgress = 0;
  String _downloadPath = '';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initDownloader();
  }

  Future<void> _initDownloader() async {
    _downloader = FlutterAliDownloader.init();
    _addLog('下载器初始化完成');
  }

  void _handleDownloadEvent(dynamic event) {
    try {
      final Map<String, dynamic> data = event is String 
          ? Map<String, dynamic>.from(const JsonDecoder().convert(event))
          : Map<String, dynamic>.from(event as Map);
      
      final String eventType = data['event'] ?? '';
      
      switch (eventType) {
        case 'download_prepared':
          setState(() {
            _downloadStatus = '准备完成';
          });
          _addLog('下载准备完成');
          break;
        case 'download_progress':
          final percent = (data['percent'] as num?)?.toDouble() ?? 0;
          setState(() {
            _downloadProgress = percent;
            _downloadStatus = '下载中: ${percent.toStringAsFixed(1)}%';
          });
          break;
        case 'download_process':
          final percent = (data['percent'] as num?)?.toDouble() ?? 0;
          setState(() {
            _downloadProgress = percent;
            _downloadStatus = '处理中: ${percent.toStringAsFixed(1)}%';
          });
          break;
        case 'download_completion':
          setState(() {
            _downloadStatus = '下载完成';
            _downloadProgress = 100;
            _downloadPath = data['savePath'] ?? '';
          });
          _addLog('下载完成: ${_downloadPath}');
          break;
        case 'download_error':
          final errorCode = data['errorCode'];
          final errorMessage = data['errorMessage'];
          setState(() {
            _downloadStatus = '下载失败: $errorMessage';
          });
          _addLog('下载错误: $errorCode - $errorMessage');
          break;
      }
    } catch (e) {
      _addLog('事件解析错误: $e');
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _prepareDownload() async {
    if (_downloader == null) {
      _addLog('下载器未初始化');
      return;
    }

    final vid = _vidController.text.trim();
    if (vid.isEmpty) {
      _addLog('请输入视频ID');
      return;
    }

    try {
      setState(() {
        _downloadStatus = '准备中...';
        _downloadProgress = 0;
      });

      if (Platform.isOhos) {
        final savePath = '/data/storage/el2/base/haps/entry/files/download';
        _downloader!.setSaveDir(savePath);
        _addLog('设置下载目录: $savePath');
      }

      if (_downloadType == FlutterAvpdef.DOWNLOADTYPE_STS) {
        await _downloader!.prepare(
          _downloadType,
          vid,
          region: _regionController.text.trim(),
          accessKeyId: _accessKeyIdController.text.trim(),
          accessKeySecret: _accessKeySecretController.text.trim(),
          securityToken: _securityTokenController.text.trim(),
        );
      } else {
        _addLog('AUTH方式暂不支持，请使用STS');
      }
      
      _addLog('开始准备下载: $vid');
    } catch (e) {
      setState(() {
        _downloadStatus = '准备失败';
      });
      _addLog('准备失败: $e');
    }
  }

  Future<void> _startDownload() async {
    if (_downloader == null) {
      _addLog('下载器未初始化');
      return;
    }

    final vid = _vidController.text.trim();
    if (vid.isEmpty) {
      _addLog('请输入视频ID');
      return;
    }

    try {
      _downloader!.start(vid, 0);
      _addLog('开始下载: $vid');
    } catch (e) {
      _addLog('开始下载失败: $e');
    }
  }

  Future<void> _stopDownload() async {
    if (_downloader == null) {
      _addLog('下载器未初始化');
      return;
    }

    final vid = _vidController.text.trim();
    try {
      await _downloader!.stop(vid, 0);
      setState(() {
        _downloadStatus = '已停止';
      });
      _addLog('停止下载: $vid');
    } catch (e) {
      _addLog('停止失败: $e');
    }
  }

  Future<void> _deleteDownload() async {
    if (_downloader == null) {
      _addLog('下载器未初始化');
      return;
    }

    final vid = _vidController.text.trim();
    try {
      await _downloader!.delete(vid, 0);
      setState(() {
        _downloadStatus = '已删除';
        _downloadProgress = 0;
      });
      _addLog('删除下载: $vid');
    } catch (e) {
      _addLog('删除失败: $e');
    }
  }

  Future<void> _releaseDownloader() async {
    if (_downloader == null) {
      _addLog('下载器未初始化');
      return;
    }

    final vid = _vidController.text.trim();
    try {
      await _downloader!.release(vid, 0);
      setState(() {
        _downloadStatus = '已释放';
        _downloadProgress = 0;
      });
      _addLog('释放下载器: $vid');
    } catch (e) {
      _addLog('释放失败: $e');
    }
  }

  @override
  void dispose() {
    _vidController.dispose();
    _accessKeyIdController.dispose();
    _accessKeySecretController.dispose();
    _securityTokenController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'F-07 视频下载功能\n'
              '需要阿里云VOD账号和STS临时凭证',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          buildSectionTitle('视频ID'),
          TextField(
            controller: _vidController,
            decoration: const InputDecoration(
              hintText: '输入阿里云VOD视频ID',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 8),
          buildSectionTitle('Region'),
          TextField(
            controller: _regionController,
            decoration: const InputDecoration(
              hintText: 'cn-shanghai',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 8),
          buildSectionTitle('AccessKeyId'),
          TextField(
            controller: _accessKeyIdController,
            decoration: const InputDecoration(
              hintText: 'STS AccessKeyId',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 8),
          buildSectionTitle('AccessKeySecret'),
          TextField(
            controller: _accessKeySecretController,
            decoration: const InputDecoration(
              hintText: 'STS AccessKeySecret',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          buildSectionTitle('SecurityToken'),
          TextField(
            controller: _securityTokenController,
            decoration: const InputDecoration(
              hintText: 'STS SecurityToken',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          buildSectionTitle('下载控制'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _prepareDownload,
                child: const Text('准备下载'),
              ),
              ElevatedButton(
                onPressed: _startDownload,
                child: const Text('开始下载'),
              ),
              ElevatedButton(
                onPressed: _stopDownload,
                child: const Text('停止下载'),
              ),
              ElevatedButton(
                onPressed: _deleteDownload,
                child: const Text('删除下载'),
              ),
              ElevatedButton(
                onPressed: _releaseDownloader,
                child: const Text('释放下载器'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          buildSectionTitle('下载状态'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(50),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('状态: $_downloadStatus'),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _downloadProgress / 100),
                const SizedBox(height: 4),
                Text('进度: ${_downloadProgress.toStringAsFixed(1)}%'),
                if (_downloadPath.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('路径: $_downloadPath', style: const TextStyle(fontSize: 10)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          buildSectionTitle('日志'),
          Container(
            height: 200,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: const TextStyle(color: Colors.green, fontSize: 11, fontFamily: 'monospace'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
