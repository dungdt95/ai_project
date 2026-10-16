class Invoice {
  final int? id;
  final int roomId;
  final int? tenantId;
  final int month;
  final int year;
  final int rentFee;
  final int internetFee;
  final int elevatorFee;
  final int washingFee;
  final int elecOld;
  final int elecNew;
  final int elecUnitPrice;
  final int waterOld;
  final int waterNew;
  final int waterUnitPrice;
  final bool isPaid;
  final DateTime? paidDate;
  final DateTime createdAt;

  Invoice({
    this.id,
    required this.roomId,
    this.tenantId,
    required this.month,
    required this.year,
    required this.rentFee,
    this.internetFee = 0,
    this.elevatorFee = 0,
    this.washingFee = 0,
    this.elecOld = 0,
    this.elecNew = 0,
    this.elecUnitPrice = 3500,
    this.waterOld = 0,
    this.waterNew = 0,
    this.waterUnitPrice = 32000,
    this.isPaid = false,
    this.paidDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get elecUsed => (elecNew - elecOld).clamp(0, 999999);
  int get elecFee => elecUsed * elecUnitPrice;
  int get waterUsed => (waterNew - waterOld).clamp(0, 999999);
  int get waterFee => waterUsed * waterUnitPrice;

  int get total =>
      rentFee + internetFee + elevatorFee + washingFee + elecFee + waterFee;

  Invoice copyWith({
    int? id,
    int? roomId,
    int? tenantId,
    int? month,
    int? year,
    int? rentFee,
    int? internetFee,
    int? elevatorFee,
    int? washingFee,
    int? elecOld,
    int? elecNew,
    int? elecUnitPrice,
    int? waterOld,
    int? waterNew,
    int? waterUnitPrice,
    bool? isPaid,
    DateTime? paidDate,
    DateTime? createdAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      tenantId: tenantId ?? this.tenantId,
      month: month ?? this.month,
      year: year ?? this.year,
      rentFee: rentFee ?? this.rentFee,
      internetFee: internetFee ?? this.internetFee,
      elevatorFee: elevatorFee ?? this.elevatorFee,
      washingFee: washingFee ?? this.washingFee,
      elecOld: elecOld ?? this.elecOld,
      elecNew: elecNew ?? this.elecNew,
      elecUnitPrice: elecUnitPrice ?? this.elecUnitPrice,
      waterOld: waterOld ?? this.waterOld,
      waterNew: waterNew ?? this.waterNew,
      waterUnitPrice: waterUnitPrice ?? this.waterUnitPrice,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'tenant_id': tenantId,
        'month': month,
        'year': year,
        'rent_fee': rentFee,
        'internet_fee': internetFee,
        'elevator_fee': elevatorFee,
        'washing_fee': washingFee,
        'elec_old': elecOld,
        'elec_new': elecNew,
        'elec_unit_price': elecUnitPrice,
        'water_old': waterOld,
        'water_new': waterNew,
        'water_unit_price': waterUnitPrice,
        'is_paid': isPaid ? 1 : 0,
        'paid_date': paidDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as int?,
        roomId: map['room_id'] as int,
        tenantId: map['tenant_id'] as int?,
        month: map['month'] as int,
        year: map['year'] as int,
        rentFee: (map['rent_fee'] as num?)?.toInt() ?? 0,
        internetFee: (map['internet_fee'] as num?)?.toInt() ?? 0,
        elevatorFee: (map['elevator_fee'] as num?)?.toInt() ?? 0,
        washingFee: (map['washing_fee'] as num?)?.toInt() ?? 0,
        elecOld: (map['elec_old'] as num?)?.toInt() ?? 0,
        elecNew: (map['elec_new'] as num?)?.toInt() ?? 0,
        elecUnitPrice: (map['elec_unit_price'] as num?)?.toInt() ?? 3500,
        waterOld: (map['water_old'] as num?)?.toInt() ?? 0,
        waterNew: (map['water_new'] as num?)?.toInt() ?? 0,
        waterUnitPrice: (map['water_unit_price'] as num?)?.toInt() ?? 32000,
        isPaid: (map['is_paid'] as int? ?? 0) == 1,
        paidDate: map['paid_date'] != null
            ? DateTime.tryParse(map['paid_date'] as String)
            : null,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
