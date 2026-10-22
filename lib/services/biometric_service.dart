import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyUsername = 'bio_saved_username';
  static const String _keyPassword = 'bio_saved_password';
  static const String _keyEnabled = 'bio_auth_enabled';

  // Kiểm tra thiết bị có hỗ trợ vân tay / sinh trắc học không
  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  // Lấy danh sách loại sinh trắc học có sẵn (vân tay, khuôn mặt...)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // Thực hiện quét vân tay / FaceID
  Future<bool> authenticate({String reason = 'Quét vân tay để đăng nhập KidSafe'}) async {
    try {
      final isAvailable = await canAuthenticate();
      if (!isAvailable) {
        // Nếu thiết bị không có phần cứng vân tay (hoặc chạy giả lập), trả về false
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Lưu thông tin đăng nhập để kích hoạt vân tay cho các lần sau
  Future<void> saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyPassword, password);
    await prefs.setBool(_keyEnabled, true);
  }

  // Lấy thông tin tài khoản đã lưu
  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_keyEnabled) ?? false;
    final username = prefs.getString(_keyUsername);
    final password = prefs.getString(_keyPassword);

    if (isEnabled && username != null && password != null) {
      return {'username': username, 'password': password};
    }
    return null;
  }

  // Xóa thông tin vân tay
  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
    await prefs.remove(_keyEnabled);
  }
}
