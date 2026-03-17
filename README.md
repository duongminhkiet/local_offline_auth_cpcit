# Local Offline Auth CPCIT

[![pub package](https://img.shields.io/pub/v/local_offline_auth_cpcit.svg)](https://pub.dev/packages/local_offline_auth_cpcit)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin that provides a secure solution for offline authentication. It allows users to log in using **Biometrics (Fingerprint/FaceID)** or an **Encrypted PIN** when the internet connection is unavailable.

## ✨ Features
- 🔒 **Secure Storage:** Sensitive data is encrypted using AES-GCM 256-bit and PBKDF2.
- 🧬 **Biometric Auth:** Seamless integration with Fingerprint and FaceID.
- 📡 **Offline Mode:** Login capability without internet connection via secure PIN fallback.
- 🛠 **Pre-built UI:** Includes a ready-to-use Biometric button that handles all logic automatically.
- 📱 **Device Binding:** Authentication is tied to the specific device ID for enhanced security.

## 🚀 Getting Started

### Android Configuration
1. Add permission to `AndroidManifest.xml`: 
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package="com.example.app">
  <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
</manifest>
```
2. Update your `MainActivity.kt` to inherit from `FlutterFragmentActivity`:
  ```kotlin
  import io.flutter.embedding.android.FlutterFragmentActivity

  class MainActivity: FlutterFragmentActivity() {
      // ...
  }
  ```

### iOS Configuration
Add the following to `Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Explain why your app needs Face ID access here.</string>
```

## 💡 Usage

### Initialize Offline Auth (After Online Login)
Automatically register a secure PIN in the background after a successful API login:
```dart
bool autoResigterPin = await OfflineAuthService.registerGeneratedPinAuto(username: username);
```

### Integrated Biometric Button (UI)
Place this widget in your login screen. It automatically checks if offline auth is setup for the given username:
```dart
OfflineAuthService.buildBiometricLoginButton(
    context: context,
    username: _usernameController.text.trim(),
    isLoading: _isProcessingLoginApiOrOffline,
    onSuccess: () => _navigateToHome(_usernameController.text), 
      ),
```

### PIN Authentication (Offline Fallback)
```dart
    await OfflineAuthService.authenticateWithPin(
      context: context,
      username: _usernameController.text,
      inputPin: _passwordController.text,
      onSuccess: () => _navigateToHome(_usernameController.text),
      onStorageInvalidated: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You need to re-login to set up new offline PIN.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          _passwordController.clear();
        }
      },
    );
```

## 🛡 Security Note
This plugin uses a combination of hardware-backed security (Secure Storage/KeyStore/Keychain) and modern cryptographic algorithms to ensure that offline credentials cannot be easily compromised.



