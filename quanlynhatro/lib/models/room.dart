class Room {
  final int? id;
  final int locationId;
  final String roomNumber;
  final int? floor;
  final int baseRent;
  final int internetFee;
  final int elevatorFee;
  final int washingFee;
  final String status; // 'occupied' | 'vacant'
  final String? notes;

  Room({
    this.id,
    this.locationId = 1,
    required this.roomNumber,
    this.floor,
    required this.baseRent,
    this.internetFee = 0,
    this.elevatorFee = 0,
    this.washingFee = 0,
    this.status = 'occupied',
    this.notes,
  });

  bool get isOccupied => status == 'occupied';

  Room copyWith({
    int? id,
    int? locationId,
    String? roomNumber,
    int? floor,
    int? baseRent,
    int? internetFee,
    int? elevatorFee,
    int? washingFee,
    String? status,
    String? notes,
  }) {
    return Room(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      roomNumber: roomNumber ?? this.roomNumber,
      floor: floor ?? this.floor,
      baseRent: baseRent ?? this.baseRent,
      internetFee: internetFee ?? this.internetFee,
      elevatorFee: elevatorFee ?? this.elevatorFee,
      washingFee: washingFee ?? this.washingFee,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'room_number': roomNumber,
        'floor': floor,
        'base_rent': baseRent,
        'internet_fee': internetFee,
        'elevator_fee': elevatorFee,
        'washing_fee': washingFee,
        'status': status,
        'notes': notes,
      };

  factory Room.fromMap(Map<String, dynamic> map) => Room(
        id: map['id'] as int?,
        locationId: (map['location_id'] as num?)?.toInt() ?? 1,
        roomNumber: map['room_number'] as String,
        floor: map['floor'] as int?,
        baseRent: (map['base_rent'] as num?)?.toInt() ?? 0,
        internetFee: (map['internet_fee'] as num?)?.toInt() ?? 0,
        elevatorFee: (map['elevator_fee'] as num?)?.toInt() ?? 0,
        washingFee: (map['washing_fee'] as num?)?.toInt() ?? 0,
        status: (map['status'] as String?) ?? 'occupied',
        notes: map['notes'] as String?,
      );
}
