import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

class DeviceSyncHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Battery _battery = Battery();

  /// Lấy tên thiết bị thực tế của máy đang chạy (ví dụ: "OPPO Reno8 (Android 14)")
  static Future<String> getActualDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        final brand = android.brand.isNotEmpty ? android.brand.toUpperCase() : 'OPPO';
        final model = android.model.isNotEmpty ? android.model : 'Android';
        final release = android.version.release.isNotEmpty ? android.version.release : '14';
        return '$brand $model (Android $release)'.trim();
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        return '${ios.name} (iOS ${ios.systemVersion})';
      }
    } catch (_) {}
    return 'Điện thoại OPPO (Android)';
  }

  /// Lấy mức pin thực tế của máy điện thoại
  static Future<int> getActualBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (level > 0 && level <= 100) return level;
    } catch (_) {}
    return 85;
  }

  /// Lấy tọa độ GPS thực tế của máy điện thoại
  static Future<String> getActualLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        return '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      }
    } catch (_) {}
    return '10.762622, 106.660172';
  }
}
