class Tenant {
  final int? id;
  final int roomId;
  final String fullName;
  final String? phone;
  final String? idCard;
  final DateTime? contractStart;
  final DateTime? contractEnd;
  final int deposit;
  final bool isCurrent;
  final String? notes;

  Tenant({
    this.id,
    required this.roomId,
    required this.fullName,
    this.phone,
    this.idCard,
    this.contractStart,
    this.contractEnd,
    this.deposit = 0,
    this.isCurrent = true,
    this.notes,
  });

  int? daysToExpire() {
    if (contractEnd == null) return null;
    final today = DateTime.now();
    final end = DateTime(contractEnd!.year, contractEnd!.month, contractEnd!.day);
    final now = DateTime(today.year, today.month, today.day);
    return end.difference(now).inDays;
  }

  bool get isExpired {
    final d = daysToExpire();
    return d != null && d < 0;
  }

  bool get isExpiring {
    final d = daysToExpire();
    return d != null && d >= 0 && d <= 30;
  }

  Tenant copyWith({
    int? id,
    int? roomId,
    String? fullName,
    String? phone,
    String? idCard,
    DateTime? contractStart,
    DateTime? contractEnd,
    int? deposit,
    bool? isCurrent,
    String? notes,
  }) {
    return Tenant(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      idCard: idCard ?? this.idCard,
      contractStart: contractStart ?? this.contractStart,
      contractEnd: contractEnd ?? this.contractEnd,
      deposit: deposit ?? this.deposit,
      isCurrent: isCurrent ?? this.isCurrent,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'full_name': fullName,
        'phone': phone,
        'id_card': idCard,
        'contract_start': contractStart?.toIso8601String(),
        'contract_end': contractEnd?.toIso8601String(),
        'deposit': deposit,
        'is_current': isCurrent ? 1 : 0,
        'notes': notes,
      };

  factory Tenant.fromMap(Map<String, dynamic> map) => Tenant(
        id: map['id'] as int?,
        roomId: map['room_id'] as int,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String?,
        idCard: map['id_card'] as String?,
        contractStart: map['contract_start'] != null
            ? DateTime.tryParse(map['contract_start'] as String)
            : null,
        contractEnd: map['contract_end'] != null
            ? DateTime.tryParse(map['contract_end'] as String)
            : null,
        deposit: (map['deposit'] as num?)?.toInt() ?? 0,
        isCurrent: (map['is_current'] as int? ?? 1) == 1,
        notes: map['notes'] as String?,
      );
}
