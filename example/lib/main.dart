import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // 测试视频 URL (MP4 / H.264 + AAC)
  //
  // 注意: 原测试源为 Apple HLS (.m3u8):
  //   https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8
  // 该源在 OHOS 上不可用 —— 鸿蒙 AVPlayer 内核不支持它的封装格式, prepare 后报:
  //   5400106 (Unsupported Format): CONTAINER_ERR-unsupport interface,
  //   unsupport container format type
  // 这是设备媒体内核的格式能力差异, 与插件无关; Android/iOS 侧无此限制。
  // 因此改用 AVPlayer 明确支持的 MP4 源。
  // 如需复现该限制, 取消上面注释并替换下面的 URL 即可。
  // Alpha 透明通道演示源 (可选): 左半 RGB + 右半灰度蒙版 (黑=透明, 白=不透明)。
  // 想看透出效果时换成它, 然后点 Alpha 按钮。
  // 例: 'http://<你的主机>:8899/alpha_test.mp4'
  final String _testUrl = 'https://vjs.zencdn.net/v/oceans.mp4';

  // Alpha 透明通道渲染演示: mode=0 关闭 (直出 XComponent), mode=1-4 开启合成。
  // 开启后合成画面由 Flutter Texture 承载, 需用 Texture widget 显示 (见 build)。
  int _alphaMode = 0;
  int? _textureId;
  // 视频原始尺寸 (Alpha 模式下 getVideoWidth/Height 返回的是合成后的可见尺寸)
  int _videoWidth = 0;
  int _videoHeight = 0;

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
    _player!.setOnError(
        (int errorCode, String? errorExtra, String? errorMsg, String playerId) {
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
    _player!.setOnInfo(
        (int? infoCode, int? extraValue, String? extraMsg, String playerId) {
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

  /// 设置 Alpha 渲染模式 (0=无 / 1=alpha在右 / 2=左 / 3=上 / 4=下)。
  ///
  /// mode=1-4 成功后返回 {textureId}, 需用 Texture widget 承载合成画面;
  /// mode=0 释放合成纹理, 画面回到 AliPlayerView 的 XComponent 直出。
  ///
  /// 同时调用 getAlphaRenderMode() 回读当前值, 状态栏显示
  /// `set=N query=N OK` 或 `MISMATCH`。
  Future<void> _setAlphaMode(int next) async {
    try {
      final ret = await _player!.setAlphaRenderMode(next);
      final tid = (ret is Map) ? (ret['textureId'] as num?)?.toInt() : null;
      // 回读当前生效的模式
      final queried = await _player!.getAlphaRenderMode();
      final w = await _player!.getVideoWidth();
      final h = await _player!.getVideoHeight();
      setState(() {
        _alphaMode = next;
        _textureId = next == 0 ? null : tid;
        _videoWidth = (w as num?)?.toInt() ?? 0;
        _videoHeight = (h as num?)?.toInt() ?? 0;
        _statusText =
            'set=$next query=$queried ${next == queried ? "OK" : "MISMATCH"}';
        _errorMsg = '';
      });
    } catch (e) {
      // 插件在无法生效时返回 PlatformException(UNSUPPORTED/ALPHA_ERROR), 此处降级
      setState(() {
        _errorMsg = 'setAlphaRenderMode($next) 失败: $e';
      });
    }
  }

  /// 切换横竖屏。
  ///
  /// 在 Alpha 模式 (mode=1-4) 下点此按钮, 可观察合成画面随窗口旋转的表现。
  ///
  /// 目标方向由当前真实窗口尺寸推断, 不使用缓存的布尔值 ——
  /// 否则应用以竖屏启动时字段初值与实际不符, 第一次点击会空转。
  ///
  /// 注意: 部分设备 (如 2in1 桌面形态) 固定横屏, 系统会拒绝旋转请求,
  /// 此时按钮无效果。
  Future<void> _toggleOrientation() async {
    final size = MediaQuery.of(context).size;
    final toPortrait = size.width >= size.height; // 当前是横屏 → 目标竖屏
    try {
      await SystemChrome.setPreferredOrientations(
        toPortrait
            ? [DeviceOrientation.portraitUp]
            : [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight
              ],
      );
      if (!mounted) return;
      setState(() {
        _statusText = 'rotate -> ${toPortrait ? "portrait" : "landscape"}';
        _errorMsg = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = '切换横竖屏失败: $e');
    }
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
    // 视频区高度按屏幕方向自适应:
    // 横屏可用高度只有竖屏的一半左右, 若用同一比例画面会过扁,
    // 故横屏取更大的占比 (0.5, 约 330 逻辑像素), 竖屏保持 0.28。
    // 整页是 ListView, 内容超高可滚动, 不必担心挤掉下方控件。
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final videoHeight = isLandscape
        ? (size.height * 0.5).clamp(240.0, 420.0)
        : (size.height * 0.28).clamp(180.0, 260.0);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('flutter_aliplayer OHOS Demo'),
        ),
        // 用 ListView 而非 Column: 内容超出屏幕高度时可滚动,
        // 不会像 Column 那样把底部控件裁掉。
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 视频渲染面。
            // mode=0: AliPlayerView 的 XComponent 直出;
            // mode=1-4: 合成结果由 Texture 承载。此时必须隐藏 AliPlayerView —
            //           XComponent 是原生 SURFACE, 不参与 Flutter 的 alpha 合成,
            //           会盖住 Texture 导致透明区透不出来。
            // 红色垫层在 Stack 最底层: Alpha 画面透明处应透出红色。
            Container(
              color: Colors.red,
              width: double.infinity,
              height: videoHeight,
              child: Stack(
                children: [
                  // Alpha 模式下 AVPlayer 输出到离屏面, XComponent 无需显示
                  Visibility(
                    visible: _textureId == null,
                    maintainState: true,
                    child: AliPlayerView(
                      onCreated: _onPlatformViewCreated,
                      x: 0,
                      y: 0,
                      width: double.infinity,
                      height: videoHeight,
                    ),
                  ),
                  if (_textureId != null && _textureId! > 0)
                    Positioned.fill(
                      child: Texture(textureId: _textureId!),
                    ),
                ],
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
                  Text(
                      '${_formatTime(_currentPosition)} / ${_formatTime(_duration)}'),
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
                const SizedBox(width: 8),
                // 横竖屏切换: 观察 Alpha 合成画面在旋转下的表现。
                // 文案显示「点击后将切换到的方向」。
                ElevatedButton(
                  onPressed: _toggleOrientation,
                  child: Text(MediaQuery.of(context).size.width >=
                          MediaQuery.of(context).size.height
                      ? '切竖屏'
                      : '切横屏'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Alpha 模式显式选择 (0-4):
            // 1=alpha在右 2=左 3=上 4=下, 透明处透出下方红色垫层; 0=关闭合成。
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Alpha:', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                for (final m in [0, 1, 2, 3, 4])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: ElevatedButton(
                      onPressed: _isPrepared ? () => _setAlphaMode(m) : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(44, 34),
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            _alphaMode == m ? Colors.blue.shade600 : null,
                        foregroundColor: _alphaMode == m ? Colors.white : null,
                      ),
                      child: Text('$m'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 适配说明。整页已是 ListView, 这里直接放文本即可,
            // 内容过长时随整页一起滚动。
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'OHOS 适配说明:\n'
                '• 播放内核: HarmonyOS AVPlayer (@ohos.multimedia.media)\n'
                '• 渲染面: XComponent (SURFACE); Alpha 模式下为 Flutter Texture\n'
                '• 已支持: URL播放/prepare/play/pause/stop/seek/音量/倍速/静音/循环/缩放/基础事件\n'
                '• 已支持: Alpha 透明通道渲染 (setAlphaRenderMode 1-4)\n'
                '  - 返回 textureId, 需用 Texture widget 承载合成画面 (透明区可透出下层 Widget)\n'
                '  - 红色垫层: Alpha 画面透明处会透出红色\n'
                '  - mode=1-4 可在 onCreated 之后任意时刻调用 (prepare 前后均可)\n'
                '  - getVideoWidth/Height 返回合成后(可见内容)尺寸, 半幅模式为原始的一半\n'
                '  - setScalingMode 的缩放基准是合成后半幅尺寸\n'
                '  - 横竖屏旋转已按 transform 矩阵校准显示尺寸\n'
                '• 不支持: VidSts/VidAuth(需应用层解析URL)/ARTC/DRM/FairPlay/HttpDNS/悬浮窗/下载/预加载\n'
                '• 不支持: setRotateMode/setMirrorMode/setVideoBackgroundColor/setOutputAudioChannel\n'
                '• 格式限制: AVPlayer 不支持部分 HLS(.m3u8) 源\n'
                '  - Apple bipbop 测试流在本设备报 5400106 (Unsupported Format, CONTAINER_ERR)\n'
                '  - 属设备媒体内核格式能力差异, 与插件无关; 故测试源改用 MP4 (H.264+AAC)\n'
                '• 测试源: https://vjs.zencdn.net/v/oceans.mp4\n'
                '• 当前: alpha=$_alphaMode textureId=$_textureId '
                'video=${_videoWidth}x$_videoHeight',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
