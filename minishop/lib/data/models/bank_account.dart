class BankAccount {
  final int? id;
  final String bankBin;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final bool isDefault;

  const BankAccount({
    this.id,
    required this.bankBin,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.isDefault = false,
  });

  BankAccount copyWith({
    int? id,
    String? bankBin,
    String? bankName,
    String? accountNumber,
    String? accountName,
    bool? isDefault,
  }) {
    return BankAccount(
      id: id ?? this.id,
      bankBin: bankBin ?? this.bankBin,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bank_bin': bankBin,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] as int,
      bankBin: map['bank_bin'] as String,
      bankName: map['bank_name'] as String,
      accountNumber: map['account_number'] as String,
      accountName: map['account_name'] as String,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}
