import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'local_offline_auth_cpcit_platform_interface.dart';

/// An implementation of [LocalOfflineAuthCpcitPlatform] that uses method channels.
class MethodChannelLocalOfflineAuthCpcit extends LocalOfflineAuthCpcitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('local_offline_auth_cpcit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
