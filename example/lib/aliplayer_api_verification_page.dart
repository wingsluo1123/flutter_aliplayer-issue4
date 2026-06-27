import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aliplayer/flutter_alidownloader.dart';
import 'package:flutter_aliplayer/flutter_aliliveshiftplayer.dart';
import 'package:flutter_aliplayer/flutter_alilistplayer.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_factory.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_global_setting.dart';
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader.dart'
    as loader_v1;
import 'package:flutter_aliplayer/flutter_aliplayer_medialoader_v2.dart'
    as loader_v2;

class AliplayerApiVerificationApp extends StatelessWidget {
  const AliplayerApiVerificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AliplayerApiVerificationPage(),
    );
  }
}

class AliplayerApiVerificationPage extends StatefulWidget {
  const AliplayerApiVerificationPage({super.key});

  @override
  State<AliplayerApiVerificationPage> createState() =>
      _AliplayerApiVerificationPageState();
}

class _AliplayerApiVerificationPageState
    extends State<AliplayerApiVerificationPage> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  );
  final TextEditingController _vidController = TextEditingController(
    text: 'replace_with_real_vid',
  );
  final TextEditingController _playAuthController = TextEditingController(
    text: 'replace_with_play_auth',
  );
  final TextEditingController _accessKeyIdController = TextEditingController(
    text: 'replace_with_ak',
  );
  final TextEditingController _accessKeySecretController =
      TextEditingController(text: 'replace_with_sk');
  final TextEditingController _securityTokenController = TextEditingController(
    text: 'replace_with_token',
  );
  final TextEditingController _regionController = TextEditingController(
    text: 'cn-shanghai',
  );
  final TextEditingController _downloadDirController = TextEditingController(
    text: '/data/storage/el2/base/files',
  );

  final List<String> _logs = <String>[];
  FlutterAliplayer? _player;
  FlutterAliListPlayer? _listPlayer;
  FlutterAliLiveShiftPlayer? _liveShiftPlayer;
  FlutterAliDownloader? _downloader;
  String? _lastPreloadTaskId;
  int? _viewId;

  @override
  void dispose() {
    _urlController.dispose();
    _vidController.dispose();
    _playAuthController.dispose();
    _accessKeyIdController.dispose();
    _accessKeySecretController.dispose();
    _securityTokenController.dispose();
    _regionController.dispose();
    _downloadDirController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final String time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '$time $message');
      if (_logs.length > 300) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _run(String label, FutureOr<Object?> Function() action) async {
    try {
      final Object? result = await action();
      _log('$label -> ${result ?? 'ok'}');
    } catch (error) {
      if (_isVerifyPlayerMissing(error)) {
        try {
          _log('$label detected missing native player; recreating verify_player');
          await _createPlayer();
          final Object? result = await action();
          _log('$label -> ${result ?? 'ok'}');
          return;
        } catch (retryError) {
          _log('$label failed after recreate: $retryError');
          return;
        }
      }
      _log('$label failed: $error');
    }
  }

  bool _isVerifyPlayerMissing(Object error) {
    return error is PlatformException &&
        error.message?.contains('Player not found: verify_player') == true;
  }

  Future<void> _copyLogsToClipboard() async {
    final String text = _logs.isEmpty ? '暂无日志' : _logs.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('调用日志已复制')));
  }

  FlutterAliplayer? get _readyPlayer {
    final FlutterAliplayer? player = _player;
    if (player == null) {
      _log('请先点击“创建普通播放器”');
    }
    return player;
  }

  FlutterAliListPlayer? get _readyListPlayer {
    final FlutterAliListPlayer? player = _listPlayer;
    if (player == null) {
      _log('请先点击“创建列表播放器”');
    }
    return player;
  }

  FlutterAliDownloader get _readyDownloader {
    _downloader ??= FlutterAliDownloader.init();
    return _downloader!;
  }

  Future<void> _createPlayer() async {
    final FlutterAliplayer player = FlutterAliplayer.init('verify_player');
    await player.create();
    _player = player;
    _registerPlayerCallbacks(player);
    if (_viewId != null) {
      await player.setPlayerView(_viewId!);
    }
    _log('普通播放器已创建');
  }

  Future<void> _createListPlayer() async {
    _listPlayer = FlutterAliListPlayer.init('verify_list_player');
    await _listPlayer!.create();
    _registerPlayerCallbacks(_listPlayer!);
    if (_viewId != null) {
      await _listPlayer!.setPlayerView(_viewId!);
    }
    _log('列表播放器已创建');
  }

  Future<void> _createLiveShiftPlayer() async {
    _liveShiftPlayer = FlutterAliLiveShiftPlayer.init(
      'verify_live_shift_player',
    );
    await _liveShiftPlayer!.create();
    _registerPlayerCallbacks(_liveShiftPlayer!);
    _log('直播时移播放器已创建，实际播放需要可用时移源');
  }

  void _registerPlayerCallbacks(FlutterAliplayer player) {
    player.setOnPrepared(
      (String playerId) => _log('event onPrepared $playerId'),
    );
    player.setOnRenderingStart(
      (String playerId) => _log('event onRenderingStart $playerId'),
    );
    player.setOnVideoSizeChanged((
      int width,
      int height,
      int? rotation,
      String playerId,
    ) {
      _log('event onVideoSizeChanged ${width}x$height rotation=$rotation');
    });
    player.setOnSnapShot(
      (String path, String playerId) => _log('event onSnapShot $path'),
    );
    player.setOnSeekComplete(
      (String playerId) => _log('event onSeekComplete $playerId'),
    );
    player.setOnError((
      int code,
      String? extra,
      String? message,
      String playerId,
    ) {
      _log('event onError code=$code extra=$extra message=$message');
    });
    player.setOnLoadingStatusListener(
      loadingBegin: (String playerId) => _log('event onLoadingBegin $playerId'),
      loadingProgress: (int percent, double? speed, String playerId) {
        _log('event onLoadingProgress percent=$percent speed=$speed');
      },
      loadingEnd: (String playerId) => _log('event onLoadingEnd $playerId'),
    );
    player.setOnStateChanged(
      (int state, String playerId) => _log('event onStateChanged state=$state'),
    );
    player.setOnInfo((int? code, int? value, String? message, String playerId) {
      _log('event onInfo code=$code value=$value message=$message');
    });
    player.setOnCompletion(
      (String playerId) => _log('event onCompletion $playerId'),
    );
    player.setOnTrackReady(
      (String playerId) => _log('event onTrackReady $playerId'),
    );
    player.setOnSubTrackReady(
      (String playerId) => _log('event onSubTrackReady $playerId'),
    );
    player.setOnTrackChanged(
      (dynamic value, String playerId) => _log('event onTrackChanged $value'),
    );
    player.setOnVideoRendered((int? timeMs, int? pts, String playerId) {
      _log('event onVideoRendered time=$timeMs pts=$pts');
    });
    player.setOnSubtitleExtAdded((int trackIndex, String url, String playerId) {
      _log('event onSubtitleExtAdded index=$trackIndex url=$url');
    });
    player.setOnSubtitleShow((
      int trackIndex,
      int subtitleID,
      String subtitle,
      String playerId,
    ) {
      _log('event onSubtitleShow index=$trackIndex id=$subtitleID');
    });
    player.setOnSubtitleHide((int trackIndex, int subtitleID, String playerId) {
      _log('event onSubtitleHide index=$trackIndex id=$subtitleID');
    });
    player.setOnSubtitleHeader((
      int trackIndex,
      String header,
      String playerId,
    ) {
      _log('event onSubtitleHeader index=$trackIndex');
    });
  }

  Future<void> _quickPlay() async {
    if (_player == null) {
      await _createPlayer();
    }
    final FlutterAliplayer player = _player!;
    await player.setUrl(_urlController.text.trim());
    await player.prepare();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await player.play();
  }

  Future<void> _runSafeSmoke() async {
    await _createPlayer();
    await _run('getSDKVersion', FlutterAliplayer.getSDKVersion);
    await _run('getDeviceUUID', FlutterAliplayer.getDeviceUUID);
    await _run(
      'enableConsoleLog',
      () => FlutterAliplayer.enableConsoleLog(true),
    );
    await _run('setLogLevel', () => FlutterAliplayer.setLogLevel(16));
    await _run('getLogLevel', FlutterAliplayer.getLogLevel);
    await _run('setUseHttp2', () => FlutterAliplayer.setUseHttp2(true));
    await _run('enableHttpDns', () => FlutterAliplayer.enableHttpDns(false));
    await _run(
      'createVidPlayerConfigGenerator',
      FlutterAliplayer.createVidPlayerConfigGenerator,
    );
    await _run('setPreviewTime', () => FlutterAliplayer.setPreviewTime(30));
    await _run(
      'setHlsUriToken',
      () => FlutterAliplayer.setHlsUriToken('demo_token'),
    );
    await _run('addVidPlayerConfigByStringValue', () {
      return FlutterAliplayer.addVidPlayerConfigByStringValue(
        'Definition',
        'AUTO',
      );
    });
    await _run('addVidPlayerConfigByIntValue', () {
      return FlutterAliplayer.addVidPlayerConfigByIntValue('PreviewTime', 30);
    });
    await _run(
      'setEncryptType',
      () => FlutterAliplayer.setEncryptType(EncryptType.Unencrypted),
    );
    await _run('generatePlayerConfig', FlutterAliplayer.generatePlayerConfig);
    await _run('setUrl', () => _player!.setUrl(_urlController.text.trim()));
    await _run('setLoop', () => _player!.setLoop(false));
    await _run('setAutoPlay', () => _player!.setAutoPlay(false));
    await _run('setMuted', () => _player!.setMuted(false));
    await _run('setVolume', () => _player!.setVolume(0.6));
    await _run('setSpeed', () => _player!.setSpeed(1.0));
    await _run('getPlayerName', _player!.getPlayerName);
    await _run('getUserData', _player!.getUserData);
    _log('安全烟测完成；真实播放、VID、下载需要可用资源和凭证');
  }

  AVPConfig _demoConfig() {
    return AVPConfig()
      ..networkTimeout = 15000
      ..networkRetryCount = 1
      ..startBufferDuration = 500
      ..highBufferDuration = 1000
      ..maxBufferDuration = 5000
      ..mMaxAllowedAbrVideoPixelNumber = PixelNumber.Resolution_720P;
  }

  Map<String, dynamic> get _vidStsArgs => <String, dynamic>{
    'vid': _vidController.text.trim(),
    'region': _regionController.text.trim(),
    'accessKeyId': _accessKeyIdController.text.trim(),
    'accessKeySecret': _accessKeySecretController.text.trim(),
    'securityToken': _securityTokenController.text.trim(),
  };

  Widget _textField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _button(String label, FutureOr<Object?> Function() action) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: () => _run(label, action),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: title == '准备' || title == '核心播放',
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 8, runSpacing: 8, children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return SafeArea(
      top: false,
      child: Container(
        height: 260,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  '调用日志',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _copyLogsToClipboard,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制全部日志'),
                ),
              ],
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _logs.isEmpty ? '暂无日志' : _logs.join('\n'),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_aliplayer OHOS API 验证台')),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 190,
            child: ColoredBox(
              color: Colors.black,
              child: AliPlayerView(
                x: 0,
                y: 0,
                width: MediaQuery.of(context).size.width,
                height: 190,
                onCreated: (int id) {
                  _viewId = id;
                  _log('PlatformView created id=$id');
                  _player?.setPlayerView(id);
                  _listPlayer?.setPlayerView(id);
                },
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: <Widget>[
                _section('准备', <Widget>[
                  SizedBox(
                    width: 420,
                    child: _textField('可公网访问的视频 URL', _urlController),
                  ),
                  SizedBox(
                    width: 180,
                    child: _textField('VID', _vidController),
                  ),
                  SizedBox(
                    width: 220,
                    child: _textField('PlayAuth', _playAuthController),
                  ),
                  SizedBox(
                    width: 180,
                    child: _textField('Region', _regionController),
                  ),
                  SizedBox(
                    width: 180,
                    child: _textField('AccessKeyId', _accessKeyIdController),
                  ),
                  SizedBox(
                    width: 180,
                    child: _textField(
                      'AccessKeySecret',
                      _accessKeySecretController,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _textField(
                      'SecurityToken',
                      _securityTokenController,
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: _textField('下载保存目录', _downloadDirController),
                  ),
                  _button('创建普通播放器', () => _createPlayer()),
                  _button('创建列表播放器', () => _createListPlayer()),
                  _button('创建直播时移播放器', () => _createLiveShiftPlayer()),
                  _button('安全烟测', () => _runSafeSmoke()),
                  _button('清空日志', () {
                    setState(() => _logs.clear());
                    return null;
                  }),
                ]),
                _section('核心播放', <Widget>[
                  _button(
                    'setPlayerView',
                    () => _readyPlayer?.setPlayerView(_viewId ?? 0),
                  ),
                  _button(
                    'setUrl',
                    () => _readyPlayer?.setUrl(_urlController.text.trim()),
                  ),
                  _button('prepare', () => _readyPlayer?.prepare()),
                  _button('play', () => _readyPlayer?.play()),
                  _button('pause', () => _readyPlayer?.pause()),
                  _button('stop', () => _readyPlayer?.stop()),
                  _button('reload', () => _readyPlayer?.reload()),
                  _button('quick setUrl+prepare+play', () => _quickPlay()),
                  _button('seekTo 10s', () => _readyPlayer?.seekTo(10000, 1)),
                  _button(
                    'setStartTime 5s',
                    () => _readyPlayer?.setStartTime(5000, 1),
                  ),
                  _button('clearScreen', () => _readyPlayer?.clearScreen()),
                  _button(
                    'snapshot',
                    () => _readyPlayer?.snapshot(
                      '/data/storage/el2/base/files/snapshot.jpg',
                    ),
                  ),
                  _button('release', () async {
                    await _readyPlayer?.release();
                    _player = null;
                  }),
                  _button('releaseAsync', () async {
                    await _readyPlayer?.releaseAsync();
                    _player = null;
                  }),
                ]),
                _section('播放配置与查询', <Widget>[
                  _button('setLoop true', () => _readyPlayer?.setLoop(true)),
                  _button('isLoop', () => _readyPlayer?.isLoop()),
                  _button(
                    'setAutoPlay false',
                    () => _readyPlayer?.setAutoPlay(false),
                  ),
                  _button('isAutoPlay', () => _readyPlayer?.isAutoPlay()),
                  _button(
                    'setFastStart true',
                    () => _readyPlayer?.setFastStart(true),
                  ),
                  _button(
                    'setMuted false',
                    () => _readyPlayer?.setMuted(false),
                  ),
                  _button('isMuted', () => _readyPlayer?.isMuted()),
                  _button('setVolume 0.6', () => _readyPlayer?.setVolume(0.6)),
                  _button('getVolume', () => _readyPlayer?.getVolume()),
                  _button('setSpeed 1.25', () => _readyPlayer?.setSpeed(1.25)),
                  _button('getSpeed', () => _readyPlayer?.getSpeed()),
                  _button(
                    'setEnableHardwareDecoder true',
                    () => _readyPlayer?.setEnableHardwareDecoder(true),
                  ),
                  _button(
                    'enableHardwareDecoder',
                    () => _readyPlayer?.enableHardwareDecoder(),
                  ),
                  _button('setRenderFrameCallbackConfig', () {
                    return _readyPlayer?.setRenderFrameCallbackConfig(
                      true,
                      true,
                    );
                  }),
                  _button(
                    'setConfig',
                    () => _readyPlayer?.setConfig(_demoConfig().convertToMap()),
                  ),
                  _button('getConfig', () => _readyPlayer?.getConfig()),
                  _button(
                    'setPlayConfig',
                    () => _readyPlayer?.setPlayConfig(_demoConfig()),
                  ),
                  _button('getPlayConfig', () => _readyPlayer?.getPlayConfig()),
                  _button(
                    'enableDowngrade',
                    () =>
                        _readyPlayer?.enableDowngrade('default', _demoConfig()),
                  ),
                ]),
                _section('显示与媒体信息', <Widget>[
                  _button(
                    'setRotateMode 0',
                    () => _readyPlayer?.setRotateMode(0),
                  ),
                  _button('getRotateMode', () => _readyPlayer?.getRotateMode()),
                  _button(
                    'setScalingMode 0',
                    () => _readyPlayer?.setScalingMode(0),
                  ),
                  _button(
                    'getScalingMode',
                    () => _readyPlayer?.getScalingMode(),
                  ),
                  _button(
                    'setMirrorMode 0',
                    () => _readyPlayer?.setMirrorMode(
                      MirrorMode.MIRROR_MODE_NONE,
                    ),
                  ),
                  _button('getMirrorMode', () => _readyPlayer?.getMirrorMode()),
                  _button(
                    'setAlphaRenderMode 0',
                    () => _readyPlayer?.setAlphaRenderMode(0),
                  ),
                  _button(
                    'getAlphaRenderMode',
                    () => _readyPlayer?.getAlphaRenderMode(),
                  ),
                  _button(
                    'setVideoBackgroundColor',
                    () => _readyPlayer?.setVideoBackgroundColor(0xFF000000),
                  ),
                  _button('getVideoWidth', () => _readyPlayer?.getVideoWidth()),
                  _button(
                    'getVideoHeight',
                    () => _readyPlayer?.getVideoHeight(),
                  ),
                  _button(
                    'getVideoRotation',
                    () => _readyPlayer?.getVideoRotation(),
                  ),
                  _button('getDuration', () => _readyPlayer?.getDuration()),
                  _button(
                    'getCurrentPosition',
                    () => _readyPlayer?.getCurrentPosition(),
                  ),
                  _button(
                    'getCurrentUtcTime',
                    () => _readyPlayer?.getCurrentUtcTime(),
                  ),
                  _button(
                    'getPlayedDuration',
                    () => _readyPlayer?.getPlayedDuration(),
                  ),
                  _button(
                    'getBufferedPosition',
                    () => _readyPlayer?.getBufferedPosition(),
                  ),
                  _button(
                    'getCurrentDownloadSpeed',
                    () => _readyPlayer?.getCurrentDownloadSpeed(),
                  ),
                  _button('getMediaInfo', () => _readyPlayer?.getMediaInfo()),
                  _button(
                    'getSubMediaInfo',
                    () => _readyPlayer?.getSubMediaInfo(),
                  ),
                  _button(
                    'getCurrentTrack video',
                    () => _readyPlayer?.currentTrack(TrackType.TYPE_VIDEO),
                  ),
                ]),
                _section('视频源和凭证场景', <Widget>[
                  _button('setVidAuth 需真实PlayAuth', () {
                    return _readyPlayer?.setVidAuth(
                      vid: _vidController.text,
                      playAuth: _playAuthController.text,
                    );
                  }),
                  _button('setVidSts 需STS', () {
                    return _readyPlayer?.setVidSts(
                      vid: _vidStsArgs['vid'],
                      region: _vidStsArgs['region'],
                      accessKeyId: _vidStsArgs['accessKeyId'],
                      accessKeySecret: _vidStsArgs['accessKeySecret'],
                      securityToken: _vidStsArgs['securityToken'],
                    );
                  }),
                  _button('setVidMps 需MPS参数', () {
                    return _readyPlayer?.setVidMps(<String, dynamic>{
                      'vid': _vidController.text,
                      'quality': 'AUTO',
                    });
                  }),
                  _button('setLiveSts 需直播STS', () {
                    return _readyPlayer?.setLiveSts(
                      url: _urlController.text,
                      accessKeyId: _accessKeyIdController.text,
                      accessKeySecret: _accessKeySecretController.text,
                      securityToken: _securityTokenController.text,
                    );
                  }),
                  _button('updateLiveStsInfo 需直播STS', () {
                    return _readyPlayer?.updateLiveStsInfo(
                      _accessKeyIdController.text,
                      _accessKeySecretController.text,
                      _securityTokenController.text,
                      _regionController.text,
                    );
                  }),
                  _button(
                    'switchStream',
                    () =>
                        _readyPlayer?.switchStream(_urlController.text.trim()),
                  ),
                ]),
                _section('Track 字幕 缩略图 滤镜', <Widget>[
                  _button(
                    'setDefaultBandWidth',
                    () => _readyPlayer?.setDefaultBandWidth(500000),
                  ),
                  _button('setDefaultResolution 720p', () {
                    return _readyPlayer?.setDefaultResolution(
                      PixelNumber.Resolution_720P,
                    );
                  }),
                  _button(
                    'setDefaultAudioLanguage',
                    () => _readyPlayer?.setDefaultAudioLanguage('zh-CN'),
                  ),
                  _button(
                    'setPlayerScene LIVE',
                    () => _readyPlayer?.setPlayerScene(PlayerScene.LIVE),
                  ),
                  _button(
                    'selectTrack auto',
                    () => _readyPlayer?.selectTrack(-1),
                  ),
                  _button(
                    'addExtSubtitle',
                    () => _readyPlayer?.addExtSubtitle(
                      'https://example.com/subtitle.vtt',
                    ),
                  ),
                  _button(
                    'selectExtSubtitle',
                    () => _readyPlayer?.selectExtSubtitle(0, true),
                  ),
                  _button('createThumbnailHelper', () {
                    return _readyPlayer?.createThumbnailHelper(
                      'https://example.com/thumb.vtt',
                    );
                  }),
                  _button(
                    'requestBitmapAtPosition',
                    () => _readyPlayer?.requestBitmapAtPosition(1000),
                  ),
                  _button(
                    'setFilterConfig',
                    () => _readyPlayer?.setFilterConfig('[{"target":"sr"}]'),
                  ),
                  _button(
                    'updateFilterConfig',
                    () => _readyPlayer?.updateFilterConfig(
                      'sr',
                      <String, dynamic>{'enable': true},
                    ),
                  ),
                  _button(
                    'setFilterInvalid',
                    () => _readyPlayer?.setFilterInvalid('sr', 'false'),
                  ),
                ]),
                _section('回调与自定义通道', <Widget>[
                  _button('setOnStreamSwitchedListener', () {
                    return _readyPlayer?.setOnStreamSwitchedListener(
                      (String url) => _log('stream switch success $url'),
                      (String url, int code, String message) =>
                          _log('stream switch fail $url $code $message'),
                    );
                  }),
                  _button('setConvertURLCallback', () {
                    return _readyPlayer?.setConvertURLCallback((
                      String url,
                      String format,
                    ) {
                      _log('convertURL url=$url format=$format');
                      return url;
                    });
                  }),
                  _button('setOnPreRenderFrameCallback', () {
                    return _readyPlayer?.setOnPreRenderFrameCallback(
                      (Object frameInfo) => true,
                    );
                  }),
                  _button('setOnRenderFrameCallback', () {
                    return _readyPlayer?.setOnRenderFrameCallback(
                      (Object frameInfo) => true,
                    );
                  }),
                  _button('setDrmCallback', () {
                    return _readyPlayer?.setDrmCallback(
                      (Object a, Object b) => '',
                      (Object a, Object b) => '',
                    );
                  }),
                  _button(
                    'setTraceID',
                    () => _readyPlayer?.setTraceID('verify-trace-id'),
                  ),
                  _button(
                    'setPreferPlayerName',
                    () => _readyPlayer?.setPreferPlayerName('AliPlayer'),
                  ),
                  _button('getPlayerName', () => _readyPlayer?.getPlayerName()),
                  _button(
                    'sendCustomEvent',
                    () => _readyPlayer?.sendCustomEvent('source=verification'),
                  ),
                  _button(
                    'setUserData',
                    () => _readyPlayer?.setUserData('verification-user-data'),
                  ),
                  _button('getUserData', () => _readyPlayer?.getUserData()),
                  _button(
                    'setStreamDelayTime',
                    () => _readyPlayer?.setStreamDelayTime(0, 0),
                  ),
                  _button(
                    'getOption render_fps',
                    () => _readyPlayer?.getOption(AVPOption.render_fps),
                  ),
                  _button('getPropertyString response_info', () {
                    return _readyPlayer?.getPropertyString(
                      AVPPropertyKey.response_info,
                    );
                  }),
                  _button(
                    'setOutputAudioChannel',
                    () => _readyPlayer?.setOutputAudioChannel(0),
                  ),
                ]),
                _section('静态与全局设置', <Widget>[
                  _button(
                    'initService 空数据',
                    () => FlutterAliPlayerFactory.initService(Uint8List(0)),
                  ),
                  _button('getSDKVersion', FlutterAliplayer.getSDKVersion),
                  _button('getDeviceUUID', FlutterAliplayer.getDeviceUUID),
                  _button('isFeatureSupport dolby', () {
                    return FlutterAliplayer.isFeatureSupport(
                      SupportFeatureType.dolbyAudio,
                    );
                  }),
                  _button(
                    'enableConsoleLog',
                    () => FlutterAliplayer.enableConsoleLog(true),
                  ),
                  _button(
                    'setLogLevel',
                    () => FlutterAliplayer.setLogLevel(16),
                  ),
                  _button('setLogInfoCallBack', () {
                    return FlutterAliplayer.setLogInfoCallBack((
                      int level,
                      String log,
                    ) {
                      _log('log callback level=$level $log');
                    });
                  }),
                  _button(
                    'setLogOption',
                    () => FlutterAliplayer.setLogOption(1),
                  ),
                  _button('getLogLevel', FlutterAliplayer.getLogLevel),
                  _button(
                    'setUseHttp2',
                    () => FlutterAliplayer.setUseHttp2(true),
                  ),
                  _button(
                    'enableHttpDns',
                    () => FlutterAliplayer.enableHttpDns(false),
                  ),
                  _button(
                    'setDNSResolve',
                    () => FlutterAliplayer.setDNSResolve(
                      'player.alicdn.com:443',
                      '127.0.0.1',
                    ),
                  ),
                  _button(
                    'setIpResolveType v4',
                    () =>
                        FlutterAliplayer.setIpResolveType(AVPIpResolveType.v4),
                  ),
                  _button(
                    'enableNetworkBalance',
                    () => FlutterAliplayer.enableNetworkBalance(true),
                  ),
                  _button('enableLocalCache', () {
                    return FlutterAliplayer.enableLocalCache(
                      true,
                      '204800',
                      _downloadDirController.text,
                      DocTypeForIOS.caches,
                    );
                  }),
                  _button('setCacheFileClearConfig', () {
                    return FlutterAliplayer.setCacheFileClearConfig(
                      '1440',
                      '1024',
                      '100',
                    );
                  }),
                  _button('clearCaches', FlutterAliplayer.clearCaches),
                  _button(
                    'Global setGlobalEnvironment',
                    () =>
                        FlutterAliPlayerGlobalSettings.setGlobalEnvironment(0),
                  ),
                  _button(
                    'Global setOption',
                    () => FlutterAliPlayerGlobalSettings.setOption(0, 'demo'),
                  ),
                  _button(
                    'Global disableCrashUpload',
                    () =>
                        FlutterAliPlayerGlobalSettings.disableCrashUpload(true),
                  ),
                  _button(
                    'Global enableEnhancedHttpDns',
                    () => FlutterAliPlayerGlobalSettings.enableEnhancedHttpDns(
                      false,
                    ),
                  ),
                  _button('Global setCacheUrlHashCallback', () {
                    return FlutterAliPlayerGlobalSettings.setCacheUrlHashCallback(
                      (String url) => url.hashCode.toString(),
                    );
                  }),
                  _button('Global setNetworkCallback', () {
                    return FlutterAliPlayerGlobalSettings.setNetworkCallback((
                      Object requestUrl,
                      Object inData,
                      Object inOutSize,
                      Object outData,
                    ) {
                      return false;
                    });
                  }),
                  _button('Global setBackupURLCallback', () {
                    return FlutterAliPlayerGlobalSettings.setAdaptiveDecoderGetBackupURLCallback(
                      (Object bizType, Object codecType, Object url) {
                        return url.toString();
                      },
                    );
                  }),
                  _button(
                    'Global setBrightness',
                    () =>
                        FlutterAliPlayerGlobalSettings.setSystemBrightness(0.5),
                  ),
                  _button(
                    'Global getBrightness',
                    FlutterAliPlayerGlobalSettings.getSystemBrightness,
                  ),
                ]),
                _section('VidPlayerConfig 生成', <Widget>[
                  _button(
                    'createVidPlayerConfigGenerator',
                    FlutterAliplayer.createVidPlayerConfigGenerator,
                  ),
                  _button(
                    'setPreviewTime',
                    () => FlutterAliplayer.setPreviewTime(30),
                  ),
                  _button(
                    'setHlsUriToken',
                    () => FlutterAliplayer.setHlsUriToken('verify-token'),
                  ),
                  _button(
                    'addConfigString',
                    () => FlutterAliplayer.addVidPlayerConfigByStringValue(
                      'Definition',
                      'AUTO',
                    ),
                  ),
                  _button(
                    'addConfigInt',
                    () => FlutterAliplayer.addVidPlayerConfigByIntValue(
                      'PreviewTime',
                      30,
                    ),
                  ),
                  _button(
                    'setEncryptType',
                    () => FlutterAliplayer.setEncryptType(
                      EncryptType.Unencrypted,
                    ),
                  ),
                  _button(
                    'generatePlayerConfig',
                    FlutterAliplayer.generatePlayerConfig,
                  ),
                ]),
                _section('列表播放器', <Widget>[
                  _button(
                    'list setPlayerView',
                    () => _readyListPlayer?.setPlayerView(_viewId ?? 0),
                  ),
                  _button('list addUrlSource', () {
                    return _readyListPlayer?.addUrlSource(
                      url: _urlController.text.trim(),
                      uid: 'url_1',
                    );
                  }),
                  _button('list addVidSource 需VID', () {
                    return _readyListPlayer?.addVidSource(
                      vid: _vidController.text.trim(),
                      uid: 'vid_1',
                    );
                  }),
                  _button(
                    'list removeSource',
                    () => _readyListPlayer?.removeSource('url_1'),
                  ),
                  _button(
                    'list getCurrentUid',
                    () => _readyListPlayer?.getCurrentUid(),
                  ),
                  _button('list clear', () => _readyListPlayer?.clear()),
                  _button(
                    'list setPreloadCount',
                    () => _readyListPlayer?.setPreloadCount(2),
                  ),
                  _button(
                    'list setMaxPreloadMemorySizeMB',
                    () => _readyListPlayer?.setMaxPreloadMemorySizeMB(64),
                  ),
                  _button(
                    'list setDefinition',
                    () => _readyListPlayer?.setDefinition('AUTO'),
                  ),
                  _button(
                    'list moveToNext',
                    () => _readyListPlayer?.moveToNext(),
                  ),
                  _button(
                    'list moveToPre',
                    () => _readyListPlayer?.moveToPre(),
                  ),
                  _button(
                    'list moveTo uid',
                    () => _readyListPlayer?.moveTo(uid: 'url_1'),
                  ),
                  _button(
                    'list setPreloadScene',
                    () => _readyListPlayer?.setPreloadScene(
                      PreloadScene.SCENE_SHORT,
                    ),
                  ),
                  _button('list setMultiBitratesMode', () {
                    return _readyListPlayer?.setMultiBitratesMode(
                      MultiBitratesMode.MultiBitratesMode_Default,
                    );
                  }),
                  _button(
                    'list enablePreloadStrategy',
                    () => _readyListPlayer?.enablePreloadStrategy(true),
                  ),
                  _button(
                    'list setPreloadStrategy',
                    () => _readyListPlayer?.setPreloadStrategy(
                      '{"algorithm":"sub","offset":"200"}',
                    ),
                  ),
                  _button(
                    'list updatePreloadConfig 阻塞项',
                    () => _readyListPlayer?.updatePreloadConfig(1000),
                  ),
                ]),
                _section('直播时移', <Widget>[
                  _button(
                    'liveShift getCurrentLiveTime',
                    () => _liveShiftPlayer?.getCurrentLiveTime(),
                  ),
                  _button(
                    'liveShift getCurrentTime',
                    () => _liveShiftPlayer?.getCurrentTime(),
                  ),
                  _button(
                    'liveShift seekToLiveTime',
                    () => _liveShiftPlayer?.seekToLiveTime(0),
                  ),
                  _button('liveShift setDataSource 需时移源', () {
                    return _liveShiftPlayer?.setDataSource(
                      'https://example.com/timeline.json',
                      _urlController.text.trim(),
                    );
                  }),
                ]),
                _section('媒体预加载', <Widget>[
                  _button('MediaLoaderV1 load', () {
                    loader_v1.FlutterAliPlayerMediaLoader().load(
                      _urlController.text.trim(),
                      1000,
                    );
                    return null;
                  }),
                  _button('MediaLoaderV1 resume', () {
                    loader_v1.FlutterAliPlayerMediaLoader().resume(
                      _urlController.text.trim(),
                    );
                    return null;
                  }),
                  _button('MediaLoaderV1 pause', () {
                    loader_v1.FlutterAliPlayerMediaLoader().pause(
                      _urlController.text.trim(),
                    );
                    return null;
                  }),
                  _button('MediaLoaderV1 cancel', () {
                    loader_v1.FlutterAliPlayerMediaLoader().cancel(
                      _urlController.text.trim(),
                    );
                    return null;
                  }),
                  _button('MediaLoaderV2 addUrlTask', () async {
                    _lastPreloadTaskId =
                        await loader_v2.FlutterAliMediaLoaderV2().addUrlTask(
                          videoSource: _urlController.text.trim(),
                        );
                    return _lastPreloadTaskId;
                  }),
                  _button(
                    'MediaLoaderV2 getConfig',
                    () =>
                        loader_v2.FlutterAliMediaLoaderV2().getPreloadConfig(),
                  ),
                  _button('MediaLoaderV2 setConfig', () {
                    loader_v2.FlutterAliMediaLoaderV2().setPreloadConfig(
                      PreloadConfig(duration: 1000),
                    );
                    return null;
                  }),
                  _button('MediaLoaderV2 resetConfig', () {
                    loader_v2.FlutterAliMediaLoaderV2().resetPreloadConfig();
                    return null;
                  }),
                  _button('MediaLoaderV2 pauseTask', () {
                    loader_v2.FlutterAliMediaLoaderV2().pauseTask(
                      _lastPreloadTaskId ?? 'missing_task_id',
                    );
                    return null;
                  }),
                  _button('MediaLoaderV2 resumeTask', () {
                    loader_v2.FlutterAliMediaLoaderV2().resumeTask(
                      _lastPreloadTaskId ?? 'missing_task_id',
                    );
                    return null;
                  }),
                  _button('MediaLoaderV2 cancelTask', () {
                    loader_v2.FlutterAliMediaLoaderV2().cancelTask(
                      _lastPreloadTaskId ?? 'missing_task_id',
                    );
                    return null;
                  }),
                ]),
                _section('下载验证 需真实VID凭证', <Widget>[
                  _button('Downloader init', () {
                    _downloader = FlutterAliDownloader.init();
                    return 'created';
                  }),
                  _button('setSaveDir', () {
                    _readyDownloader.setSaveDir(
                      _downloadDirController.text.trim(),
                    );
                    return null;
                  }),
                  _button('prepare Auth', () {
                    return _readyDownloader.prepare(
                      'download_auth',
                      _vidController.text.trim(),
                      index: 0,
                      region: _regionController.text.trim(),
                      playAuth: _playAuthController.text.trim(),
                    );
                  }),
                  _button('prepare STS', () {
                    return _readyDownloader.prepare(
                      'download_sts',
                      _vidController.text.trim(),
                      index: 0,
                      region: _regionController.text.trim(),
                      accessKeyId: _accessKeyIdController.text.trim(),
                      accessKeySecret: _accessKeySecretController.text.trim(),
                      securityToken: _securityTokenController.text.trim(),
                    );
                  }),
                  _button(
                    'selectItem',
                    () => _readyDownloader.selectItem(
                      _vidController.text.trim(),
                      0,
                    ),
                  ),
                  _button('start', () {
                    _readyDownloader.start(_vidController.text.trim(), 0);
                    return null;
                  }),
                  _button(
                    'stop',
                    () => _readyDownloader.stop(_vidController.text.trim(), 0),
                  ),
                  _button(
                    'getFilePath',
                    () => _readyDownloader.getFilePath(
                      _vidController.text.trim(),
                      0,
                    ),
                  ),
                  _button('setDownloaderConfig', () {
                    return _readyDownloader.setDownloaderConfig(
                      _vidController.text.trim(),
                      '0',
                      userAgent: 'flutter_aliplayer_verification',
                      connectTimeoutS: 15,
                      networkTimeoutMs: 15000,
                    );
                  }),
                  _button('updateSource Auth', () {
                    return _readyDownloader.updateSource(
                      'download_auth',
                      _vidController.text.trim(),
                      '0',
                      region: _regionController.text.trim(),
                      playAuth: _playAuthController.text.trim(),
                    );
                  }),
                  _button(
                    'delete',
                    () =>
                        _readyDownloader.delete(_vidController.text.trim(), 0),
                  ),
                  _button(
                    'release',
                    () =>
                        _readyDownloader.release(_vidController.text.trim(), 0),
                  ),
                ]),
                _section('当前明确阻塞项', <Widget>[
                  const Text(
                    'setPrivateService: Dart 传 Int8List，OHOS HAR 仅暴露 string 形态，暂不安全映射。',
                  ),
                  const Text(
                    'setEventReportParamsDelegate: OHOS HAR 未暴露等价埋点 delegate API。',
                  ),
                  const Text(
                    'updatePreloadConfig: OHOS AliListPlayer/IListPlayer 声明没有该方法，点击会返回 notImplemented。',
                  ),
                  const Text(
                    'VID/STS/Auth/下载/直播时移：需要真实阿里云资源、授权信息和可能的 License 才能验证成功路径。',
                  ),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _buildLogPanel(),
        ],
      ),
    );
  }
}
