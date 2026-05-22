import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aliplayer/flutter_aliplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
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
  FlutterAliplayer? _player;
  int _viewId = -1;
  bool _isPlaying = false;
  bool _isPrepared = false;
  bool _isSurfaceReady = false;
  Completer<void>? _surfaceReadyCompleter;
  int _duration = 0;
  int _currentPosition = 0;
  int _bufferedPosition = 0;
  double _speed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _isLoop = false;
  bool _isAutoPlay = true;
  int _scalingMode = ScaleMode.SCALE_ASPECT_FIT;
  int _rotateMode = RotateMode.ROTATE_0;
  int _mirrorMode = MirrorMode.MIRROR_MODE_NONE;
  String _videoInfo = '';
  String _eventLog = '';
  List<AVPTrackInfo> _trackList = [];
  int _selectedTrackIndex = -1;
  bool _playerCreated = false;

  final TextEditingController _urlController = TextEditingController(
    text: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
  );

  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String sdkVersion;
    try {
      sdkVersion = await _getSDKVersion();
    } on PlatformException {
      sdkVersion = 'Failed to get SDK version.';
    }
    if (!mounted) return;
    setState(() {
      _sdkVersion = sdkVersion;
    });
  }

  Future<String> _getSDKVersion() async {
    try {
      final result = await FlutterAliPlayerFactory.methodChannel.invokeMethod('getSDKVersion');
      return result?.toString() ?? '7.14.0';
    } catch (e) {
      return '7.14.0';
    }
  }

  Future<void> _createPlayer() async {
    if (_player != null) {
      await _player!.release();
    }

    _player = FlutterAliPlayerFactory.createAliPlayer(playerId: 'demo_player');
    await _player!.create();
    _setupEventListeners();
    setState(() {
      _playerCreated = true;
    });
    _addLog('播放器创建成功');
  }

  void _setupEventListeners() {
    if (_player == null) return;

    _player!.setOnPrepared((playerId) {
      _addLog('onPrepared: 准备完成');
      setState(() {
        _isPrepared = true;
      });
      _player!.getDuration().then((d) {
        _addLog('getDuration result: $d ms');
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

    _player!.setOnSurfaceReady((playerId) {
      _addLog('onSurfaceReady: 渲染表面就绪');
      setState(() {
        _isSurfaceReady = true;
      });
      if (_surfaceReadyCompleter != null && !_surfaceReadyCompleter!.isCompleted) {
        _surfaceReadyCompleter!.complete();
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
      String stateStr = _getStateString(newState);
      _addLog('onStateChanged: $stateStr ($newState)');
      setState(() {
        if (newState == PlayState.started) {
          _isPlaying = true;
        } else if (newState == PlayState.paused || newState == PlayState.stopped) {
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
      loadingBegin: (playerId) {
        _addLog('onLoadingBegin: 缓冲开始');
      },
      loadingProgress: (percent, netSpeed, playerId) {
        _addLog('缓冲进度: $percent%, 网速: $netSpeed');
      },
      loadingEnd: (playerId) {
        _addLog('onLoadingEnd: 缓冲结束');
      },
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

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    setState(() {
      _eventLog = '[$timestamp] $message\n$_eventLog';
      if (_eventLog.length > 10000) {
        _eventLog = _eventLog.substring(0, 10000);
      }
    });
  }

  Future<void> _setUrlAndPrepare() async {
    if (_player == null) {
      await _createPlayer();
    }

    if (_viewId >= 0) {
      _addLog('绑定播放器视图...');
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
      setState(() {
        _isPlaying = true;
      });
      _addLog('开始播放');
    }
  }

  Future<void> _pause() async {
    if (_player != null && _isPlaying) {
      await _player!.pause();
      setState(() {
        _isPlaying = false;
      });
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
      _addLog('seekTo: value=$value, duration=$_duration, position=$position ms');
      await _player!.seekTo(position, FlutterAvpdef.ACCURATE);
      _addLog('跳转到: ${(position / 1000).toStringAsFixed(1)}s');
    }
  }

  Future<void> _setSpeed(double speed) async {
    _addLog('尝试设置倍速: ${speed}x');
    if (_player != null) {
      try {
        await _player!.setSpeed(speed);
        setState(() {
          _speed = speed;
        });
        _addLog('设置倍速成功: ${speed}x');
      } catch (e) {
        _addLog('设置倍速失败: $e');
      }
    } else {
      _addLog('播放器未初始化，无法设置倍速');
    }
  }

  Future<void> _setVolume(double volume) async {
    if (_player != null) {
      await _player!.setVolume(volume);
      setState(() {
        _volume = volume;
      });
      _addLog('设置音量: ${volume.toStringAsFixed(2)}');
    }
  }

  Future<void> _toggleMute() async {
    if (_player != null) {
      final newMuted = !_isMuted;
      await _player!.setMuted(newMuted);
      setState(() {
        _isMuted = newMuted;
      });
      _addLog(newMuted ? '静音开启' : '静音关闭');
    }
  }

  Future<void> _toggleLoop() async {
    if (_player != null) {
      final newLoop = !_isLoop;
      await _player!.setLoop(newLoop);
      setState(() {
        _isLoop = newLoop;
      });
      _addLog(newLoop ? '循环播放开启' : '循环播放关闭');
    }
  }

  Future<void> _toggleAutoPlay() async {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
    });
    _addLog(_isAutoPlay ? '自动播放开启' : '自动播放关闭');
  }

  Future<void> _setScalingMode(int mode) async {
    if (_player != null) {
      await _player!.setScalingMode(mode);
      setState(() {
        _scalingMode = mode;
      });
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
      setState(() {
        _rotateMode = mode;
      });
      _addLog('旋转模式: ${mode}°');
    }
  }

  Future<void> _setMirrorMode(int mode) async {
    if (_player != null) {
      await _player!.setMirrorMode(mode);
      setState(() {
        _mirrorMode = mode;
      });
      final modeStr = mode == MirrorMode.MIRROR_MODE_NONE
          ? '无'
          : mode == MirrorMode.MIRROR_MODE_HORIZONTAL
              ? '水平镜像'
              : '垂直镜像';
      _addLog('镜像模式: $modeStr');
    }
  }

  Future<void> _selectTrack(int index) async {
    if (_player != null) {
      await _player!.selectTrack(index);
      setState(() {
        _selectedTrackIndex = index;
      });
      _addLog('切换到轨道: $index');
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

  Future<void> _snapshot() async {
    if (_player != null) {
      final path =
          '/data/storage/el2/base/haps/entry/files/snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _player!.snapshot(path);
      _addLog('截图保存到: $path');
    }
  }

  void _onPlatformViewCreated(int viewId) {
    setState(() {
      _viewId = viewId;
      _surfaceReadyCompleter = Completer<void>();
    });
    _addLog('PlatformView 创建成功: $viewId');

    if (_player != null) {
      _player!.setPlayerView(viewId).then((_) {
        _addLog('播放器视图绑定成功');
      }).catchError((e) {
        _addLog('绑定播放器视图失败: $e');
      });
    }
  }

  @override
void dispose() {
    _player?.release();
    _urlController.dispose();
    _logScrollController.dispose();
    super.dispose();
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
              onPressed: _showInfoDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildVideoPlayer(),
            _buildUrlInput(),
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
                          _buildLogTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      height: 220,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AliPlayerView(
            onCreated: _onPlatformViewCreated,
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
            child: _buildProgressBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
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
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
          child: Slider(
            value: durationSec > 0 ? currentSec / durationSec : 0,
            onChanged: _isPrepared ? _seekTo : null,
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

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildUrlInput() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: '输入播放地址',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    );
  }

  Widget _buildControlsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('播放控制 (F-02)'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _isPrepared ? (_isPlaying ? _pause : _play) : null,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 36,
                tooltip: _isPlaying ? '暂停' : '播放',
              ),
              IconButton(
                onPressed: _isPrepared ? _stop : null,
                icon: const Icon(Icons.stop),
                iconSize: 36,
                tooltip: '停止',
              ),
              IconButton(
                onPressed: _isPrepared ? _snapshot : null,
                icon: const Icon(Icons.camera_alt),
                iconSize: 36,
                tooltip: '截图',
              ),
              IconButton(
                onPressed: _getMediaInfo,
                icon: const Icon(Icons.info),
                iconSize: 36,
                tooltip: '媒体信息',
              ),
            ],
          ),
          _buildSectionTitle('倍速播放 (F-02)'),
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
          _buildSectionTitle('音量控制 (F-05)'),
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
            _buildSectionTitle('清晰度切换 (F-08)'),
            Wrap(
              spacing: 8,
              children: _trackList.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                return ChoiceChip(
                  label: Text(track.trackDefinition ?? 'Track $index'),
                  selected: _selectedTrackIndex == track.trackIndex,
                  onSelected: (_) => _selectTrack(track.trackIndex ?? index),
                );
              }).toList(),
            ),
          ],
          if (_videoInfo.isNotEmpty) ...[
            _buildSectionTitle('媒体信息 (F-06)'),
            Text(_videoInfo, style: const TextStyle(fontSize: 12)),
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
          _buildSectionTitle('循环/自动播放 (F-02)'),
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
                selected: _isAutoPlay,
                onSelected: (_) => _toggleAutoPlay(),
              ),
            ],
          ),
          _buildSectionTitle('缩放模式 (F-04)'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('适应'),
                selected: _scalingMode == ScaleMode.SCALE_ASPECT_FIT,
                onSelected: (_) => _setScalingMode(ScaleMode.SCALE_ASPECT_FIT),
              ),
              ChoiceChip(
                label: const Text('填充'),
                selected: _scalingMode == ScaleMode.SCALE_ASPECT_FILL,
                onSelected: (_) => _setScalingMode(ScaleMode.SCALE_ASPECT_FILL),
              ),
              ChoiceChip(
                label: const Text('拉伸'),
                selected: _scalingMode == ScaleMode.SCALE_TO_FILL,
                onSelected: (_) => _setScalingMode(ScaleMode.SCALE_TO_FILL),
              ),
            ],
          ),
          _buildSectionTitle('旋转模式 (F-04)'),
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
          _buildSectionTitle('镜像模式 (F-04)'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('无'),
                selected: _mirrorMode == MirrorMode.MIRROR_MODE_NONE,
                onSelected: (_) => _setMirrorMode(MirrorMode.MIRROR_MODE_NONE),
              ),
              ChoiceChip(
                label: const Text('水平'),
                selected: _mirrorMode == MirrorMode.MIRROR_MODE_HORIZONTAL,
                onSelected: (_) => _setMirrorMode(MirrorMode.MIRROR_MODE_HORIZONTAL),
              ),
              ChoiceChip(
                label: const Text('垂直'),
                selected: _mirrorMode == MirrorMode.MIRROR_MODE_VERTICAL,
                onSelected: (_) => _setMirrorMode(MirrorMode.MIRROR_MODE_VERTICAL),
              ),
            ],
          ),
          _buildSectionTitle('SDK 信息'),
          Text('版本: $_sdkVersion', style: const TextStyle(fontSize: 12)),
          Text('Platform: ${Platform.operatingSystem}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLogTab() {
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  void _showInfoDialog() {
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
            Text('PRD 功能覆盖:'),
            Text('• F-01 播放器创建与管理'),
            Text('• F-02 播放控制 (play/pause/stop/seek/speed/loop/autoPlay)'),
            Text('• F-03 播放源设置 (URL/STS/Auth)'),
            Text('• F-04 视频渲染 (缩放/旋转/镜像)'),
            Text('• F-05 音量控制 (音量/静音)'),
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

const int AVPTRACK_TYPE_VIDEO = 0;
const int AVPTRACK_TYPE_AUDIO = 1;
const int AVPTRACK_TYPE_SUBTITLE = 2;
