import 'dart:async';
import 'dart:io';
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
  // 普通源 (非 Alpha), 用于对比直出与合成路径。
  final String _normalUrl = 'https://vjs.zencdn.net/v/oceans.mp4';

  // Alpha 透明通道演示源: 1440x960, 左半灰度蒙版 + 右半彩色。
  // 用 "换 Alpha 源" 按钮切换到它, 再点 Alpha 按钮观察合成效果。
  // 也可换成自建素材, 例: 'http://<你的主机>:8899/alpha_test.mp4'
  final String _alphaUrl =
      'https://static.jtsee.com/app_media/video/mp4/us/alysa_split/split_5989.mp4';

  // 本地文件源 (issue #4 阻塞点 #1: 旧实现在 file:// 上返回 onError 401)。
  // 迁移到官方 SDK 后原生支持 file:// 本地视频。
  // 首次点击「本地文件」时由本页下载到应用沙箱, 不依赖任何预置文件。
  final String _localFileName = 'aliplayer_local_test.mp4';
  // 鸿蒙应用沙箱 files 目录 (由 bundleName 决定, 见 module.json5)
  final String _localDir =
      '/data/storage/el2/base/haps/entry/files';

  // 当前播放源; 由 "换 Alpha 源" 按钮切换后重新 prepare。
  String _testUrl = '';

  // Alpha 透明通道渲染演示: mode=0 关闭 (直出 XComponent), mode=1-4 开启合成。
  // 开启后合成画面由 Flutter Texture 承载, 需用 Texture widget 显示 (见 build)。
  int _alphaMode = 0;
  int? _textureId;
  // 视频原始尺寸 (Alpha 模式下 getVideoWidth/Height 返回的是合成后的可见尺寸)
  int _videoWidth = 0;
  int _videoHeight = 0;

  // stop() 在原生侧是异步的 (stop -> reset -> 重新 setUrl -> prepare),
  // Dart 侧 await stop() 只等到方法调用返回, 不等 AVPlayer 真正回到 idle。
  // 若此时立刻 setUrl, AVPlayer 会报 "current state is not idle, unsupport set url"
  // 并沿用旧源 —— 必须等状态回调里的 idle 再换源。
  Completer<void>? _stopCompleter;

  @override
  void initState() {
    super.initState();
    // 默认直接加载 Alpha 拼接源: 验收场景 (issue #3 反馈) 就是用它,
    // 免去每次先点「Alpha 源」再点 mode 的操作步骤。
    _testUrl = _alphaUrl;
    _initPlayer();
  }

  void _initPlayer() {
    _player = FlutterAliPlayerFactory.createAliPlayer();
    _player!.setOnStateChanged((int newState, String playerId) {
      // AVPlayer 回到 idle 才算 stop 真正完成, 此时才允许 setUrl 换源
      if (newState == FlutterAvpdef.idle) {
        final c = _stopCompleter;
        if (c != null && !c.isCompleted) {
          c.complete();
        }
      }
    });
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

  /// 切换播放源 (普通源 / Alpha 拼接源) 并重新 prepare。
  ///
  /// 切换前先关闭 Alpha 合成 (mode=0): 不同源的分辨率与半区方向都不同,
  /// 沿用旧 mode 会让纹理尺寸与上报尺寸的对应关系难以判读。
  Future<void> _switchSource(bool useAlpha) async {
    await _switchToUrl(useAlpha ? _alphaUrl : _normalUrl,
        useAlpha ? 'switch -> alpha source' : 'switch -> normal source');
  }

  /// 切换到本地文件源 (验证 issue #4 阻塞点 #1: 旧实现 file:// 返回 onError 401)。
  ///
  /// 复刻真实链路「先下载到沙箱, 再播本地文件」: 首次点击时把测试素材下载到
  /// 应用沙箱, 之后直接以 file:// 播放。不依赖任何预置文件。
  Future<void> _switchToLocal() async {
    final localPath = '$_localDir/$_localFileName';
    final localUrl = 'file://$localPath';
    final f = File(localPath);
    try {
      if (!f.existsSync() || f.lengthSync() == 0) {
        setState(() {
          _statusText = 'downloading to sandbox...';
          _errorMsg = '';
        });
        await _downloadTo(_alphaUrl, localPath);
      }
      if (!mounted) return;
      await _switchToUrl(localUrl, 'switch -> local file');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = '本地文件准备失败: $e');
    }
  }

  /// 下载 [url] 到沙箱 [savePath]。
  ///
  /// 直接用 dart:io 的 HttpClient 写沙箱文件 —— 应用对自身 files 目录有写权限,
  /// 无需额外插件。这也是接入方「先下载再播本地文件」链路的等价实现。
  Future<void> _downloadTo(String url, String savePath) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final file = File(savePath);
      await file.parent.create(recursive: true);
      final sink = file.openWrite();
      await resp.forEach((chunk) => sink.add(chunk));
      await sink.close();
      debugPrint('downloaded $url -> $savePath (${file.lengthSync()} bytes)');
    } finally {
      client.close();
    }
  }

  /// 同实例换源 (验证 issue #4 阻塞点 #2: 旧实现会静默失败沿用旧源)。
  Future<void> _switchToUrl(String target, String statusText) async {
    if (target == _testUrl) {
      return;
    }
    try {
      if (_alphaMode != 0) {
        await _setAlphaMode(0);
      }
      // 迁移后: 官方 SDK 的 stop 为同步调用, 状态机自行管理, 不再需要
      // 等 idle 回调 (旧 AVPlayer 实现才需要)。此处保留 stop 以保证语义一致。
      await _player!.stop();
      if (!mounted) return;
      setState(() {
        _testUrl = target;
        _isPrepared = false;
        _isPlaying = false;
        _videoWidth = 0;
        _videoHeight = 0;
        _statusText = statusText;
        _errorMsg = '';
      });
      await _player!.setUrl(target);
      await _player!.prepare();
    } catch (e) {
      _stopCompleter = null;
      if (!mounted) return;
      setState(() => _errorMsg = '切换源失败: $e');
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
                    // 验收标准用法: 直接用 getVideoWidth/Height 上报的尺寸作为
                    // Texture 的宽高比。修复后纹理 buffer 几何等于合成尺寸,
                    // 该比例即真实内容比例, 不应出现压扁/拉伸。
                    Center(
                      child: AspectRatio(
                        aspectRatio: _videoWidth > 0 && _videoHeight > 0
                            ? _videoWidth / _videoHeight
                            : 16 / 9,
                        child: Texture(textureId: _textureId!),
                      ),
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
            // 源切换: 普通源 ↔ Alpha 拼接源 (1440x960, 左半灰度蒙版 + 右半彩色)。
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _switchSource(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _testUrl == _normalUrl ? Colors.blue.shade600 : null,
                    foregroundColor:
                        _testUrl == _normalUrl ? Colors.white : null,
                  ),
                  child: const Text('普通源'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _switchSource(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _testUrl == _alphaUrl ? Colors.blue.shade600 : null,
                    foregroundColor:
                        _testUrl == _alphaUrl ? Colors.white : null,
                  ),
                  child: const Text('Alpha 源'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _switchToLocal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _testUrl.startsWith('file://')
                        ? Colors.blue.shade600
                        : null,
                    foregroundColor:
                        _testUrl.startsWith('file://') ? Colors.white : null,
                  ),
                  child: const Text('本地文件'),
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
                '  - Texture 的宽高比直接用 getVideoWidth/Height 上报尺寸即可 (buffer 几何随合成尺寸)\n'
                '  - setScalingMode 的缩放基准是合成后半幅尺寸\n'
                '  - 横竖屏旋转已按 transform 矩阵校准显示尺寸\n'
                '• 不支持: VidSts/VidAuth(需应用层解析URL)/ARTC/DRM/FairPlay/HttpDNS/悬浮窗/下载/预加载\n'
                '• 不支持: setRotateMode/setMirrorMode/setVideoBackgroundColor/setOutputAudioChannel\n'
                '• 格式限制: AVPlayer 不支持部分 HLS(.m3u8) 源\n'
                '  - Apple bipbop 测试流在本设备报 5400106 (Unsupported Format, CONTAINER_ERR)\n'
                '  - 属设备媒体内核格式能力差异, 与插件无关; 故测试源改用 MP4 (H.264+AAC)\n'
                '• 普通源: https://vjs.zencdn.net/v/oceans.mp4\n'
                '• Alpha 源: split_5989.mp4 (1440x960, 左半灰度蒙版 + 右半彩色)\n'
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
