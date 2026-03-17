// File: lib/offlineAuth/offline_auth_service.dart
// PHIÊN BẢN UTILITY CLASS (all-static) - Độc lập, an toàn và dễ tái sử dụng nhất.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lớp tiện ích tĩnh, độc lập để quản lý toàn bộ quy trình xác thực offline.
const int kDefaultPinLength = 6;

class OfflineAuthService {
  // Ngăn việc tạo instance của lớp tiện ích này.
  OfflineAuthService._();

  // --- CORE COMPONENTS ---

  static const _storage = FlutterSecureStorage();
  static final _deviceInfoPlugin = DeviceInfoPlugin();
  static final _localAuth = LocalAuthentication();

  // --- PRIVATE HELPERS & CONFIG ---
  static String _normalizeUsername(String username) =>
      username.trim().toLowerCase();

  static String _getPinSaltKey(String username) =>
      'offline_pin_salt_${_normalizeUsername(username)}';
  static String _getPinHashKey(String username) =>
      'offline_pin_hash_${_normalizeUsername(username)}';
  static String _getBiometricPinKey(String username) =>
      'biometric_pin_${_normalizeUsername(username)}';
  static String _getSetupLaterKey(String username) =>
      'offline_setup_later_${_normalizeUsername(username)}';

  static AndroidOptions _getAndroidOptions() =>
      const AndroidOptions(encryptedSharedPreferences: true);
  static IOSOptions _getIOSOptions() => const IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  static Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) return (await _deviceInfoPlugin.androidInfo).id;
      if (Platform.isIOS)
        return (await _deviceInfoPlugin.iosInfo).identifierForVendor ??
            'ios_id_not_found';
    } catch (e) {
      if (kDebugMode) debugPrint('Lỗi không lấy được Device ID: $e');
    }
    return 'unknown_device_id';
  }

  // ========== CÁC HÀM LOGIC CÔNG KHAI (PUBLIC, STATIC) ==========

  // static Future<bool> authenticateWithPin({
  //   required String username,
  //   required String inputPin,
  //   VoidCallback? onStorageInvalidated,
  // }) async {
  //   if (username.isEmpty || inputPin.isEmpty) return false;
  //   try {
  //     // Logic đọc dữ liệu cũ
  //     final storedHash = await _storage.read(key: _getPinHashKey(username), aOptions: _getAndroidOptions(), iOptions: _getIOSOptions());
  //     final storedSaltBase64 = await _storage.read(key: _getPinSaltKey(username), aOptions: _getAndroidOptions(), iOptions: _getIOSOptions());
  //
  //     if (storedHash == null || storedSaltBase64 == null) return false;
  //
  //     // Logic so sánh hash (giữ nguyên)
  //     final salt = base64.decode(storedSaltBase64);
  //     final deviceId = await _getDeviceId();
  //     final rawString = "${_normalizeUsername(username)}|$inputPin|$deviceId";
  //     final currentHash = await _hashWithAlgorithm(rawString, salt);
  //
  //     return _areHashesEqual(storedHash, currentHash);
  //   } on PlatformException catch (e) {
  //     // === BẮT LỖI QUAN TRỌNG TẠI ĐÂY ===
  //     // Kiểm tra nếu lỗi là do giải mã thất bại (BadPaddingException)
  //     if (e.message?.contains('javax.crypto.BadPaddingException') == true ||
  //         e.message?.contains('BAD_DECRYPT') == true)
  //     {
  //       if (kDebugMode) {
  //         print('Phát hiện khóa mã hóa không hợp lệ (do nâng cấp OS hoặc thay đổi bảo mật). Đang xóa dữ liệu cũ...');
  //       }
  //       // Xóa toàn bộ dữ liệu offline không còn hợp lệ
  //       await clearOfflineAuthData(username: username);
  //       // Gọi callback để thông báo cho UI biết rằng cần phải đăng nhập lại online
  //       onStorageInvalidated?.call();
  //     } else {
  //       // Xử lý các lỗi PlatformException khác
  //       if (kDebugMode) print('Lỗi PlatformException khi xác thực PIN: ${e.message}');
  //     }
  //     return false; // Luôn trả về false khi có lỗi
  //   } catch (e) {
  //     if (kDebugMode) print('Lỗi không xác định khi xác thực PIN: $e');
  //     return false;
  //   }
  // }
  static Future<void> authenticateWithPin({
    required BuildContext context,
    required String username,
    required String inputPin,
    required VoidCallback onSuccess,
    VoidCallback? onFail,
    VoidCallback? onStorageInvalidated,
  }) async {
    if (username.isEmpty || inputPin.isEmpty) {
      _showErrorSnackBar(context, "Vui lòng nhập đầy đủ thông tin.");
      onFail?.call();
      return;
    }

    try {
      // 1. Đọc dữ liệu Hash và Salt từ bộ nhớ an toàn
      final storedHash = await _storage.read(
        key: _getPinHashKey(username),
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
      final storedSaltBase64 = await _storage.read(
        key: _getPinSaltKey(username),
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );

      if (storedHash == null || storedSaltBase64 == null) {
        _showErrorSnackBar(
          context,
          "Chưa thiết lập đăng nhập offline cho tài khoản này.",
        );
        onFail?.call();
        return;
      }

      // 2. Thực hiện băm mã PIN nhập vào với Salt đã lưu
      final salt = base64.decode(storedSaltBase64);
      final deviceId = await _getDeviceId();
      final rawString = "${_normalizeUsername(username)}|$inputPin|$deviceId";
      final currentHash = await _hashWithAlgorithm(rawString, salt);

      // 3. So sánh kết quả
      if (_areHashesEqual(storedHash, currentHash)) {
        _showSuccessSnackBar(context, "Xác thực thành công!");
        onSuccess();
      } else {
        _showErrorSnackBar(context, "Mã PIN không chính xác.");
        onFail?.call();
      }
    } on PlatformException catch (e) {
      // Bắt lỗi khi khóa bảo mật bị hỏng (do nâng cấp OS hoặc thay đổi cấu hình hệ thống)
      if (e.message?.contains('javax.crypto.BadPaddingException') == true ||
          e.message?.contains('BAD_DECRYPT') == true) {
        await clearOfflineAuthData(username: username);
        onStorageInvalidated?.call();
      } else {
        _showErrorSnackBar(context, "Lỗi hệ thống: ${e.message}");
        onFail?.call();
      }
    } catch (e) {
      _showErrorSnackBar(context, "Đã xảy ra lỗi không xác định: $e");
      onFail?.call();
    }
  }

  static Future<void> authenWithBiometric({
    required BuildContext context,
    required String? username,
    required VoidCallback onSuccess,
    VoidCallback? onFail,
    VoidCallback? onNotEnrolled,
    VoidCallback? onKeysInvalidated, // Callback khi phát hiện thêm vân tay mới
  }) async {
    if (username == null || username.isEmpty) {
      _showErrorSnackBar(context, 'Vui lòng nhập tên tài khoản.');
      onFail?.call();
      return;
    }
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        _showErrorSnackBar(
          context,
          'Thiết bị này không hỗ trợ xác thực sinh trắc học.',
        );
        onFail?.call();
        return;
      }
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        onNotEnrolled?.call();
        onFail?.call();
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Vui lòng xác thực để đăng nhập nhanh',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        // <<< BẮT ĐẦU VÙNG KIỂM TRA BẢO MẬT >>>
        // Chúng ta đặt toàn bộ logic đọc mã PIN vào trong một khối try...catch.
        try {
          // <<< BƯỚC 1: Thử đọc mã PIN từ bộ nhớ an toàn.
          // Đây chính là lúc hệ điều hành kiểm tra xem khóa mã hóa có còn hợp lệ không.
          final pin = await getPinFromSecureStorage(username: username);
          if (pin == null) {
            _showErrorSnackBar(
              context,
              "Dữ liệu sinh trắc học không hợp lệ. Vui lòng đăng nhập bằng mã PIN hoặc ONLINE.",
            );
            onFail?.call();
            return;
          }
          // Nếu đọc thành công (không có lỗi), nghĩa là biometric không thay đổi.
          // bool isAuthenticated = await authenticateWithPin(username: username, inputPin: pin);
          // if (isAuthenticated) {
          //   _showSuccessSnackBar(context, 'Xác thực thành công!');
          //   onSuccess();
          // } else {
          //   _showErrorSnackBar(context, "Dữ liệu xác thực không đồng nhất.");
          //   onFail?.call();
          // }
          await authenticateWithPin(
            context: context,
            username: username,
            inputPin: pin,
            onSuccess: onSuccess,
            onFail: onFail,
            onStorageInvalidated: onKeysInvalidated,
          );
        } on PlatformException catch (e) {
          // <<< BƯỚC 2: BẮT LỖI KHI KHÓA BỊ THAY ĐỔI >>>
          // Nếu một vân tay/khuôn mặt mới được thêm vào, khóa mã hóa sẽ bị vô hiệu hóa.
          // Lệnh `_storage.read()` ở trên sẽ thất bại và ném ra một PlatformException.
          // Chúng ta bắt lỗi này tại đây.
          if (e.code == 'flutter_secure_storage_plugin_error' ||
              (Platform.isAndroid &&
                  e.message?.contains('KeyStore exception') == true)) {
            // <<< BƯỚC 3: HÀNH ĐỘNG BẢO MẬT >>>
            // Gọi callback để yêu cầu màn hình Login bắt người dùng nhập lại PIN.
            onKeysInvalidated?.call();
            onFail?.call();
          } else {
            // Xử lý các lỗi khác liên quan đến bộ nhớ an toàn.
            _showErrorSnackBar(context, "Lỗi bộ nhớ an toàn: ${e.message}");
            onFail?.call();
          }
        }
        // <<< KẾT THÚC VÙNG KIỂM TRA BẢO MẬT >>>
      } else {
        _showErrorSnackBar(context, "Xác thực đã bị hủy.");
        onFail?.call();
      }
    } on PlatformException catch (e) {
      if (e.code == auth_error.notEnrolled) {
        onNotEnrolled?.call();
      } else {
        _showErrorSnackBar(context, "Lỗi sinh trắc học: ${e.message}");
      }
      onFail?.call();
    } catch (e) {
      _showErrorSnackBar(context, 'Đã xảy ra lỗi không xác định: $e');
      onFail?.call();
    }
  }

  static Future<bool> registerGeneratedPinAuto({
    required String username,
  }) async {
    final bool isAlreadySetup = await isOfflineAuthSetup(username);
    if (isAlreadySetup) {
      if (kDebugMode) debugPrint('Mã PIN cho người dùng $username đã tồn tại.');
      return true;
    }

    final String generatedPin = _generatePin();
    final bool success = await _registerPin(
      username: username,
      pin: generatedPin,
    );

    if (success && kDebugMode)
      debugPrint('Đã tạo và đăng ký PIN mới cho $username thành công.');
    return success;
  }

  static Future<String?> getPinFromSecureStorage({
    required String username,
  }) async {
    try {
      // Logic đọc này sẽ tự động thất bại nếu vân tay/khuôn mặt đã bị thay đổi
      // từ lúc lưu, và sẽ ném ra PlatformException.
      final String? pin = await _storage.read(
        key: _getBiometricPinKey(username),
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
      return pin;
    } on PlatformException catch (e) {
      // Bắt lỗi khi khóa mã hóa bị vô hiệu hóa (vân tay mới được thêm)
      if (e.code == 'flutter_secure_storage_plugin_error' ||
          (Platform.isAndroid &&
              e.message?.contains('KeyStore exception') == true)) {
        if (kDebugMode) {
          debugPrint(
            'Lỗi bảo mật: Khóa mã hóa đã bị vô hiệu hóa. Có thể do vân tay đã thay đổi.',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint('Lỗi khi đọc PIN từ Secure Storage: ${e.message}');
        }
      }
      return null; // Trả về null khi có bất kỳ lỗi nào
    }
  }

  /// Kiểm tra xem thiết bị có hỗ trợ
  /// và người dùng đã đăng ký ít nhất một phương thức sinh trắc học (vân tay/khuôn mặt) hay chưa.
  static Future<bool> canUseBiometrics() async {
    try {
      // Đầu tiên, kiểm tra xem phần cứng thiết bị có cảm biến sinh trắc học không.
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        return false;
      }

      // Tiếp theo, kiểm tra xem người dùng đã đăng ký ít nhất một dấu vân tay/khuôn mặt chưa.
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      return canCheckBiometrics;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi khi kiểm tra sinh trắc học: ${e.message}');
      }
      return false;
    }
  }

  static Future<void> clearOfflineAuthData({required String username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getSetupLaterKey(username));
    await _storage.delete(
      key: _getBiometricPinKey(username),
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    await _storage.delete(
      key: _getPinHashKey(username),
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    await _storage.delete(
      key: _getPinSaltKey(username),
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  // static Future<bool> isOfflineAuthSetup(String username) async {
  //   final storedHash = await _storage.read(key: _getPinHashKey(username));
  //   return storedHash != null;
  // }
  static Future<bool> isOfflineAuthSetup(String username) async {
    if (username.isEmpty) return false;
    // BỔ SUNG: Truyền options vào để đảm bảo đọc đúng vùng nhớ bảo mật
    final storedHash = await _storage.read(
      key: _getPinHashKey(username),
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    return storedHash != null;
  }

  // ========== CÁC HÀM TƯƠNG TÁC VỚI UI (PUBLIC, STATIC) ==========

  static Future<void> askAndSetupOfflineAuth({
    required BuildContext context,
    required String username,
    VoidCallback? onSetupSuccess,
    bool forceShow = false, // Tham số đã có giá trị mặc định là false
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final setupLaterKey = _getSetupLaterKey(username);
    final isAlreadySetup = await isOfflineAuthSetup(username);

    // Điều kiện để bỏ qua: không "ép buộc" VÀ (người dùng đã cài đặt HOẶC đã chọn "để sau")
    if (!forceShow &&
        (isAlreadySetup || prefs.getBool(setupLaterKey) == true)) {
      return;
    }

    // Biến cờ để quyết định có hiển thị dialog cài đặt PIN hay không.
    // Nếu `forceShow` là true, ta sẽ đi thẳng tới bước cài đặt PIN.
    bool shouldProceedToSetup = forceShow;

    // Nếu không "ép buộc", chúng ta sẽ hỏi người dùng trước.
    if (!forceShow) {
      if (!context.mounted) return;
      final userChoice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Thiết lập mã PIN đăng nhập offline"),
          content: const Text("Mã số PIN này dùng để đăng nhập khi offline"),
          actions: [
            TextButton(
              child: const Text('Để sau'),
              onPressed: () => Navigator.of(ctx).pop('later'),
            ),
            ElevatedButton(
              child: const Text('Đồng ý'),
              onPressed: () => Navigator.of(ctx).pop('agree'),
            ),
          ],
        ),
      );

      if (userChoice == 'agree') {
        shouldProceedToSetup = true;
      } else if (userChoice == 'later') {
        await prefs.setBool(setupLaterKey, true);
      }
    }

    // Chỉ hiển thị dialog cài đặt PIN nếu người dùng đã đồng ý hoặc bị "ép buộc"
    if (shouldProceedToSetup) {
      // Đảm bảo context vẫn còn tồn tại trước khi hiển thị dialog mới
      if (!context.mounted) return;
      final success = await _showPinSetupDialog(
        context: context,
        username: username,
      );

      if (success == true) {
        // Nếu cài đặt thành công, xóa cờ "để sau" để không bỏ qua ở lần đăng nhập tới.
        await prefs.remove(setupLaterKey);
        if (context.mounted) {
          _showSuccessSnackBar(context, "Thiết lập PIN thành công!");
        }
        onSetupSuccess?.call();
      }
    }
  }

  // static Widget buildBiometricLoginWidget({
  //   required bool isLoading,
  //   required bool hasSavedUsername,
  //   required VoidCallback onPressed,
  // }) {
  //   // ... (Toàn bộ logic giữ nguyên như cũ, chỉ cần là static)
  //   if (!hasSavedUsername) return const SizedBox.shrink();
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 24.0),
  //     child: Center(
  //       child: Column(
  //         children: [
  //           const Text('Hoặc đăng nhập bằng', style: TextStyle(color: Colors.grey)),
  //           const SizedBox(height: 8),
  //           IconButton(
  //             iconSize: 50,
  //             icon: const Icon(Icons.fingerprint, color: Color(0xFF0c6fff)),
  //             onPressed: isLoading ? null : onPressed,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  // static Widget buildBiometricLoginButton({
  //   required BuildContext context,
  //   required String username,
  //   required bool isLoading,
  //   required bool hasSavedData,
  //   required VoidCallback onSuccess,
  // }) {
  //   if (!hasSavedData) return const SizedBox.shrink();
  //
  //
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 24.0),
  //     child: Center(
  //       child: Column(
  //         children: [
  //           const Text('Hoặc đăng nhập bằng', style: TextStyle(color: Colors.grey)),
  //           const SizedBox(height: 8),
  //           IconButton(
  //             iconSize: 50,
  //             icon: const Icon(Icons.fingerprint, color: Color(0xFF0c6fff)),
  //             // onPressed: isLoading ? null : onPressed,
  //             onPressed: isLoading ? null : () => authenWithBiometric(
  //               context: context,
  //               username: username,
  //               onSuccess: onSuccess,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  /// Widget nút bấm xác thực - Tự động kiểm tra trạng thái và hiển thị
  // static Widget buildBiometricLoginButton({
  //   required BuildContext context,
  //   required String username,
  //   required bool isLoading,
  //   required VoidCallback onSuccess,
  // }) {
  //   if (username.isEmpty) return const SizedBox.shrink();
  //
  //   return FutureBuilder<bool>(
  //     // Key giúp FutureBuilder biết khi nào cần chạy lại (khi username thay đổi)
  //     key: ValueKey('biometric_btn_$username'),
  //     future: isOfflineAuthSetup(username),
  //     builder: (context, snapshot) {
  //       // Kiểm tra điều kiện: Đã load xong VÀ có dữ liệu VÀ dữ liệu là true
  //       if (snapshot.hasData && snapshot.data == true) {
  //         return Padding(
  //           padding: const EdgeInsets.only(top: 24.0),
  //           child: Column(
  //             children: [
  //               const Text('Hoặc đăng nhập nhanh bằng',
  //                   style: TextStyle(color: Colors.grey, fontSize: 13)),
  //               const SizedBox(height: 10),
  //               IconButton(
  //                 icon: const Icon(Icons.fingerprint, size: 55, color: Color(0xFF0c6fff)),
  //                 onPressed: isLoading ? null : () => authenWithBiometric(
  //                   context: context,
  //                   username: username,
  //                   onSuccess: onSuccess,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //       // Trả về một khoảng trống có kích thước cố định để tránh UI bị nhảy (Layout Jitter)
  //       return const SizedBox(height: 0);
  //     },
  //   );
  // }

  /// Widget nút bấm xác thực - Tự động kiểm tra trạng thái và hiển thị
  static Widget buildBiometricLoginButton({
    required BuildContext context,
    required String username,
    required bool
    isLoading, // Đây là loading từ màn hình Login (ví dụ đang gọi API)
    required VoidCallback onSuccess,
  }) {
    if (username.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      key: ValueKey('biometric_btn_$username'),
      future: isOfflineAuthSetup(username),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          // Trả về Widget Stateful để tự quản lý trạng thái disable khi đang quét vân tay
          return _InternalBiometricButton(
            username: username,
            externalLoading: isLoading,
            onSuccess: onSuccess,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  static Future<bool> _registerPin({
    required String username,
    required String pin,
  }) async {
    try {
      final salt = _generateSalt();
      final deviceId = await _getDeviceId();
      final normalizedUsername = _normalizeUsername(username);
      final rawString = "$normalizedUsername|$pin|$deviceId";
      final hashedPin = await _hashWithAlgorithm(rawString, salt);
      final saltBase64 = base64.encode(salt);

      await _storage.write(
        key: _getPinHashKey(username),
        value: hashedPin,
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
      await _storage.write(
        key: _getPinSaltKey(username),
        value: saltBase64,
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
      await _storage.write(
        key: _getBiometricPinKey(username),
        value: pin,
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Lỗi khi đăng ký PIN với PBKDF2: $e');
      return false;
    }
  }
  // static Future<bool> _registerPin({required String username, required String pin}) async {
  //   // ... (Toàn bộ logic giữ nguyên như cũ, chỉ cần là static)
  //   try {
  //     final deviceId = await _getDeviceId();
  //     final normalizedUsername = _normalizeUsername(username);
  //     final rawString = "$normalizedUsername|$pin|$deviceId";
  //     final hashedPin = _hash(rawString);
  //
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setString(_getPinHashKey(username), hashedPin);
  //
  //     await _storage.write(
  //       key: _getBiometricPinKey(username),
  //       value: pin,
  //       aOptions: _getAndroidOptions(),
  //       iOptions: _getIOSOptions(),
  //     );
  //     return true;
  //   } catch (e) {
  //     return false;
  //   }
  // }
  /// Tạo ra một mã PIN với độ dài chuẩn một cách an toàn và nhất quán
  /// dựa trên username và một định danh duy nhất của thiết bị.

  static String _generatePin() {
    final random = Random.secure();
    String pin = '';
    for (int i = 0; i < kDefaultPinLength; i++) {
      pin += random.nextInt(10).toString();
    }
    return pin;
  }

  // --- PRIVATE UI HELPERS (static) ---
  static void _showSuccessSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // START GIAI PHAP PBKDF2, thay cho các loại hàm băm khác
  // THÊM CÁC HÀM NÀY VÀO VÙNG PRIVATE HELPERS

  /// Hàm tạo salt ngẫu nhiên. Salt là một chuỗi ngẫu nhiên được thêm vào trước khi băm
  /// để đảm bảo hai người dùng có cùng mã PIN cũng sẽ có hash khác nhau.
  static List<int> _generateSalt([int length = 16]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// =================================================================
  /// HÀM BĂM MỚI SỬ DỤNG cac kỹ thuật mới - AN TOÀN HƠN RẤT NHIỀU
  /// =================================================================
  ///
  /// [rawInput]: Chuỗi thô (ví dụ: "username|pin|deviceId").
  /// [salt]: Chuỗi salt đã tạo cho người dùng này.
  ///

  static Future<String> _hashWithAlgorithm(
    String rawInput,
    List<int> salt,
  ) async {
    return _hashWithPbkdf2(rawInput, salt);
  }

  /// =================================================================
  /// HÀM BĂM MỚI SỬ DỤNG PBKDF2 (TỪ THƯ VIỆN 'cryptography')
  /// =================================================================
  ///
  static Future<String> _hashWithPbkdf2(String rawInput, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = SecretKey(utf8.encode(rawInput));
    final newKey = await pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
    final newKeyBytes = await newKey.extractBytes();
    return hex.encode(newKeyBytes);
  }

  // static Future<String> _hashWithArgon2id(
  //   String rawInput,
  //   List<int> salt,
  // ) async {
  //   final argon2id = Argon2id(
  //     parallelism: 4, // Số luồng (tăng nếu device mạnh)
  //     memory: 64 * 1024, // 64 MiB (OWASP khuyến nghị cao hơn minimum 19 MiB)
  //     iterations: 3, // Thời gian (tăng để chậm hơn nếu cần)
  //     hashLength: 32, // 256 bits
  //   );
  //
  //   final rawInputBytes = utf8.encode(rawInput);
  //   final saltUint8 = Uint8List.fromList(salt);
  //
  //   final secretKey = await argon2id.deriveKey(
  //     secretKey: SecretKey(rawInputBytes),
  //     nonce: saltUint8,
  //   );
  //
  //   final derivedBytes = await secretKey.extractBytes();
  //   return hex.encode(derivedBytes); // Giữ hex để tương thích lưu trữ
  // }

  /// Hàm so sánh hai chuỗi một cách an toàn để chống timing attack.
  static bool _areHashesEqual(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

// ... Dialog Nhập PIN giữ nguyên không đổi ...
// (Phần dialog bên dưới không cần thay đổi gì)
Future<bool?> _showPinSetupDialog({
  required BuildContext context,
  required String username,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PinSetupDialogContent(username: username),
  );
}

class _PinSetupDialogContent extends StatefulWidget {
  final String username;
  const _PinSetupDialogContent({required this.username});
  @override
  State<_PinSetupDialogContent> createState() => _PinSetupDialogContentState();
}

class _PinSetupDialogContentState extends State<_PinSetupDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  // final int _pinLength = 6;
  Future<void> _onSavePin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    // Sửa ở đây: Gọi hàm static _registerPin
    final success = await OfflineAuthService._registerPin(
      username: widget.username,
      pin: _pinController.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thiết lập mã PIN'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Vui lòng tạo mã PIN gồm $kDefaultPinLength chữ số để đăng nhập Offline.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: kDefaultPinLength,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mã PIN',
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
                validator: (v) => (v?.length ?? 0) != kDefaultPinLength
                    ? 'PIN phải có $kDefaultPinLength chữ số'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                maxLength: kDefaultPinLength,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận PIN',
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
                validator: (v) =>
                    v != _pinController.text ? 'PIN xác nhận không khớp' : null,
              ),
            ],
          ),
        ),
      ),
      actions: _isLoading
          ? [
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ]
          : [
              TextButton(
                child: const Text('Hủy'),
                onPressed: () => Navigator.of(context).pop(null),
              ),
              ElevatedButton(onPressed: _onSavePin, child: const Text('Lưu')),
            ],
    );
  }
}

class _InternalBiometricButton extends StatefulWidget {
  final String username;
  final bool externalLoading;
  final VoidCallback onSuccess;

  const _InternalBiometricButton({
    required this.username,
    required this.externalLoading,
    required this.onSuccess,
  });

  @override
  State<_InternalBiometricButton> createState() =>
      _InternalBiometricButtonState();
}

class _InternalBiometricButtonState extends State<_InternalBiometricButton> {
  bool _isProcessing = false; // Trạng thái loading nội bộ khi đang quét vân tay

  Future<void> _handleTap() async {
    setState(() => _isProcessing = true);

    await OfflineAuthService.authenWithBiometric(
      context: context,
      username: widget.username,
      onSuccess: widget.onSuccess,
      // Đảm bảo nút được bật lại dù thành công hay thất bại
      onFail: () {
        if (mounted) setState(() => _isProcessing = false);
      },
    );

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nút sẽ bị disable nếu: Đang bận xử lý bên ngoài HOẶC đang bận quét vân tay
    final bool isDisabled = widget.externalLoading || _isProcessing;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        children: [
          const Text(
            'Hoặc đăng nhập nhanh bằng',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: isDisabled ? 0.5 : 1.0, // Làm mờ nút khi bị disable
            child: IconButton(
              icon: const Icon(
                Icons.fingerprint,
                size: 55,
                color: Color(0xFF0c6fff),
              ),
              onPressed: isDisabled ? null : _handleTap,
            ),
          ),
        ],
      ),
    );
  }
}
