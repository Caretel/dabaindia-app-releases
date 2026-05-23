class Employee {
  final int id;
  final String eid;
  final String name;
  final String role;
  final int? shopId;
  final String? shopName;
  final double? shopLat;
  final double? shopLng;
  final int shopGeofenceRadius;
  final int weeklyOffDay;
  final bool checkedIn;

  Employee({
    required this.id,
    required this.eid,
    required this.name,
    required this.role,
    this.shopId,
    this.shopName,
    this.shopLat,
    this.shopLng,
    this.shopGeofenceRadius = 50,
    required this.weeklyOffDay,
    required this.checkedIn,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      eid: json['eid'],
      name: json['name'],
      role: json['role'],
      shopId: json['shop_id'],
      shopName: json['shop_name'],
      shopLat: json['shop_lat'] != null ? double.parse(json['shop_lat'].toString()) : null,
      shopLng: json['shop_lng'] != null ? double.parse(json['shop_lng'].toString()) : null,
      shopGeofenceRadius: json['shop_geofence_radius'] != null ? int.parse(json['shop_geofence_radius'].toString()) : 50,
      weeklyOffDay: json['weekly_off_day'] != null ? int.parse(json['weekly_off_day'].toString()) : 0,
      checkedIn: json['checked_in'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eid': eid,
      'name': name,
      'role': role,
      'shop_id': shopId,
      'shop_name': shopName,
      'shop_lat': shopLat,
      'shop_lng': shopLng,
      'shop_geofence_radius': shopGeofenceRadius,
      'weekly_off_day': weeklyOffDay,
      'checked_in': checkedIn,
    };
  }
}
