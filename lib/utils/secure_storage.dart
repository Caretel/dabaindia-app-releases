import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  
  static const _keyToken = 'auth_token';
  static const _keyEmployee = 'employee_data';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  static Future<void> saveEmployee(String employeeJson) async {
    await _storage.write(key: _keyEmployee, value: employeeJson);
  }

  static Future<String?> getEmployee() async {
    return await _storage.read(key: _keyEmployee);
  }

  static Future<void> saveGeofenceZones(String zonesJson) async {
    await _storage.write(key: 'geofence_zones', value: zonesJson);
  }

  static Future<String?> getGeofenceZones() async {
    return await _storage.read(key: 'geofence_zones');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
