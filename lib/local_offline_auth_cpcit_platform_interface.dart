import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'local_offline_auth_cpcit_method_channel.dart';

abstract class LocalOfflineAuthCpcitPlatform extends PlatformInterface {
  /// Constructs a LocalOfflineAuthCpcitPlatform.
  LocalOfflineAuthCpcitPlatform() : super(token: _token);

  static final Object _token = Object();

  static LocalOfflineAuthCpcitPlatform _instance = MethodChannelLocalOfflineAuthCpcit();

  /// The default instance of [LocalOfflineAuthCpcitPlatform] to use.
  ///
  /// Defaults to [MethodChannelLocalOfflineAuthCpcit].
  static LocalOfflineAuthCpcitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LocalOfflineAuthCpcitPlatform] when
  /// they register themselves.
  static set instance(LocalOfflineAuthCpcitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
