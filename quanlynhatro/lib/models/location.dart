class Location {
  final int? id;
  final String name;
  final String? address;
  final String? ownerName;
  final String? ownerPhone;
  final String? bankName;
  final String? bankAccount;
  final String? bankHolder;
  final String? transferTemplate;
  final int elecPrice;
  final int waterPrice;
  final String? invoiceFooter;
  final String? qrImagePath;
  final int sortOrder;
  final String? createdAt;

  const Location({
    this.id,
    required this.name,
    this.address,
    this.ownerName,
    this.ownerPhone,
    this.bankName,
    this.bankAccount,
    this.bankHolder,
    this.transferTemplate,
    this.elecPrice = 3500,
    this.waterPrice = 32000,
    this.invoiceFooter,
    this.qrImagePath,
    this.sortOrder = 0,
    this.createdAt,
  });

  Location copyWith({
    int? id,
    String? name,
    String? address,
    String? ownerName,
    String? ownerPhone,
    String? bankName,
    String? bankAccount,
    String? bankHolder,
    String? transferTemplate,
    int? elecPrice,
    int? waterPrice,
    String? invoiceFooter,
    String? qrImagePath,
    bool clearQrImage = false,
    int? sortOrder,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bankHolder: bankHolder ?? this.bankHolder,
      transferTemplate: transferTemplate ?? this.transferTemplate,
      elecPrice: elecPrice ?? this.elecPrice,
      waterPrice: waterPrice ?? this.waterPrice,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      qrImagePath: clearQrImage ? null : (qrImagePath ?? this.qrImagePath),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'owner_name': ownerName,
        'owner_phone': ownerPhone,
        'bank_name': bankName,
        'bank_account': bankAccount,
        'bank_holder': bankHolder,
        'transfer_template': transferTemplate,
        'elec_price': elecPrice,
        'water_price': waterPrice,
        'invoice_footer': invoiceFooter,
        'qr_image_path': qrImagePath,
        'sort_order': sortOrder,
        'created_at': createdAt,
      };

  factory Location.fromMap(Map<String, dynamic> map) => Location(
        id: map['id'] as int?,
        name: map['name'] as String,
        address: map['address'] as String?,
        ownerName: map['owner_name'] as String?,
        ownerPhone: map['owner_phone'] as String?,
        bankName: map['bank_name'] as String?,
        bankAccount: map['bank_account'] as String?,
        bankHolder: map['bank_holder'] as String?,
        transferTemplate: map['transfer_template'] as String?,
        elecPrice: (map['elec_price'] as num?)?.toInt() ?? 3500,
        waterPrice: (map['water_price'] as num?)?.toInt() ?? 32000,
        invoiceFooter: map['invoice_footer'] as String?,
        qrImagePath: map['qr_image_path'] as String?,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: map['created_at'] as String?,
      );
}
