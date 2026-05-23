class ApiConfig {
  static const String baseUrl = 'https://caretel.in/dabaindia_attendance/api/';
  
  static const String login = 'auth?action=login';
  static const String logout = 'auth?action=logout';
  static const String profile = 'auth?action=profile';
  
  static const String checkIn = 'attendance?action=check_in';
  static const String checkOut = 'attendance?action=check_out';
  static const String status = 'attendance?action=status';
  static const String history = 'attendance?action=history';
  static const String geofenceZones = 'attendance?action=get_geofence_zones';
  
  static const String leaveSubmit = 'leave?action=submit_request';
  static const String leaveRequests = 'leave?action=my_requests';
  static const String leavePending = 'leave?action=my_pending';
  static const String leaveRespond = 'leave?action=respond';
  static const String notifCount = 'leave?action=notif_count';
  static const String notifList = 'leave?action=notif_list';
  static const String notifMarkRead = 'leave?action=mark_read';
  static const String checkUpdate = 'auth?action=check_update';
}
