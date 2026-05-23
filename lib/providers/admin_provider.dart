import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../utils/secure_storage.dart';

class EmployeeLocation {
  final int id;
  final String eid;
  final String name;
  final String? shop;
  final bool isCheckedIn;
  final String? checkIn;
  final double? lastLat;
  final double? lastLng;
  final String? lastSeen;

  EmployeeLocation({
    required this.id,
    required this.eid,
    required this.name,
    this.shop,
    required this.isCheckedIn,
    this.checkIn,
    this.lastLat,
    this.lastLng,
    this.lastSeen,
  });

  factory EmployeeLocation.fromJson(Map<String, dynamic> json) {
    return EmployeeLocation(
      id: json['id'] as int,
      eid: json['eid'] ?? '',
      name: json['name'] ?? '',
      shop: json['shop'],
      isCheckedIn: json['is_checked_in'] == true,
      checkIn: json['check_in'],
      lastLat: json['last_lat'] != null ? (json['last_lat'] as num).toDouble() : null,
      lastLng: json['last_lng'] != null ? (json['last_lng'] as num).toDouble() : null,
      lastSeen: json['last_seen'],
    );
  }
}

class AdminProvider extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://caretel.in/dabaindia_attendance/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingEmployees = false;
  bool get isLoadingEmployees => _isLoadingEmployees;

  Map<String, dynamic> _stats = {
    'total_employees': 0,
    'present_today': 0,
    'absent_today': 0,
    'on_leave_today': 0,
  };
  Map<String, dynamic> get stats => _stats;

  List<EmployeeLocation> _employees = [];
  List<EmployeeLocation> get employees => _employees;

  Future<void> fetchDashboardStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _dio.get(
        '/admin_dashboard.php',
        queryParameters: {'action': 'stats'},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.json,
        ),
      );

      final data = response.data;
      if (data['success'] == true) {
        _stats = data['stats'];
      }
    } catch (e) {
      debugPrint("Error fetching admin stats: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllEmployeesLocation() async {
    _isLoadingEmployees = true;
    notifyListeners();

    try {
      final token = await SecureStorage.getToken();
      if (token == null) return;

      final response = await _dio.get(
        '/attendance.php',
        queryParameters: {'action': 'get_all_employees_location'},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.json,
        ),
      );

      final data = response.data;
      if (data['success'] == true && data['employees'] != null) {
        _employees = (data['employees'] as List)
            .map((e) => EmployeeLocation.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint("Error fetching employees locations: $e");
    } finally {
      _isLoadingEmployees = false;
      notifyListeners();
    }
  }

  /// Static method used by TrackEmployeeScreen to fetch a specific employee's
  /// location trail without needing a full provider context.
  static Future<Map<String, dynamic>> fetchEmployeeLocationData(int employeeId) async {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://caretel.in/dabaindia_attendance/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    final token = await SecureStorage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await dio.get(
      '/attendance.php',
      queryParameters: {
        'action': 'get_employee_location',
        'employee_id': employeeId,
        'limit': 50,
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.json,
      ),
    );

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to fetch location');
    }
    return data;
  }
}
