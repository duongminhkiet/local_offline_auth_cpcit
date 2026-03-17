import 'package:flutter_test/flutter_test.dart';
import 'package:local_offline_auth_cpcit/local_offline_auth_cpcit.dart';
import 'package:local_offline_auth_cpcit/local_offline_auth_cpcit_platform_interface.dart';
import 'package:local_offline_auth_cpcit/local_offline_auth_cpcit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLocalOfflineAuthCpcitPlatform
    with MockPlatformInterfaceMixin
    implements LocalOfflineAuthCpcitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LocalOfflineAuthCpcitPlatform initialPlatform = LocalOfflineAuthCpcitPlatform.instance;

  test('$MethodChannelLocalOfflineAuthCpcit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLocalOfflineAuthCpcit>());
  });

  test('getPlatformVersion', () async {
    LocalOfflineAuthCpcit localOfflineAuthCpcitPlugin = LocalOfflineAuthCpcit();
    MockLocalOfflineAuthCpcitPlatform fakePlatform = MockLocalOfflineAuthCpcitPlatform();
    LocalOfflineAuthCpcitPlatform.instance = fakePlatform;

    expect(await localOfflineAuthCpcitPlugin.getPlatformVersion(), '42');
  });
}
