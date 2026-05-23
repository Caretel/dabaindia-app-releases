class AttendanceRecord {
  final int id;
  final String? checkIn;
  final String? checkOut;
  final String? duration;

  AttendanceRecord({
    required this.id,
    this.checkIn,
    this.checkOut,
    this.duration,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      checkIn: json['check_in'],
      checkOut: json['check_out'],
      duration: json['duration'],
    );
  }
}
