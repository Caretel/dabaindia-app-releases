import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../models/geofence_zone.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../services/device_service.dart';
import '../services/background_location_service.dart';
import '../utils/secure_storage.dart';

class AttendanceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();

  bool _isLoading = false;
  bool _isCheckedIn = false;
  String? _lastCheckInTime;
  String? _lastAddress;
  List<AttendanceRecord> _history = [];
  List<String> _leaves = [];
  List<GeofenceZone> _geofenceZones = [];
  bool _zonesFetched = false;

  // Monthly working hours
  double _achievedHours = 0;
  int _targetHours = 0;
  double _remainingHours = 0;

  bool get isLoading => _isLoading;
  bool get isCheckedIn => _isCheckedIn;
  String? get lastCheckInTime => _lastCheckInTime;
  String? get lastAddress => _lastAddress;
  List<AttendanceRecord> get history => _history;
  List<String> get leaves => _leaves;
  List<GeofenceZone> get geofenceZones => _geofenceZones;
  double get achievedHours => _achievedHours;
  int get targetHours => _targetHours;
  double get remainingHours => _remainingHours;

  Future<void> fetchStatus() async {
    try {
      final response = await _apiService.dio.get(ApiConfig.status);
      if (response.data['success'] == true) {
        _isCheckedIn = response.data['checked_in'] ?? false;
        _lastCheckInTime = response.data['since'];
        _lastAddress = response.data['address'];
        _achievedHours = (response.data['achieved_hours'] ?? 0).toDouble();
        _targetHours = (response.data['target_hours'] ?? 0).toInt();
        _remainingHours = (response.data['remaining_hours'] ?? 0).toDouble();
        notifyListeners();
      }
      
      // Also fetch geofence zones if not fetched
      if (!_zonesFetched) {
        await fetchGeofenceZones();
      }
    } catch (_) {}
  }

  Future<void> fetchGeofenceZones() async {
    try {
      final response = await _apiService.dio.get(ApiConfig.geofenceZones);
      if (response.data['success'] == true) {
        _geofenceZones = (response.data['zones'] as List)
            .map((z) => GeofenceZone.fromJson(z))
            .toList();
        _zonesFetched = true;
        
        // Save to secure storage for background task
        await SecureStorage.saveGeofenceZones(jsonEncode(response.data['zones']));
        
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching geofence zones: $e');
    }
  }

  Future<Map<String, dynamic>> checkIn({
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch zones if not present
      if (_geofenceZones.isEmpty) {
        await fetchGeofenceZones();
      }

      if (_geofenceZones.isNotEmpty) {
        bool withinAnyZone = false;
        double minDistance = double.infinity;
        int targetRadius = 50;

        for (var zone in _geofenceZones) {
          double dist = Geolocator.distanceBetween(lat, lng, zone.latitude, zone.longitude);
          if (dist <= zone.radius) {
            withinAnyZone = true;
            break;
          }
          if (dist < minDistance) {
            minDistance = dist;
            targetRadius = zone.radius;
          }
        }

        if (!withinAnyZone) {
          _isLoading = false;
          notifyListeners();
          return {
            'success': false,
            'error': 'Geofence Error: You are outside all allowed zones. Closest zone is ${minDistance.toStringAsFixed(0)}m away (Required: ${targetRadius}m).'
          };
        }
      }

      final mac = await _deviceService.getMacAddress();
      final response = await _apiService.dio.post(
        ApiConfig.checkIn,
        data: {
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy,
          'mac_address': mac ?? '',
        },
      );

      _isLoading = false;
      if (response.data['success'] == true) {
        _isCheckedIn = true;
        _lastCheckInTime = response.data['time'];
        _lastAddress = response.data['address'];
        notifyListeners();
        
        final token = await SecureStorage.getToken();
        if (token != null) {
          final zonesJson = await SecureStorage.getGeofenceZones();
          await BackgroundLocationService.startService(token, zonesJson);
        }
        
        return {'success': true, 'message': response.data['message']};
      } else {
        notifyListeners();
        return {'success': false, 'error': response.data['error']};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> checkOut({
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch zones if not present
      if (_geofenceZones.isEmpty) {
        await fetchGeofenceZones();
      }

      if (_geofenceZones.isNotEmpty) {
        bool withinAnyZone = false;
        double minDistance = double.infinity;
        int targetRadius = 50;

        for (var zone in _geofenceZones) {
          double dist = Geolocator.distanceBetween(lat, lng, zone.latitude, zone.longitude);
          if (dist <= zone.radius) {
            withinAnyZone = true;
            break;
          }
          if (dist < minDistance) {
            minDistance = dist;
            targetRadius = zone.radius;
          }
        }

        if (!withinAnyZone) {
          _isLoading = false;
          notifyListeners();
          return {
            'success': false,
            'error': 'Geofence Error: You are outside all allowed zones. Closest zone is ${minDistance.toStringAsFixed(0)}m away (Required: ${targetRadius}m).'
          };
        }
      }

      final response = await _apiService.dio.post(
        ApiConfig.checkOut,
        data: {
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy,
        },
      );

      _isLoading = false;
      if (response.data['success'] == true) {
        _isCheckedIn = false;
        _lastCheckInTime = null;
        _lastAddress = response.data['address'];
        notifyListeners();
        
        await BackgroundLocationService.stopService();
        
        return {'success': true, 'message': response.data['message']};
      } else {
        notifyListeners();
        return {'success': false, 'error': response.data['error']};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<void> fetchHistory(String month) async {
    try {
      final response = await _apiService.dio.get(
        ApiConfig.history,
        queryParameters: {'month': month},
      );
      if (response.data['success'] == true) {
        _history = (response.data['records'] as List)
            .map((e) => AttendanceRecord.fromJson(e))
            .toList();
        _leaves = List<String>.from(response.data['leaves'] ?? []);
        notifyListeners();
      }
    } catch (_) {}
  }
}
