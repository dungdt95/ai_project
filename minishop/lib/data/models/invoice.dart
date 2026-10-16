class Invoice {
  static const statusUnpaid = 'unpaid';
  static const statusPaid = 'paid';
  static const statusCancelled = 'cancelled';

  final int? id;
  final String code;
  final DateTime createdAt;
  final int totalAmount;
  final String status;
  final DateTime? paidAt;
  final String? paidMethod;
  final int? matchedNotificationId;

  const Invoice({
    this.id,
    required this.code,
    required this.createdAt,
    required this.totalAmount,
    this.status = statusUnpaid,
    this.paidAt,
    this.paidMethod,
    this.matchedNotificationId,
  });

  Invoice copyWith({
    int? id,
    String? code,
    DateTime? createdAt,
    int? totalAmount,
    String? status,
    DateTime? paidAt,
    String? paidMethod,
    int? matchedNotificationId,
  }) {
    return Invoice(
      id: id ?? this.id,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      paidMethod: paidMethod ?? this.paidMethod,
      matchedNotificationId:
          matchedNotificationId ?? this.matchedNotificationId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'created_at': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'status': status,
      'paid_at': paidAt?.toIso8601String(),
      'paid_method': paidMethod,
      'matched_notification_id': matchedNotificationId,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int,
      code: map['code'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      totalAmount: map['total_amount'] as int,
      status: map['status'] as String,
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String)
          : null,
      paidMethod: map['paid_method'] as String?,
      matchedNotificationId: map['matched_notification_id'] as int?,
    );
  }
}
