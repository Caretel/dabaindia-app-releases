import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/employee.dart';
import '../utils/secure_storage.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> login(String eid, String password, String deviceId, {String? macAddress}) async {
    try {
      final response = await _apiService.dio.post(
        ApiConfig.login,
        data: {
          'eid': eid,
          'password': password,
          'device_id': deviceId,
          'mac_address': macAddress ?? deviceId,
        },
      );

      final data = response.data;
      if (data['success'] == true) {
        final token = data['token'];
        final employee = Employee.fromJson(data['employee']);
        
        await SecureStorage.saveToken(token);
        await SecureStorage.saveEmployee(jsonEncode(employee.toJson()));
        
        return {'success': true, 'employee': employee};
      } else {
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.dio.post(ApiConfig.logout);
    } catch (_) {
      // Ignore logout errors, just clear local data
    } finally {
      await SecureStorage.clearAll();
    }
  }

  Future<Employee?> getProfile() async {
    try {
      final response = await _apiService.dio.get(ApiConfig.profile);
      if (response.data['success'] == true) {
        return Employee.fromJson(response.data['employee']);
      }
    } catch (_) {}
    return null;
  }
}
