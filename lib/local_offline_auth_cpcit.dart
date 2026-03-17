// library local_offline_auth_cpcit;

// Xuất file service ra để người dùng có thể import và sử dụng
export 'src/offline_auth_service.dart';

// Nếu bạn có các file model khác, hãy export chúng ở đây luôn
// export 'src/models/auth_models.dart';
import 'local_offline_auth_cpcit_platform_interface.dart';

class LocalOfflineAuthCpcit {
  Future<String?> getPlatformVersion() {
    return LocalOfflineAuthCpcitPlatform.instance.getPlatformVersion();
  }
}
