import 'package:flutter/material.dart';
import '../models/leave_request.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class LeaveProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  List<LeaveRequest> _myRequests = [];
  List<LeaveRequest> _pendingApprovals = [];
  List<NotificationModel> _notifications = [];
  int _unreadNotifCount = 0;

  bool get isLoading => _isLoading;
  List<LeaveRequest> get myRequests => _myRequests;
  List<LeaveRequest> get pendingApprovals => _pendingApprovals;
  List<NotificationModel> get notifications => _notifications;
  int get unreadNotifCount => _unreadNotifCount;

  Future<void> fetchMyRequests() async {
    try {
      final response = await _apiService.dio.get(ApiConfig.leaveRequests);
      if (response.data['success'] == true) {
        _myRequests = (response.data['requests'] as List)
            .map((e) => LeaveRequest.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchPendingApprovals() async {
    try {
      final response = await _apiService.dio.get(ApiConfig.leavePending);
      if (response.data['success'] == true) {
        _pendingApprovals = (response.data['requests'] as List)
            .map((e) => LeaveRequest.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> submitRequest({
    required String type,
    required String date,
    String? endDate,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.dio.post(
        ApiConfig.leaveSubmit,
        data: {
          'leave_type': type,
          'requested_date': date,
          'end_date': endDate ?? date,
          'note': note ?? '',
        },
      );

      _isLoading = false;
      notifyListeners();
      
      if (response.data['success'] == true) {
        fetchMyRequests(); // Refresh
        return {'success': true, 'message': response.data['message']};
      } else {
        return {'success': false, 'error': response.data['error']};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<bool> respondToRequest(int requestId, String decision) async {
    try {
      final response = await _apiService.dio.post(
        ApiConfig.leaveRespond,
        data: {
          'request_id': requestId,
          'decision': decision,
        },
      );
      if (response.data['success'] == true) {
        fetchPendingApprovals(); // Refresh
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await _apiService.dio.get(ApiConfig.notifList);
      if (response.data['success'] == true) {
        _notifications = (response.data['notifications'] as List)
            .map((e) => NotificationModel.fromJson(e))
            .toList();
        notifyListeners();
      }
      
      final countRes = await _apiService.dio.get(ApiConfig.notifCount);
      if (countRes.data['success'] == true) {
        _unreadNotifCount = countRes.data['count'] ?? 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markNotificationsRead() async {
    try {
      await _apiService.dio.post(ApiConfig.notifMarkRead);
      _unreadNotifCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}
