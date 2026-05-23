import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/auth_service.dart';
import '../utils/secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  Employee? _user;
  bool _isLoading = false;
  String? _error;

  Employee? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> checkAuth() async {
    final employeeJson = await SecureStorage.getEmployee();
    if (employeeJson != null) {
      _user = Employee.fromJson(jsonDecode(employeeJson));
      notifyListeners();
      
      // Refresh profile from server in background
      final updatedUser = await _authService.getProfile();
      if (updatedUser != null) {
        _user = updatedUser;
        await SecureStorage.saveEmployee(jsonEncode(_user!.toJson()));
        notifyListeners();
      }
    }
  }

  Future<bool> login(String eid, String password, String deviceId, {String? macAddress}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.login(eid, password, deviceId, macAddress: macAddress);
    
    _isLoading = false;
    if (result['success'] == true) {
      _user = result['employee'];
      notifyListeners();
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}
