import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aliplayer/flutter_alidownloader.dart';
import 'package:flutter_aliplayer/flutter_alilistplayer.dart';
import 'package:flutter_aliplayer/flutter_aliliveshiftplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer_example/widgets/result_panel.dart';

class TestCaseRunnerPage extends StatefulWidget {
  const TestCaseRunnerPage({
    super.key,
    required this.caseId,
  });

  final String caseId;

  @override
  State<TestCaseRunnerPage> createState() => _TestCaseRunnerPageState();
}

class _TestCaseRunnerPageState extends State<TestCaseRunnerPage> {
  _TestCaseScenario? _scenario;
  String? _loadError;

  final TextEditingController _singleUrlController =
      TextEditingController(text: _DemoSamples.defaultVideoUrl);
  final TextEditingController _playlistUrlController =
      TextEditingController(text: _DemoSamples.altVideoUrl);
  final TextEditingController _playlistUidController =
      TextEditingController(text: 'playlist-custom-01');
  final TextEditingController _liveUrlController =
      TextEditingController(text: _DemoSamples.liveUrl);
  final TextEditingController _liveTimelineController =
      TextEditingController(text: _DemoSamples.liveTimelineUrl);
  final TextEditingController _videoIdController =
      TextEditingController(text: 'demo-video-id');
  final TextEditingController _regionController =
      TextEditingController(text: 'cn-shanghai');
  final TextEditingController _accessKeyIdController =
      TextEditingController(text: 'demo-access-key-id');
  final TextEditingController _accessKeySecretController =
      TextEditingController(text: 'demo-access-key-secret');
  final TextEditingController _securityTokenController =
      TextEditingController(text: 'demo-security-token');
  final TextEditingController _proxyController =
      TextEditingController(text: 'https://proxy.example.com');
  final TextEditingController _drmLicenseController =
      TextEditingController(text: 'https://license.example.com');
  final TextEditingController _drmMediaController =
      TextEditingController(text: _DemoSamples.defaultVideoUrl);
  final TextEditingController _drmAuthController =
      TextEditingController(text: 'demo-drm-token');

  FlutterAliplayer? _singlePlayer;
  FlutterAliListPlayer? _listPlayer;
  FlutterAliLiveShiftPlayer? _livePlayer;
  FlutterAliDownloader? _downloader;
  StreamSubscription<dynamic>? _downloadSubscription;
  Timer? _pollTimer;

  final List<String> _logs = <String>[];
  final List<_PlaylistEntry> _playlistEntries = <_PlaylistEntry>[];

  int? _singleViewId;
  int? _listViewId;
  int? _liveViewId;
  int? _subtitleTrackIndex;
  String _currentSubtitle = '';

  String _result = '';
  String _selectedPlaylistUid = _DemoSamples.defaultPlaylistEntries.first.uid;
  String _currentListUid = '';
  String _downloadStatus = '未开始';

  double _volume = 1.0;
  double _speed = 1.0;
  bool _muted = false;
  int _scalingMode = ScaleMode.SCALE_ASPECT_FIT;
  int _rotateMode = RotateMode.ROTATE_0;
  int _mirrorMode = MirrorMode.MIRROR_MODE_NONE;
  int _backgroundColor = 0xFF0F172A;
  int _defaultBandwidth = 1000000;
  int _defaultResolution = 720;
  bool _subtitleEnabled = false;
  int _currentPositionMs = 0;
  int _bufferedPositionMs = 0;
  int _durationMs = 0;
  int _videoWidth = 0;
  int _videoHeight = 0;
  int _videoRotation = 0;
  int _currentLiveTime = 0;
  int _currentShiftTime = 0;
  int _shiftStartTime = 0;
  int _shiftEndTime = 0;
  int _downloadProgress = 0;
  int _maxBufferDuration = 30000;
  int _highBufferDuration = 5000;
  int _startBufferDuration = 1000;
  int _networkTimeout = 15000;
  int _networkRetryCount = 2;
  Map<String, dynamic> _mediaInfo = <String, dynamic>{};
  _FilterStyle _filterStyle = _FilterStyle.none;
  bool _filterEnabled = false;
  bool _isPlaying = false;
  bool _isPrepared = false;

  bool _playSingleAfterPrepare = false;
  bool _playListAfterPrepare = false;
  bool _playLiveAfterPrepare = false;

  @override
  void initState() {
    super.initState();
    _playlistEntries.addAll(_DemoSamples.defaultPlaylistEntries);
    _loadScenario();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollPlaybackState(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _downloadSubscription?.cancel();
    unawaited(_singlePlayer?.release() ?? Future<void>.value());
    unawaited(_listPlayer?.release() ?? Future<void>.value());
    unawaited(_livePlayer?.release() ?? Future<void>.value());
    _singleUrlController.dispose();
    _playlistUrlController.dispose();
    _playlistUidController.dispose();
    _liveUrlController.dispose();
    _liveTimelineController.dispose();
    _videoIdController.dispose();
    _regionController.dispose();
    _accessKeyIdController.dispose();
    _accessKeySecretController.dispose();
    _securityTokenController.dispose();
    _proxyController.dispose();
    _drmLicenseController.dispose();
    _drmMediaController.dispose();
    _drmAuthController.dispose();
    super.dispose();
  }

  Future<void> _loadScenario() async {
    try {
      final String raw = await rootBundle.loadString('assets/test_cases.json');
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      final List<dynamic> modules = json['modules'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic module in modules) {
        final Map<String, dynamic> moduleMap =
            module as Map<String, dynamic>;
        final List<dynamic> cases =
            moduleMap['test_cases'] as List<dynamic>? ?? <dynamic>[];
        for (final dynamic item in cases) {
          final Map<String, dynamic> caseMap =
              item as Map<String, dynamic>;
          if ((caseMap['id'] as String?) == widget.caseId) {
            setState(() {
              _scenario = _TestCaseScenario.fromJson(moduleMap, caseMap);
            });
            if (widget.caseId == 'F09-001') {
              _singleUrlController.text = 'https://media.w3.org/2010/05/sintel/trailer.mp4';
            }
            _appendLog('载入测试用例 ${widget.caseId}');
            _setResult('已载入测试信息，等待执行操作。');
            return;
          }
        }
      }
      setState(() {
        _loadError = '未在测试资产中找到用例 ${widget.caseId}';
      });
    } catch (error) {
      setState(() {
        _loadError = '加载测试资产失败: $error';
      });
    }
  }

  Future<void> _pollPlaybackState() async {
    if (!mounted) {
      return;
    }

    if (_singlePlayer != null) {
      try {
        final int currentPosition =
            (await _singlePlayer!.getCurrentPosition()) as int? ?? 0;
        final int duration = await _singlePlayer!.getDuration();
        final int bufferedPosition =
            (await _singlePlayer!.getBufferedPosition()) as int? ??
                currentPosition;
        final int width =
            (await _singlePlayer!.getVideoWidth()) as int? ?? 0;
        final int height =
            (await _singlePlayer!.getVideoHeight()) as int? ?? 0;
        if (!mounted) {
          return;
        }
        setState(() {
          _currentPositionMs = currentPosition;
          _bufferedPositionMs = bufferedPosition;
          _durationMs = duration;
          _videoWidth = width;
          _videoHeight = height;
        });
      } catch (_) {
        // Ignore idle polling failures.
      }
    }

    if (_livePlayer != null) {
      try {
        final int currentLiveTime =
            (await _livePlayer!.getCurrentLiveTime()) as int? ?? 0;
        final int currentShiftTime =
            (await _livePlayer!.getCurrentTime()) as int? ?? 0;
        if (!mounted) {
          return;
        }
        setState(() {
          _currentLiveTime = currentLiveTime;
          _currentShiftTime = currentShiftTime;
        });
      } catch (_) {
        // Ignore idle polling failures.
      }
    }
  }

  Future<void> _ensureSinglePlayer() async {
    if (_singlePlayer != null) {
      return;
    }
    final FlutterAliplayer player =
        FlutterAliplayer.init('single-${widget.caseId}');
    await player.create();
    _bindSinglePlayerCallbacks(player);
    _singlePlayer = player;
    if (_singleViewId != null) {
      await player.setPlayerView(_singleViewId!);
    }
    _appendLog('单播放器已创建');
    _setResult('单播放器创建成功，可继续设置播放源和控制播放。');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureListPlayer() async {
    if (_listPlayer != null) {
      return;
    }
    final FlutterAliListPlayer player =
        FlutterAliListPlayer.init('list-${widget.caseId}');
    await player.create();
    _bindListPlayerCallbacks(player);
    _listPlayer = player;
    if (_listViewId != null) {
      await player.setPlayerView(_listViewId!);
    }
    _appendLog('列表播放器已创建');
    _setResult('列表播放器创建成功，可加载播放列表并切换资源。');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureLivePlayer() async {
    if (_livePlayer != null) {
      return;
    }
    final FlutterAliLiveShiftPlayer player =
        FlutterAliLiveShiftPlayer.init('live-${widget.caseId}');
    await player.create();
    _bindLivePlayerCallbacks(player);
    _livePlayer = player;
    if (_liveViewId != null) {
      await player.setPlayerView(_liveViewId!);
    }
    _appendLog('直播时移播放器已创建');
    _setResult('直播时移播放器创建成功，可配置直播流和时移时间线。');
    if (mounted) {
      setState(() {});
    }
  }

  void _bindSinglePlayerCallbacks(FlutterAliplayer player) {
    player.setOnPrepared((String playerId) {
      _appendLog('[$playerId] onPrepared');
      if (!mounted) {
        return;
      }
      setState(() {
        _isPrepared = true;
      });
      player.getDuration().then((dynamic d) {
        if (d != null && d is int && mounted) {
          setState(() {
            _durationMs = d;
          });
        }
      });
      if (_playSingleAfterPrepare) {
        _playSingleAfterPrepare = false;
        unawaited(_runAction(
          label: '准备完成后自动播放',
          action: () => player.play(),
          successMessage: '播放器准备完成，已开始播放。',
        ));
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      } else {
        _setResult('播放器已准备完成，可手动点击播放。');
      }
    });
    player.setOnRenderingStart((String playerId) {
      _appendLog('[$playerId] onRenderingStart');
      _setResult('视频首帧已渲染，播放器视图绑定正常。');
    });
    player.setOnVideoSizeChanged((int width, int height, int? rotation, String playerId) {
      _appendLog('[$playerId] 视频尺寸: ${width}x$height, rotation=${rotation ?? 0}');
      if (!mounted) {
        return;
      }
      setState(() {
        _videoWidth = width;
        _videoHeight = height;
        _videoRotation = rotation ?? 0;
      });
    });
    player.setOnStateChanged((int newState, String playerId) {
      _appendLog('[$playerId] 状态变化: $newState');
      if (!mounted) {
        return;
      }
      setState(() {
        if (newState == PlayState.started) {
          _isPlaying = true;
        } else if (newState == PlayState.paused ||
            newState == PlayState.stopped) {
          _isPlaying = false;
        }
      });
    });
    player.setOnInfo(
      (int? infoCode, int? extraValue, String? extraMsg, String playerId) {
        if (infoCode != null) {
          _appendLog('[$playerId] onInfo code=$infoCode value=${extraValue ?? '-'}');
        }
        if (!mounted) {
          return;
        }
        if (infoCode == InfoCode.CURRENTPOSITION) {
          setState(() {
            _currentPositionMs = extraValue ?? _currentPositionMs;
          });
        } else if (infoCode == InfoCode.BUFFEREDPOSITION) {
          setState(() {
            _bufferedPositionMs = extraValue ?? _bufferedPositionMs;
          });
        }
      },
    );
    player.setOnCompletion((String playerId) {
      _appendLog('[$playerId] onCompletion');
      _setResult('播放完成，界面与日志已同步记录结束状态。');
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
      });
    });
    player.setOnError(
      (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
        _appendLog('[$playerId] onError code=$errorCode msg=${errorMsg ?? errorExtra ?? '未知错误'}');
        _setResult('播放器报错：${errorMsg ?? errorExtra ?? '未知错误'}');
      },
    );
    player.setOnTrackReady((String playerId) {
      _appendLog('[$playerId] onTrackReady');
    });
    player.setOnSnapShot((String path, String playerId) {
      _appendLog('[$playerId] onSnapShot path=$path');
      _setResult('截图已完成，保存路径：$path');
    });
    player.setOnSubtitleExtAdded((int trackIndex, String url, String playerId) {
      _appendLog('[$playerId] 外挂字幕已添加 trackIndex=$trackIndex');
      if (!mounted) {
        return;
      }
      setState(() {
        _subtitleTrackIndex = trackIndex;
      });
      _setResult('外挂字幕已添加，可继续启用或关闭字幕。');
    });
    player.setOnSubtitleShow(
      (int trackIndex, int subtitleId, String subtitle, String playerId) {
        _appendLog('[$playerId] 字幕显示 trackIndex=$trackIndex text=$subtitle');
        if (!mounted) {
          return;
        }
        setState(() {
          _currentSubtitle = subtitle;
        });
        _setResult('字幕已显示：$subtitle');
      },
    );
    player.setOnSubtitleHide((int trackIndex, int subtitleId, String playerId) {
      _appendLog('[$playerId] 字幕隐藏 trackIndex=$trackIndex');
      if (!mounted) {
        return;
      }
      setState(() {
        _currentSubtitle = '';
      });
      _setResult('字幕已关闭。');
    });
  }

  void _bindListPlayerCallbacks(FlutterAliListPlayer player) {
    player.setOnPrepared((String playerId) {
      _appendLog('[$playerId] 列表播放器准备完成');
      if (_playListAfterPrepare) {
        _playListAfterPrepare = false;
        unawaited(_runAction(
          label: '列表准备完成后自动播放',
          action: () => player.play(),
          successMessage: '列表播放器准备完成，已开始播放。',
        ));
      } else {
        _setResult('列表资源已准备完成，可点选播放列表项开始播放。');
      }
    });
    player.setOnRenderingStart((String playerId) {
      _appendLog('[$playerId] 列表播放器开始渲染');
      _setResult('列表播放器已开始渲染当前资源。');
    });
    player.setOnStateChanged((int newState, String playerId) {
      _appendLog('[$playerId] 列表状态变化: $newState');
    });
    player.setOnCompletion((String playerId) {
      _appendLog('[$playerId] 列表播放完成');
    });
    player.setOnError(
      (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
        _appendLog('[$playerId] 列表播放错误: ${errorMsg ?? errorExtra ?? errorCode}');
        _setResult('列表播放器报错：${errorMsg ?? errorExtra ?? errorCode}');
      },
    );
    player.setOnInfo(
      (int? infoCode, int? extraValue, String? extraMsg, String playerId) {
        if (infoCode != null) {
          _appendLog('[$playerId] onInfo code=$infoCode value=${extraValue ?? '-'}');
        }
        if (!mounted) {
          return;
        }
        if (infoCode == InfoCode.CURRENTPOSITION) {
          setState(() {
            _currentPositionMs = extraValue ?? _currentPositionMs;
          });
        } else if (infoCode == InfoCode.BUFFEREDPOSITION) {
          setState(() {
            _bufferedPositionMs = extraValue ?? _bufferedPositionMs;
          });
        }
      },
    );
  }

  void _bindLivePlayerCallbacks(FlutterAliLiveShiftPlayer player) {
    player.setOnPrepared((String playerId) {
      _appendLog('[$playerId] 直播时移准备完成');
      if (_playLiveAfterPrepare) {
        _playLiveAfterPrepare = false;
        unawaited(_runAction(
          label: '直播准备完成后自动播放',
          action: () => player.play(),
          successMessage: '直播时移播放器准备完成，已开始播放。',
        ));
      } else {
        _setResult('直播时移播放器已准备完成。');
      }
    });
    player.setOnRenderingStart((String playerId) {
      _appendLog('[$playerId] 直播时移开始渲染');
      _setResult('直播时移画面已出现，可继续执行定位操作。');
    });
    player.setOnStateChanged((int newState, String playerId) {
      _appendLog('[$playerId] 直播状态变化: $newState');
    });
    player.setOnError(
      (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
        _appendLog('[$playerId] 直播播放错误: ${errorMsg ?? errorExtra ?? errorCode}');
        _setResult('直播时移播放器报错：${errorMsg ?? errorExtra ?? errorCode}');
      },
    );
    player.setOnTimeShiftUpdater(
      (int currentTime, int shiftStart, int shiftEnd, String playerId) {
        _appendLog('[$playerId] 时移更新: currentTime=$currentTime, range=$shiftStart~$shiftEnd');
        if (!mounted) {
          return;
        }
        setState(() {
          _currentShiftTime = currentTime;
          _shiftStartTime = shiftStart;
          _shiftEndTime = shiftEnd;
        });
      },
    );
    player.setOnSeekLiveCompletion((int playTime, String playerId) {
      _appendLog('[$playerId] 时移跳转完成: playTime=$playTime');
      _setResult('时移跳转已完成，当前播放时间已更新。');
    });
  }

  Future<void> _runAction({
    required String label,
    required Future<dynamic> Function() action,
    String? successMessage,
  }) async {
    try {
      final dynamic value = await action();
      final String resolved = successMessage ??
          (value == null ? '$label 执行成功。' : '$label 返回：$value');
      _appendLog('$label -> 成功');
      _setResult(resolved);
    } on PlatformException catch (error) {
      _appendLog('$label -> PlatformException ${error.code}: ${error.message}');
      _setResult('$label 失败：${error.message ?? error.code}');
    } catch (error) {
      _appendLog('$label -> 异常: $error');
      _setResult('$label 失败：$error');
    }
  }

  void _appendLog(String message) {
    final String timestamp = DateTime.now().toIso8601String().substring(11, 19);
    if (!mounted) {
      _logs.add('[$timestamp] $message');
      return;
    }
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 80) {
        _logs.removeRange(80, _logs.length);
      }
    });
  }

  void _setResult(String message) {
    if (!mounted) {
      _result = message;
      return;
    }
    setState(() {
      _result = message;
    });
  }

  Future<void> _bindSingleViewIfReady() async {
    if (_singlePlayer != null && _singleViewId != null) {
      await _singlePlayer!.setPlayerView(_singleViewId!);
      _appendLog('单播放器已绑定到渲染视图 $_singleViewId');
    }
  }

  Future<void> _bindListViewIfReady() async {
    if (_listPlayer != null && _listViewId != null) {
      await _listPlayer!.setPlayerView(_listViewId!);
      _appendLog('列表播放器已绑定到渲染视图 $_listViewId');
    }
  }

  Future<void> _bindLiveViewIfReady() async {
    if (_livePlayer != null && _liveViewId != null) {
      await _livePlayer!.setPlayerView(_liveViewId!);
      _appendLog('直播时移播放器已绑定到渲染视图 $_liveViewId');
    }
  }

  Future<void> _prepareAndPlaySingle() async {
    await _ensureSinglePlayer();
    await _runAction(
      label: '设置单播放器 URL',
      action: () => _singlePlayer!.setUrl(_singleUrlController.text.trim()),
      successMessage: '播放地址已写入单播放器，准备发起播放。',
    );
    _playSingleAfterPrepare = true;
    await _runAction(
      label: '准备单播放器',
      action: () => _singlePlayer!.prepare(),
      successMessage: '播放器正在准备，准备完成后会自动播放。',
    );
  }

  Future<void> _loadSingleSourceOnly() async {
    await _ensureSinglePlayer();
    await _runAction(
      label: '设置单播放器 URL',
      action: () => _singlePlayer!.setUrl(_singleUrlController.text.trim()),
      successMessage: '播放地址已更新，可继续 prepare / play。',
    );
  }

  Future<void> _loadLiveSourceAndPlay() async {
    await _ensureLivePlayer();
    _playLiveAfterPrepare = true;
    await _runAction(
      label: '设置直播时移数据源',
      action: () => _livePlayer!.setDataSource(
        _liveTimelineController.text.trim(),
        _liveUrlController.text.trim(),
      ),
      successMessage: '直播流与时间线地址已写入，准备开始播放。',
    );
    await _runAction(
      label: '准备直播时移播放器',
      action: () => _livePlayer!.prepare(),
      successMessage: '直播时移播放器正在准备，完成后会自动播放。',
    );
  }

  Future<void> _loadDefaultPlaylist() async {
    await _ensureListPlayer();
    await _runAction(
      label: '清空列表播放器资源',
      action: () => _listPlayer!.clear(),
      successMessage: '已清空旧播放列表，准备加载默认资源。',
    );
    for (final _PlaylistEntry entry in _DemoSamples.defaultPlaylistEntries) {
      await _listPlayer!.addUrlSource(url: entry.url, uid: entry.uid);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _playlistEntries
        ..clear()
        ..addAll(_DemoSamples.defaultPlaylistEntries);
      _selectedPlaylistUid = _playlistEntries.first.uid;
      _currentListUid = _playlistEntries.first.uid;
    });
    _appendLog('默认播放列表已载入 ${_playlistEntries.length} 条资源');
    _playListAfterPrepare = true;
    await _runAction(
      label: '设置列表播放器 URL',
      action: () => _listPlayer!.setUrl(_playlistEntries.first.url),
      successMessage: '播放地址已写入列表播放器，准备发起播放。',
    );
    await _runAction(
      label: '准备列表播放器',
      action: () => _listPlayer!.prepare(),
      successMessage: '列表播放器正在准备，准备完成后会自动播放。',
    );
  }

  Future<void> _addCustomPlaylistItem() async {
    await _ensureListPlayer();
    final _PlaylistEntry entry = _PlaylistEntry(
      uid: _playlistUidController.text.trim(),
      title: '自定义资源 ${_playlistUidController.text.trim()}',
      url: _playlistUrlController.text.trim(),
    );
    await _runAction(
      label: '添加自定义列表资源',
      action: () => _listPlayer!.addUrlSource(url: entry.url, uid: entry.uid),
      successMessage: '自定义资源已加入播放列表。',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _playlistEntries.add(entry);
      _selectedPlaylistUid = entry.uid;
    });
  }

  Future<void> _moveToPlaylistEntry(String uid) async {
    await _ensureListPlayer();
    final _PlaylistEntry entry = _playlistEntries.firstWhere(
      (e) => e.uid == uid,
      orElse: () => _playlistEntries.first,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedPlaylistUid = uid;
      _currentListUid = uid;
    });
    _playListAfterPrepare = true;
    await _runAction(
      label: '设置列表播放器 URL',
      action: () => _listPlayer!.setUrl(entry.url),
      successMessage: '播放地址已写入列表播放器，准备发起播放。',
    );
    await _runAction(
      label: '准备列表播放器',
      action: () => _listPlayer!.prepare(),
      successMessage: '列表播放器正在准备，准备完成后会自动播放。',
    );
  }

  Future<void> _applyPlayerConfig() async {
    await _ensureSinglePlayer();
    final AVPConfig config = AVPConfig()
      ..maxBufferDuration = _maxBufferDuration
      ..highBufferDuration = _highBufferDuration
      ..startBufferDuration = _startBufferDuration
      ..networkTimeout = _networkTimeout
      ..networkRetryCount = _networkRetryCount
      ..httpProxy = _proxyController.text.trim();
    await _runAction(
      label: '应用播放器配置',
      action: () => _singlePlayer!.setPlayConfig(config),
      successMessage: '播放器配置已应用: 最大缓冲${_maxBufferDuration}ms 超时${_networkTimeout}ms 重试${_networkRetryCount}次',
    );
  }

  Future<void> _fetchMediaInfo() async {
    await _ensureSinglePlayer();
    try {
      final dynamic mediaInfo = await _singlePlayer!.getMediaInfo();
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaInfo = _normalizeMap(mediaInfo);
        if (_mediaInfo.containsKey('width') && _mediaInfo.containsKey('height')) {
          final int? width = _mediaInfo['width'] as int?;
          final int? height = _mediaInfo['height'] as int?;
          if (width != null && height != null && width > 0 && height > 0) {
            _videoWidth = width;
            _videoHeight = height;
          }
        }
      });
      _appendLog('媒体信息已刷新');
      _setResult('媒体信息获取成功，已在页面下方展示详情。');
    } catch (error) {
      _appendLog('获取媒体信息失败: $error');
      _setResult('获取媒体信息失败：$error');
    }
  }

  Future<void> _addTestSubtitle() async {
    try {
      await _ensureSinglePlayer();
      final directory = Directory.systemTemp.createTempSync('subtitle_');
      final subtitleFile = File('${directory.path}/test_subtitle.srt');
      final testSubtitle = '''1
00:00:01,000 --> 00:00:05,000
测试字幕第一行
字幕功能正常工作！

2
00:00:06,000 --> 00:00:10,000
测试字幕第二行
如果看到这行，字幕显示回调已触发

3
00:00:11,000 --> 00:00:15,000
测试字幕第三条
继续播放观看更多字幕

4
00:00:16,000 --> 00:00:20,000
测试字幕第四条
字幕功能测试成功！

5
00:00:21,000 --> 00:00:30,000
测试字幕最后一条
从第21秒到第30秒
''';
      await subtitleFile.writeAsString(testSubtitle);
      final path = 'file://${subtitleFile.path}';
      setState(() {
        _subtitleTrackIndex = null;
        _currentSubtitle = '';
        _subtitleEnabled = false;
      });
      await _singlePlayer!.addExtSubtitle(path);
      _appendLog('测试字幕已添加: $path');
      _setResult('测试字幕已添加，请启用字幕并观察画面。');
    } catch (e) {
      _appendLog('添加测试字幕失败: $e');
      _setResult('添加测试字幕失败：$e');
    }
  }

  Future<void> _prepareDownload() async {
    _downloader ??= FlutterAliDownloader.init();
    await _runAction(
      label: '准备下载任务',
      action: () => _downloader!.prepare(
        FlutterAvpdef.DOWNLOADTYPE_STS,
        _videoIdController.text.trim(),
        region: _regionController.text.trim(),
        accessKeyId: _accessKeyIdController.text.trim(),
        accessKeySecret: _accessKeySecretController.text.trim(),
        securityToken: _securityTokenController.text.trim(),
      ),
      successMessage: '下载任务已提交准备，可继续启动下载并观察进度。',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _downloadStatus = '已准备';
    });
  }

  Future<void> _startDownload() async {
    _downloader ??= FlutterAliDownloader.init();
    await _downloadSubscription?.cancel();
    final Stream<dynamic>? stream =
        _downloader!.start(_videoIdController.text.trim(), 0);
    _downloadSubscription = stream?.listen((dynamic event) {
      final String summary = event.toString();
      _appendLog('下载事件: $summary');
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadStatus = summary;
        _downloadProgress = (_downloadProgress + 10).clamp(0, 100);
      });
      _setResult('下载任务已启动，请结合下载状态与进度条观察执行情况。');
    });
    _setResult('已启动下载事件监听，等待下载状态回传。');
  }

  Future<void> _saveGlobalSettings() async {
    await _runAction(
      label: '设置日志级别',
      action: () => FlutterAliPlayerFactory.methodChannel.invokeMethod<void>(
        'setLogLevel',
        <String, dynamic>{'level': _DemoGlobalSettingsStore.logLevel},
      ),
      successMessage: '日志级别已下发到 OHOS 侧。其余全局设置会作为 Demo 状态保留。',
    );
    await _runAction(
      label: '设置控制台日志开关',
      action: () => FlutterAliPlayerFactory.methodChannel.invokeMethod<void>(
        'enableConsoleLog',
        <String, dynamic>{'enable': _DemoGlobalSettingsStore.consoleLogEnabled},
      ),
      successMessage: '控制台日志开关已同步，页面状态已保存。',
    );
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{'value': value};
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.caseId)),
        body: Center(child: Text(_loadError!)),
      );
    }

    if (_scenario == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.caseId)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final _TestCaseScenario scenario = _scenario!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${scenario.id} ${scenario.title}'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildInfoCard(scenario),
                  const SizedBox(height: 12),
                  _buildCapabilityCard(scenario),
                  const SizedBox(height: 12),
                  _buildScenarioActions(scenario),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ResultPanel(
              result: _result,
              emptyHint: '等待操作…',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(_TestCaseScenario scenario) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${scenario.moduleCode} ${scenario.moduleName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildKeyValueRow('优先级', scenario.priority),
            _buildKeyValueRow('级别', scenario.level),
            _buildKeyValueRow('前置条件', scenario.preconditions),
            _buildKeyValueRow('预期结果', scenario.expectedResult),
            if (scenario.postconditions.isNotEmpty)
              _buildKeyValueRow('后置条件', scenario.postconditions),
            const SizedBox(height: 8),
            const Text(
              '测试步骤',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            for (int index = 0; index < scenario.steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${index + 1}. ${scenario.steps[index].action}\n验证点：${scenario.steps[index].checkpoint}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityCard(_TestCaseScenario scenario) {
    String summary = '当前 Demo 优先对齐已完成的 OHOS 适配能力。'
        ' 对于平台明确不支持或尚未开放的高级能力，页面会给出清晰降级提示。';
    if (scenario.moduleCode == 'F-12') {
      summary = '悬浮窗能力在 OHOS 侧不支持，页面会展示明确的不可用提示，'
          '并保证主播放链路不受影响。';
    } else if (scenario.moduleCode == 'F-11') {
      summary = '画中画链路当前未在 OHOS 适配层暴露，Demo 保留测试入口与状态说明。';
    } else if (scenario.moduleCode == 'F-17') {
      summary = '滤镜特效使用 Demo 预览叠层呈现视觉变化，便于测试人员验证交互和结果面板输出。';
    } else if (scenario.moduleCode == 'F-18') {
      summary = 'DRM 回调链路尚未在当前 OHOS 适配中完成，页面将保存输入并输出待对接提示。';
    }
    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(summary),
      ),
    );
  }

  Widget _buildScenarioActions(_TestCaseScenario scenario) {
    switch (scenario.id) {
      case 'F01-001':
      case 'F02-001':
      case 'F02-002':
      case 'F02-003':
      case 'F03-001':
      case 'F04-001':
      case 'F04-002':
      case 'F05-001':
      case 'F06-001':
      case 'F07-001':
      case 'F07-002':
      case 'F08-001':
      case 'F08-002':
      case 'F09-001':
      case 'F10-001':
      case 'F16-001':
      case 'F17-001':
      case 'F18-001':
        return _buildSinglePlayerScenario(scenario);
      case 'F01-002':
      case 'F03-002':
      case 'F14-001':
        return _buildListPlayerScenario(scenario);
      case 'F01-003':
      case 'F02-004':
      case 'F03-003':
        return _buildLivePlayerScenario();
      case 'F11-001':
        return _buildPictureInPictureScenario();
      case 'F12-001':
        return _buildFloatWindowScenario();
      case 'F13-001':
        return _buildDownloadScenario();
      case 'F15-001':
        return _buildGlobalSettingsScenario();
      default:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('未定义的场景：${scenario.id}'),
          ),
        );
    }
  }

  Widget _buildSinglePlayerScenario(_TestCaseScenario scenario) {
    final bool showSettings = <String>{
      'F04-001',
      'F04-002',
      'F08-001',
      'F08-002',
      'F16-001',
    }.contains(scenario.id);
    final bool showVolume = scenario.id == 'F05-001';
    final bool showMediaInfo = scenario.id == 'F06-001';
    final bool showLogs = <String>{'F07-001', 'F07-002', 'F10-001'}.contains(
      scenario.id,
    );
    final bool showSnapshot = scenario.id == 'F10-001';
    final bool showSubtitles = scenario.id == 'F09-001';
    final bool showFilter = scenario.id == 'F17-001';
    final bool showDrm = scenario.id == 'F18-001';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionCard(
          title: '播放器视图',
          children: <Widget>[
            _buildSurfacePreview(
              viewId: _singleViewId,
              onCreated: (int viewId) async {
                setState(() {
                  _singleViewId = viewId;
                });
                await _bindSingleViewIfReady();
              },
              overlay: showFilter && _filterEnabled
                  ? _buildFilterOverlay()
                  : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _singleUrlController,
              label: '播放地址',
              keyName: 'input_single_url',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildActionButton(
                  keyName: 'btn_create_single_player',
                  label: '创建单播放器',
                  onPressed: _ensureSinglePlayer,
                ),
                _buildActionButton(
                  keyName: 'btn_bind_single_view',
                  label: '绑定渲染视图',
                  onPressed: _bindSingleViewIfReady,
                ),
                _buildActionButton(
                  keyName: 'btn_set_single_url',
                  label: '设置播放地址',
                  onPressed: _loadSingleSourceOnly,
                ),
                _buildActionButton(
                  keyName: 'btn_play_single',
                  label: '播放',
                  onPressed: _prepareAndPlaySingle,
                ),
                _buildActionButton(
                  keyName: 'btn_pause_single',
                  label: _isPlaying ? '暂停' : '恢复',
                  onPressed: () => _runAction(
                    label: _isPlaying ? '暂停单播放器' : '恢复单播放器',
                    action: () async {
                      await _ensureSinglePlayer();
                      if (_isPlaying) {
                        await _singlePlayer!.pause();
                      } else {
                        await _singlePlayer!.play();
                      }
                    },
                    successMessage: _isPlaying ? '单播放器已暂停。' : '单播放器已恢复播放。',
                  ),
                ),
                _buildActionButton(
                  keyName: 'btn_stop_single',
                  label: '停止',
                  onPressed: () => _runAction(
                    label: '停止单播放器',
                    action: () async {
                      await _ensureSinglePlayer();
                      await _singlePlayer!.stop();
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _isPlaying = false;
                        _isPrepared = false;
                        _currentPositionMs = 0;
                      });
                    },
                    successMessage: '单播放器已停止。',
                  ),
                ),
                _buildActionButton(
                  keyName: 'btn_release_single',
                  label: '销毁释放',
                  onPressed: () => _runAction(
                    label: '释放单播放器',
                    action: () async {
                      await _singlePlayer?.release();
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _singlePlayer = null;
                        _isPlaying = false;
                        _isPrepared = false;
                        _currentPositionMs = 0;
                        _bufferedPositionMs = 0;
                        _durationMs = 0;
                      });
                    },
                    successMessage: '单播放器已释放，页面状态已重置。',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPlaybackStatusCard(),
          ],
        ),
        if (scenario.id == 'F02-002')
          _buildSectionCard(
            title: '进度跳转',
            children: <Widget>[
              Slider(
                key: const Key('slider_seek_position'),
                value: _durationMs > 0
                    ? _currentPositionMs.clamp(0, _durationMs).toDouble()
                    : 0,
                max: _durationMs > 0 ? _durationMs.toDouble() : 1,
                onChanged: _isPrepared && _durationMs > 0
                    ? (double value) {
                        setState(() {
                          _currentPositionMs = value.round();
                        });
                      }
                    : null,
                onChangeEnd: (double value) => _runAction(
                  label: '跳转播放进度',
                  action: () async {
                    await _ensureSinglePlayer();
                    return _singlePlayer!.seekTo(
                      value.round(),
                      SeekMode.ACCURATE,
                    );
                  },
                  successMessage:
                    '已请求跳转到 ${_formatDuration(value.round())}，请继续观察播放位置变化。',
                ),
              ),
            ],
          ),
        if (scenario.id == 'F02-003')
          _buildSectionCard(
            title: '倍速切换',
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: <double>[0.75, 1.0, 1.5, 2.0]
                    .map(
                      (double option) => ChoiceChip(
                        key: Key(
                          'chip_speed_${option.toString().replaceAll('.', '_')}',
                        ),
                        label: Text('${option.toStringAsFixed(1)}x'),
                        selected: _speed == option,
                        onSelected: (_) async {
                          setState(() {
                            _speed = option;
                          });
                          await _runAction(
                            label: '设置播放倍速',
                            action: () async {
                              await _ensureSinglePlayer();
                              return _singlePlayer!.setSpeed(option);
                            },
                            successMessage:
                                '倍速已切换到 ${option.toStringAsFixed(1)}x。',
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        if (showSettings) _buildRenderSettingsSection(scenario),
        if (showVolume) _buildVolumeSection(),
        if (showMediaInfo) _buildMediaInfoSection(),
        if (showSnapshot) _buildSnapshotSection(),
        if (showLogs) _buildLogsSection(),
        if (showSubtitles) _buildSubtitleSection(),
        if (showFilter) _buildFilterSection(),
        if (showDrm) _buildDrmSection(),
      ],
    );
  }

  Widget _buildListPlayerScenario(_TestCaseScenario scenario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionCard(
          title: '列表播放器视图',
          children: <Widget>[
            _buildSurfacePreview(
              viewId: _listViewId,
              onCreated: (int viewId) async {
                setState(() {
                  _listViewId = viewId;
                });
                await _bindListViewIfReady();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildActionButton(
                  keyName: 'btn_create_list_player',
                  label: '创建列表播放器',
                  onPressed: _ensureListPlayer,
                ),
                _buildActionButton(
                  keyName: 'btn_load_default_list',
                  label: '加载默认列表',
                  onPressed: _loadDefaultPlaylist,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _playlistUrlController,
              label: '视频URL地址',
              keyName: 'input_playlist_url',
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _playlistUidController,
              label: '资源UID',
              keyName: 'input_playlist_uid',
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              keyName: 'btn_add_playlist_item',
              label: '添加到列表',
              onPressed: _addCustomPlaylistItem,
            ),
            const SizedBox(height: 12),
            _buildPlaylistCard(),
          ],
        ),
        if (scenario.id == 'F14-001')
          _buildSectionCard(
            title: '预加载设置',
            children: <Widget>[
              const Text(
                '当前 Demo 版本明确标记预加载链路为能力展示项，不影响播放列表正常使用。',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: const Key('dropdown_preload_count'),
                initialValue: 1,
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(value: 1, child: Text('1')),
                  DropdownMenuItem<int>(value: 2, child: Text('2')),
                  DropdownMenuItem<int>(value: 3, child: Text('3')),
                ],
                onChanged: null,
                decoration: const InputDecoration(
                  labelText: '预加载个数',
                  helperText: '当前平台演示中保持禁用状态',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLivePlayerScenario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionCard(
          title: '直播时移播放器',
          children: <Widget>[
            _buildSurfacePreview(
              viewId: _liveViewId,
              onCreated: (int viewId) async {
                setState(() {
                  _liveViewId = viewId;
                });
                await _bindLiveViewIfReady();
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _liveUrlController,
              label: '直播流地址',
              keyName: 'input_live_url',
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _liveTimelineController,
              label: '时移时间线地址',
              keyName: 'input_live_timeline_url',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildActionButton(
                  keyName: 'btn_create_live_player',
                  label: '创建时移播放器',
                  onPressed: _ensureLivePlayer,
                ),
                _buildActionButton(
                  keyName: 'btn_set_live_source',
                  label: '设置并播放',
                  onPressed: _loadLiveSourceAndPlay,
                ),
                _buildActionButton(
                  keyName: 'btn_seek_live_start',
                  label: '跳到起始',
                  onPressed: () async {
                    if (_shiftStartTime <= 0) {
                      _appendLog('无可用的时移范围，无法跳转。');
                      _appendLog('提示：阿里云直播时移服务需要配置有效的时移时间线地址才能获取时移范围。');
                      _setResult('由于阿里云直播时移服务不支持或未配置有效的时移时间线，该功能无法实现。');
                      return;
                    }
                    await _runAction(
                      label: '跳到时移起始点',
                      action: () async {
                        await _ensureLivePlayer();
                        return _livePlayer!.seekToLiveTime(_shiftStartTime);
                      },
                      successMessage: '已请求跳到时移起始点 ($_shiftStartTime)，请观察播放时间变化。',
                    );
                  },
                ),
                _buildActionButton(
                  keyName: 'btn_seek_live_middle',
                  label: '跳到中间',
                  onPressed: () async {
                    if (_shiftStartTime <= 0 || _shiftEndTime <= 0) {
                      _appendLog('无可用的时移范围，无法跳转。');
                      _appendLog('提示：阿里云直播时移服务需要配置有效的时移时间线地址才能获取时移范围。');
                      _setResult('由于阿里云直播时移服务不支持或未配置有效的时移时间线，该功能无法实现。');
                      return;
                    }
                    final int targetTime = _shiftStartTime + ((_shiftEndTime - _shiftStartTime) ~/ 2);
                    await _runAction(
                      label: '跳到时移中间点',
                      action: () async {
                        await _ensureLivePlayer();
                        return _livePlayer!.seekToLiveTime(targetTime);
                      },
                      successMessage: '已请求跳到时移中间点 ($targetTime)，请继续观察播放位置变化。',
                    );
                  },
                ),
                _buildActionButton(
                  keyName: 'btn_release_live_player',
                  label: '销毁释放',
                  onPressed: () => _runAction(
                    label: '释放直播时移播放器',
                    action: () async {
                      await _livePlayer?.release();
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _livePlayer = null;
                        _currentLiveTime = 0;
                        _currentShiftTime = 0;
                        _shiftStartTime = 0;
                        _shiftEndTime = 0;
                      });
                    },
                    successMessage: '直播时移播放器已释放，页面恢复初始状态。',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildKeyValueRow(
              '当前直播时间',
              _currentLiveTime == 0 ? '未获取' : _currentLiveTime.toString(),
            ),
            _buildKeyValueRow(
              '当前时移播放时间',
              _currentShiftTime == 0 ? '未获取' : _currentShiftTime.toString(),
            ),
            _buildKeyValueRow(
              '时移起始',
              _shiftStartTime == 0 ? '未获取' : _formatTimestamp(_shiftStartTime),
            ),
            _buildKeyValueRow(
              '时移结束',
              _shiftEndTime == 0 ? '未获取' : _formatTimestamp(_shiftEndTime),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(int ms) {
    if (ms <= 0) return '--';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _buildPictureInPictureScenario() {
    return _buildSectionCard(
      title: '画中画演示',
      children: <Widget>[
        const Text('当前 OHOS 适配层尚未开放画中画启动接口，本页面保留测试入口与结果提示。'),
        const SizedBox(height: 8),
        _buildActionButton(
          keyName: 'btn_enter_picture_in_picture',
          label: '进入画中画',
          onPressed: () {
            _appendLog('尝试进入画中画：当前实现未开放 OHOS 入口');
            _setResult('当前 OHOS 适配暂未开放画中画接口，请在后续能力补齐后联调验证。');
          },
        ),
      ],
    );
  }

  Widget _buildFloatWindowScenario() {
    return _buildSectionCard(
      title: '悬浮窗播放',
      children: <Widget>[
        const Text('悬浮窗仅 Android 支持。OHOS Demo 会明确提示不支持，并保持普通播放链路可继续使用。'),
        const SizedBox(height: 8),
        _buildActionButton(
          keyName: 'btn_show_float_window',
          label: '悬浮窗播放',
          onPressed: () async {
            final bool noPermissionNeeded =
                await FlutterAliPlayerFactory.checkFloatViewPermission();
            _appendLog('悬浮窗检查结果: $noPermissionNeeded');
            FlutterAliPlayerFactory.showFloatViewForAndroid(_singleViewId ?? 0);
            _setResult('当前平台不支持悬浮窗播放，已保留普通播放链路。');
          },
        ),
      ],
    );
  }

  Widget _buildDownloadScenario() {
    return _buildSectionCard(
      title: '视频下载',
      children: <Widget>[
        _buildTextField(
          controller: _videoIdController,
          label: '视频ID',
          keyName: 'input_download_vid',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _regionController,
          label: 'Region',
          keyName: 'input_download_region',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _accessKeyIdController,
          label: 'AccessKeyId',
          keyName: 'input_download_access_key_id',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _accessKeySecretController,
          label: 'AccessKeySecret',
          keyName: 'input_download_access_key_secret',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _securityTokenController,
          label: 'SecurityToken',
          keyName: 'input_download_security_token',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildActionButton(
              keyName: 'btn_prepare_download',
              label: '准备下载',
              onPressed: _prepareDownload,
            ),
            _buildActionButton(
              keyName: 'btn_start_download',
              label: '开始下载',
              onPressed: _startDownload,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _downloadProgress == 0 ? null : _downloadProgress / 100,
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        _buildKeyValueRow('下载状态', _downloadStatus),
      ],
    );
  }

  Widget _buildGlobalSettingsScenario() {
    return _buildSectionCard(
      title: '全局设置',
      children: <Widget>[
        DropdownButtonFormField<int>(
          key: const Key('dropdown_global_log_level'),
          initialValue: _DemoGlobalSettingsStore.logLevel,
          decoration: const InputDecoration(
            labelText: '日志级别',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 0, child: Text('Verbose')),
            DropdownMenuItem<int>(value: 1, child: Text('Debug')),
            DropdownMenuItem<int>(value: 2, child: Text('Info')),
            DropdownMenuItem<int>(value: 3, child: Text('Warn')),
          ],
          onChanged: (int? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _DemoGlobalSettingsStore.logLevel = value;
            });
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('switch_global_local_cache'),
          contentPadding: EdgeInsets.zero,
          title: const Text('本地缓存'),
          value: _DemoGlobalSettingsStore.localCacheEnabled,
          onChanged: (bool value) {
            setState(() {
              _DemoGlobalSettingsStore.localCacheEnabled = value;
            });
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('input_global_network_retry_count'),
          initialValue:
              _DemoGlobalSettingsStore.networkReconnectCount.toString(),
          decoration: const InputDecoration(
            labelText: '网络重连次数',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (String value) {
            _DemoGlobalSettingsStore.networkReconnectCount =
                int.tryParse(value) ??
                    _DemoGlobalSettingsStore.networkReconnectCount;
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('switch_console_log'),
          contentPadding: EdgeInsets.zero,
          title: const Text('控制台日志'),
          value: _DemoGlobalSettingsStore.consoleLogEnabled,
          onChanged: (bool value) {
            setState(() {
              _DemoGlobalSettingsStore.consoleLogEnabled = value;
            });
          },
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          keyName: 'btn_save_global_settings',
          label: '保存全局设置',
          onPressed: _saveGlobalSettings,
        ),
      ],
    );
  }

  Widget _buildRenderSettingsSection(_TestCaseScenario scenario) {
    return _buildSectionCard(
      title: '渲染与播放设置',
      children: <Widget>[
        const Text('缩放模式'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <MapEntry<String, int>>[
            const MapEntry<String, int>('适应', ScaleMode.SCALE_ASPECT_FIT),
            const MapEntry<String, int>('填充', ScaleMode.SCALE_TO_FILL),
            const MapEntry<String, int>('裁剪', ScaleMode.SCALE_ASPECT_FILL),
          ]
              .map(
                (MapEntry<String, int> entry) => ChoiceChip(
                  key: Key('chip_scale_${entry.value}'),
                  label: Text(entry.key),
                  selected: _scalingMode == entry.value,
                  onSelected: (_) async {
                    setState(() {
                      _scalingMode = entry.value;
                    });
                    await _runAction(
                      label: '设置缩放模式',
                      action: () async {
                        await _ensureSinglePlayer();
                        return _singlePlayer!.setScalingMode(entry.value);
                      },
                      successMessage: '缩放模式已切换为 ${entry.key}。',
                    );
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('旋转模式'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <MapEntry<String, int>>[
            const MapEntry<String, int>('0°', RotateMode.ROTATE_0),
            const MapEntry<String, int>('90°', RotateMode.ROTATE_90),
            const MapEntry<String, int>('180°', RotateMode.ROTATE_180),
          ]
              .map(
                (MapEntry<String, int> entry) => ChoiceChip(
                  key: Key('chip_rotate_${entry.value}'),
                  label: Text(entry.key),
                  selected: _rotateMode == entry.value,
                  onSelected: (_) async {
                    setState(() {
                      _rotateMode = entry.value;
                    });
                    await _runAction(
                      label: '设置旋转模式',
                      action: () async {
                        await _ensureSinglePlayer();
                        return _singlePlayer!.setRotateMode(entry.value);
                      },
                      successMessage: '旋转模式已切换为 ${entry.key}。',
                    );
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('镜像模式'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <MapEntry<String, int>>[
            const MapEntry<String, int>('无', MirrorMode.MIRROR_MODE_NONE),
            const MapEntry<String, int>(
              '水平',
              MirrorMode.MIRROR_MODE_HORIZONTAL,
            ),
            const MapEntry<String, int>(
              '垂直',
              MirrorMode.MIRROR_MODE_VERTICAL,
            ),
          ]
              .map(
                (MapEntry<String, int> entry) => ChoiceChip(
                  key: Key('chip_mirror_${entry.value}'),
                  label: Text(entry.key),
                  selected: _mirrorMode == entry.value,
                  onSelected: (_) async {
                    setState(() {
                      _mirrorMode = entry.value;
                    });
                    await _runAction(
                      label: '设置镜像模式',
                      action: () async {
                        await _ensureSinglePlayer();
                        return _singlePlayer!.setMirrorMode(entry.value);
                      },
                      successMessage: '镜像模式已切换为 ${entry.key}。',
                    );
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('背景色'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <MapEntry<String, int>>[
            const MapEntry<String, int>('蓝色', 0xFF2563EB),
            const MapEntry<String, int>('深灰', 0xFF0F172A),
            const MapEntry<String, int>('墨绿', 0xFF14532D),
          ]
              .map(
                (MapEntry<String, int> entry) => ChoiceChip(
                  key: Key('chip_background_${entry.value}'),
                  label: Text(entry.key),
                  selected: _backgroundColor == entry.value,
                  onSelected: (_) async {
                    setState(() {
                      _backgroundColor = entry.value;
                    });
                    await _runAction(
                      label: '设置背景色',
                      action: () async {
                        await _ensureSinglePlayer();
                        return _singlePlayer!
                            .setVideoBackgroundColor(entry.value);
                      },
                      successMessage: '背景色已切换为 ${entry.key}。',
                    );
                  },
                ),
              )
              .toList(),
        ),
        if (scenario.id == 'F08-001' || scenario.id == 'F08-002') ...<Widget>[
          const SizedBox(height: 12),
          const Text('默认带宽'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <MapEntry<String, int>>[
              const MapEntry<String, int>('512Kbps', 512000),
              const MapEntry<String, int>('1Mbps', 1000000),
              const MapEntry<String, int>('2Mbps', 2000000),
            ]
                .map(
                  (MapEntry<String, int> entry) => ChoiceChip(
                    key: Key('chip_bandwidth_${entry.value}'),
                    label: Text(entry.key),
                    selected: _defaultBandwidth == entry.value,
                    onSelected: (_) async {
                      setState(() {
                        _defaultBandwidth = entry.value;
                      });
                      await _runAction(
                        label: '设置默认带宽',
                        action: () async {
                          await _ensureSinglePlayer();
                          return _singlePlayer!.setDefaultBandWidth(
                            entry.value,
                          );
                        },
                        successMessage: '默认带宽已切换为 ${entry.key}。',
                      );
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text('默认分辨率'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <MapEntry<String, int>>[
              const MapEntry<String, int>('480P', 480),
              const MapEntry<String, int>('720P', 720),
              const MapEntry<String, int>('1080P', 1080),
            ]
                .map(
                  (MapEntry<String, int> entry) => ChoiceChip(
                    key: Key('chip_resolution_${entry.value}'),
                    label: Text(entry.key),
                    selected: _defaultResolution == entry.value,
                    onSelected: (_) async {
                      setState(() {
                        _defaultResolution = entry.value;
                      });
                      await _runAction(
                        label: '设置默认分辨率',
                        action: () async {
                          await _ensureSinglePlayer();
                          return _singlePlayer!.setDefaultResolution(
                            entry.value,
                          );
                        },
                        successMessage: '默认分辨率已切换为 ${entry.key}。',
                      );
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            keyName: 'btn_select_auto_track',
            label: '自动',
            onPressed: () => _runAction(
              label: '切换到自动码率',
              action: () async {
                await _ensureSinglePlayer();
                return _singlePlayer!.selectTrack(-1);
              },
              successMessage: '已请求切换为自动码率模式。',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <int>[0, 1, 2]
                .map(
                  (int track) => _buildActionButton(
                    keyName: 'btn_select_track_$track',
                    label: '清晰度轨道 $track',
                    onPressed: () => _runAction(
                      label: '切换清晰度轨道',
                      action: () async {
                        await _ensureSinglePlayer();
                        return _singlePlayer!.selectTrack(track);
                      },
                      successMessage: '已请求切换到轨道 $track。',
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (scenario.id == 'F16-001') ...<Widget>[
          const SizedBox(height: 12),
          Text('最大缓冲: ${(_maxBufferDuration / 1000).toStringAsFixed(0)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            key: const Key('slider_max_buffer'),
            value: _maxBufferDuration.toDouble(),
            min: 5000,
            max: 120000,
            divisions: 23,
            label: '${(_maxBufferDuration / 1000).toStringAsFixed(0)}秒',
            onChanged: (double value) {
              setState(() {
                _maxBufferDuration = value.toInt();
              });
            },
          ),
          Text('高水位缓冲: ${(_highBufferDuration / 1000).toStringAsFixed(0)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            key: const Key('slider_high_buffer'),
            value: _highBufferDuration.toDouble(),
            min: 1000,
            max: 30000,
            divisions: 29,
            label: '${(_highBufferDuration / 1000).toStringAsFixed(0)}秒',
            onChanged: (double value) {
              setState(() {
                _highBufferDuration = value.toInt();
              });
            },
          ),
          Text('起播缓冲: ${(_startBufferDuration / 1000).toStringAsFixed(1)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            key: const Key('slider_start_buffer'),
            value: _startBufferDuration.toDouble(),
            min: 100,
            max: 5000,
            divisions: 49,
            label: '${(_startBufferDuration / 1000).toStringAsFixed(1)}秒',
            onChanged: (double value) {
              setState(() {
                _startBufferDuration = value.toInt();
              });
            },
          ),
          Text('网络超时: ${(_networkTimeout / 1000).toStringAsFixed(0)}秒',
              style: const TextStyle(fontSize: 12)),
          Slider(
            key: const Key('slider_network_timeout'),
            value: _networkTimeout.toDouble(),
            min: 5000,
            max: 60000,
            divisions: 11,
            label: '${(_networkTimeout / 1000).toStringAsFixed(0)}秒',
            onChanged: (double value) {
              setState(() {
                _networkTimeout = value.toInt();
              });
            },
          ),
          Text('重试次数: $_networkRetryCount 次',
              style: const TextStyle(fontSize: 12)),
          Slider(
            key: const Key('slider_retry_count'),
            value: _networkRetryCount.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            label: '$_networkRetryCount 次',
            onChanged: (double value) {
              setState(() {
                _networkRetryCount = value.toInt();
              });
            },
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _proxyController,
            label: 'HTTP代理',
            keyName: 'input_http_proxy',
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            keyName: 'btn_apply_player_config',
            label: '应用配置',
            onPressed: _applyPlayerConfig,
          ),
        ],
      ],
    );
  }

  Widget _buildVolumeSection() {
    return _buildSectionCard(
      title: '音量控制',
      children: <Widget>[
        Slider(
          key: const Key('slider_volume'),
          value: _volume,
          min: 0,
          max: 2,
          divisions: 20,
          label: _volume.toStringAsFixed(2),
          onChanged: (double value) {
            setState(() {
              _volume = value;
            });
          },
          onChangeEnd: (double value) => _runAction(
            label: '设置音量',
            action: () async {
              await _ensureSinglePlayer();
              return _singlePlayer!.setVolume(value);
            },
            successMessage: '音量已切换到 ${value.toStringAsFixed(2)}。',
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(child: Text('当前音量: ${_volume.toStringAsFixed(2)}')),
            IconButton(
              key: const Key('btn_toggle_mute'),
              onPressed: () async {
                final bool next = !_muted;
                setState(() {
                  _muted = next;
                });
                await _runAction(
                  label: '切换静音',
                  action: () async {
                    await _ensureSinglePlayer();
                    return _singlePlayer!.setMuted(next);
                  },
                  successMessage: next ? '播放器已静音。' : '播放器已恢复有声。',
                );
              },
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaInfoSection() {
    return _buildSectionCard(
      title: '媒体信息',
      children: <Widget>[
        _buildActionButton(
          keyName: 'btn_fetch_media_info',
          label: '信息',
          onPressed: _fetchMediaInfo,
        ),
        const SizedBox(height: 8),
        _buildKeyValueRow(
          '视频尺寸',
          _videoWidth == 0 ? '未知' : '${_videoWidth} x $_videoHeight',
        ),
        _buildKeyValueRow(
          '旋转角度',
          '${_videoRotation}°',
        ),
        _buildKeyValueRow('时长', _formatDuration(_durationMs)),
        _buildKeyValueRow('当前位置', _formatDuration(_currentPositionMs)),
        _buildKeyValueRow('缓冲位置', _formatDuration(_bufferedPositionMs)),
        if (_mediaInfo.isNotEmpty) ...<Widget>[
          const Divider(height: 24),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(_mediaInfo),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildLogsSection() {
    return _buildSectionCard(
      title: '日志',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('已记录 ${_logs.length} 条日志'),
            ),
            TextButton(
              key: const Key('btn_clear_logs'),
              onPressed: () {
                setState(() {
                  _logs.clear();
                });
                _setResult('日志已清空。');
              },
              child: const Text('清空日志'),
            ),
          ],
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            _logs.isEmpty ? '暂无日志输出。' : _logs.join('\n\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotSection() {
    return _buildSectionCard(
      title: '截图功能',
      children: <Widget>[
        if (!_isPrepared)
          const Text(
            '请先点击【播放】按钮开始播放视频，然后才能截图。',
            style: TextStyle(color: Colors.orange),
          ),
        _buildActionButton(
          keyName: 'btn_snapshot',
          label: '截图',
          onPressed: _isPrepared ? _snapshot : null,
        ),
      ],
    );
  }

  Future<void> _snapshot() async {
    try {
      await _ensureSinglePlayer();
      await _singlePlayer!.snapshot('');
      _appendLog('截图请求已发出，等待回调返回保存路径...');
    } catch (e) {
      _appendLog('截图失败: $e');
      _setResult('截图失败：$e');
    }
  }

  Widget _buildSubtitleSection() {
    return _buildSectionCard(
      title: '字幕支持',
      children: <Widget>[
        if (!_isPrepared)
          const Text(
            '请先点击【播放】按钮开始播放视频，然后才能添加字幕。',
            style: TextStyle(color: Colors.orange),
          ),
        Wrap(
          spacing: 8,
          children: [
            _buildActionButton(
              keyName: 'btn_add_test_subtitle',
              label: '添加测试字幕',
              onPressed: _isPrepared ? _addTestSubtitle : null,
            ),
            _buildActionButton(
              keyName: 'btn_add_subtitle',
              label: '在线Sintel字幕',
              onPressed: _isPrepared
                  ? () => _runAction(
                        label: '添加外挂字幕',
                        action: () async {
                          await _ensureSinglePlayer();
                          setState(() {
                            _subtitleTrackIndex = null;
                            _currentSubtitle = '';
                            _subtitleEnabled = false;
                          });
                          return _singlePlayer!.addExtSubtitle(_DemoSamples.subtitleUrl);
                        },
                        successMessage: '字幕添加请求已发出，请观察字幕添加回调。',
                      )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            _buildActionButton(
              keyName: 'btn_enable_subtitle',
              label: '启用字幕',
              onPressed: _subtitleTrackIndex == null
                  ? null
                  : () async {
                      setState(() {
                        _subtitleEnabled = true;
                      });
                      await _runAction(
                        label: '启用外挂字幕',
                        action: () async {
                          await _ensureSinglePlayer();
                          return _singlePlayer!.selectExtSubtitle(
                            _subtitleTrackIndex!,
                            true,
                          );
                        },
                        successMessage: '已启用外挂字幕，请观察画面与日志变化。',
                      );
                    },
            ),
            _buildActionButton(
              keyName: 'btn_disable_subtitle',
              label: '禁用字幕',
              onPressed: _subtitleTrackIndex == null
                  ? null
                  : () async {
                      setState(() {
                        _subtitleEnabled = false;
                      });
                      await _runAction(
                        label: '关闭外挂字幕',
                        action: () async {
                          await _ensureSinglePlayer();
                          return _singlePlayer!.selectExtSubtitle(
                            _subtitleTrackIndex!,
                            false,
                          );
                        },
                        successMessage: '已关闭外挂字幕。',
                      );
                    },
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildKeyValueRow('字幕轨道', _subtitleTrackIndex?.toString() ?? '尚未回调'),
        _buildKeyValueRow('字幕状态', _subtitleEnabled ? '已启用' : '未启用'),
        if (_currentSubtitle.isNotEmpty) ...<Widget>[
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
      ],
    );
  }

  Widget _buildFilterSection() {
    return _buildSectionCard(
      title: '滤镜特效',
      children: <Widget>[
        SwitchListTile(
          key: const Key('switch_filter_enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('启用滤镜'),
          value: _filterEnabled,
          onChanged: (bool value) {
            setState(() {
              _filterEnabled = value;
            });
            _setResult(value ? '滤镜已启用，请继续选择样式观察画面叠层变化。' : '滤镜已关闭。');
          },
        ),
        DropdownButtonFormField<_FilterStyle>(
          key: const Key('dropdown_filter_style'),
          initialValue: _filterStyle,
          decoration: const InputDecoration(
            labelText: '滤镜样式',
            border: OutlineInputBorder(),
          ),
          items: _FilterStyle.values
              .map(
                (_FilterStyle style) => DropdownMenuItem<_FilterStyle>(
                  value: style,
                  child: Text(style.label),
                ),
              )
              .toList(),
          onChanged: (_FilterStyle? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _filterStyle = value;
            });
            _setResult('滤镜样式已切换为 ${value.label}，请观察视频区域叠层效果。');
          },
        ),
      ],
    );
  }

  Widget _buildDrmSection() {
    return _buildSectionCard(
      title: 'DRM 支持',
      children: <Widget>[
        _buildTextField(
          controller: _drmLicenseController,
          label: 'DRM 许可证地址',
          keyName: 'input_drm_license_url',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _drmMediaController,
          label: '媒体地址',
          keyName: 'input_drm_media_url',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _drmAuthController,
          label: '鉴权信息',
          keyName: 'input_drm_auth',
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          keyName: 'btn_apply_drm',
          label: '应用DRM并播放',
          onPressed: () {
            _appendLog('DRM 入口已点击，当前 OHOS Demo 仅保留输入与提示。');
            _setResult(
              '当前 OHOS 适配尚未完成 DRM 回调链路，已记录许可证地址、媒体地址和鉴权信息，待后续能力接入后联调。',
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaybackStatusCard() {
    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildKeyValueRow('当前位置', _formatDuration(_currentPositionMs)),
            _buildKeyValueRow('缓冲位置', _formatDuration(_bufferedPositionMs)),
            _buildKeyValueRow('视频时长', _formatDuration(_durationMs)),
            _buildKeyValueRow(
              '视频尺寸',
              _videoWidth == 0 ? '未知' : '${_videoWidth} x $_videoHeight',
            ),
            if (_currentListUid.isNotEmpty)
              _buildKeyValueRow('当前列表资源', _currentListUid),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _playlistEntries
            .map(
              (_PlaylistEntry entry) => ListTile(
                key: Key('item_playlist_${entry.uid}'),
                title: Text(entry.title),
                subtitle: Text(entry.uid),
                trailing: _selectedPlaylistUid == entry.uid
                    ? const Icon(Icons.play_arrow)
                    : null,
                onTap: () => _moveToPlaylistEntry(entry.uid),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSurfacePreview({
    required int? viewId,
    required ValueChanged<int> onCreated,
    Widget? overlay,
  }) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Color(_backgroundColor),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AliPlayerView(
            onCreated: onCreated,
            x: 0,
            y: 0,
            width: 320,
            height: 180,
          ),
          if (overlay != null) overlay,
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'viewId: ${viewId ?? '-'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOverlay() {
    final Color color = switch (_filterStyle) {
      _FilterStyle.none => Colors.transparent,
      _FilterStyle.cinema => const Color(0x6625120D),
      _FilterStyle.cool => const Color(0x661E3A8A),
      _FilterStyle.warm => const Color(0x66B45309),
    };
    return IgnorePointer(
      child: ColoredBox(color: color),
    );
  }

  Widget _buildActionButton({
    required String keyName,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      key: Key(keyName),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String keyName,
  }) {
    return TextField(
      key: Key(keyName),
      controller: controller,
      minLines: 1,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: '$key：',
          style: const TextStyle(fontWeight: FontWeight.w600),
          children: <InlineSpan>[
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int value) {
    final Duration duration = Duration(milliseconds: value);
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:'
        '${twoDigits(duration.inSeconds.remainder(60))}';
  }
}

class _TestCaseScenario {
  _TestCaseScenario({
    required this.id,
    required this.title,
    required this.level,
    required this.priority,
    required this.moduleCode,
    required this.moduleName,
    required this.preconditions,
    required this.expectedResult,
    required this.postconditions,
    required this.steps,
  });

  factory _TestCaseScenario.fromJson(
    Map<String, dynamic> moduleJson,
    Map<String, dynamic> caseJson,
  ) {
    final List<dynamic> rawSteps =
        caseJson['test_steps'] as List<dynamic>? ?? <dynamic>[];
    return _TestCaseScenario(
      id: caseJson['id'] as String? ?? '',
      title: caseJson['title'] as String? ?? '',
      level: caseJson['level'] as String? ?? '',
      priority: moduleJson['priority'] as String? ?? '',
      moduleCode: moduleJson['moduleCode'] as String? ?? '',
      moduleName: moduleJson['moduleName'] as String? ?? '',
      preconditions: caseJson['preconditions'] as String? ?? '',
      expectedResult: caseJson['expected_result'] as String? ?? '',
      postconditions: caseJson['postconditions'] as String? ?? '',
      steps: rawSteps
          .map(
            (dynamic item) =>
                _TestStep.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String id;
  final String title;
  final String level;
  final String priority;
  final String moduleCode;
  final String moduleName;
  final String preconditions;
  final String expectedResult;
  final String postconditions;
  final List<_TestStep> steps;
}

class _TestStep {
  _TestStep({
    required this.action,
    required this.checkpoint,
  });

  factory _TestStep.fromJson(Map<String, dynamic> json) {
    return _TestStep(
      action: json['action'] as String? ?? '',
      checkpoint: json['checkpoint'] as String? ?? '',
    );
  }

  final String action;
  final String checkpoint;
}

class _PlaylistEntry {
  const _PlaylistEntry({
    required this.uid,
    required this.title,
    required this.url,
  });

  final String uid;
  final String title;
  final String url;
}

class _DemoGlobalSettingsStore {
  static int logLevel = 2;
  static bool localCacheEnabled = false;
  static bool consoleLogEnabled = true;
  static int networkReconnectCount = 2;
}

enum _FilterStyle {
  none('无'),
  cinema('Cinema'),
  cool('Cool'),
  warm('Warm');

  const _FilterStyle(this.label);

  final String label;
}

class _DemoSamples {
  static const String defaultVideoUrl =
      'https://media.w3.org/2010/05/sintel/trailer.mp4';
  static const String altVideoUrl =
      'https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4';
  static const String liveUrl =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static const String liveTimelineUrl =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static const String subtitleUrl =
      'https://durian.blender.org/wp-content/content/subtitles/sintel_en.srt';

  static const List<_PlaylistEntry> defaultPlaylistEntries = <_PlaylistEntry>[
    _PlaylistEntry(
      uid: 'playlist-001',
      title: '默认资源 1',
      url: defaultVideoUrl,
    ),
    _PlaylistEntry(
      uid: 'playlist-002',
      title: '默认资源 2',
      url: altVideoUrl,
    ),
  ];
}
