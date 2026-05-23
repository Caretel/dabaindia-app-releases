import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Android ID is the best unique identifier for device binding on modern Android
        return androidInfo.id; 
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String?> getMacAddress() async {
    try {
      // On modern mobile OS, physical MAC is restricted.
      // We return the unique hardware ID (Android ID/Vendor ID) as the "MAC" for binding.
      return await getDeviceId();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getWifiBssid() async {
    try {
      // Used for location-based WiFi restriction
      return await _networkInfo.getWifiBSSID();
    } catch (_) {
      return null;
    }
  }
}
