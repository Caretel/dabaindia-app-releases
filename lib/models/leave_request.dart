class LeaveRequest {
  final int id;
  final int requesterId;
  final String? requesterName;
  final String? requesterEid;
  final int shopId;
  final String? shopName;
  final String leaveType;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? note;
  final String createdAt;

  LeaveRequest({
    required this.id,
    required this.requesterId,
    this.requesterName,
    this.requesterEid,
    required this.shopId,
    this.shopName,
    required this.leaveType,
    this.startDate,
    this.endDate,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'],
      requesterId: json['requester_id'],
      requesterName: json['requester_name'],
      requesterEid: json['requester_eid'],
      shopId: json['shop_id'],
      shopName: json['shop_name'],
      leaveType: json['leave_type'] ?? 'Swap',
      startDate: json['start_date'],
      endDate: json['end_date'],
      status: json['status'] ?? 'pending',
      note: json['requester_note'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
