import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_aliplayer_method_channel.dart';

abstract class FlutterAliplayerPlatform extends PlatformInterface {
  /// Constructs a FlutterAliplayerPlatform.
  FlutterAliplayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAliplayerPlatform _instance = MethodChannelFlutterAliplayer();

  /// The default instance of [FlutterAliplayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAliplayer].
  static FlutterAliplayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAliplayerPlatform] when
  /// they register themselves.
  static set instance(FlutterAliplayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
