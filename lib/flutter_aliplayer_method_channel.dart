import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_aliplayer_platform_interface.dart';

/// An implementation of [FlutterAliplayerPlatform] that uses method channels.
class MethodChannelFlutterAliplayer extends FlutterAliplayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_aliplayer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
