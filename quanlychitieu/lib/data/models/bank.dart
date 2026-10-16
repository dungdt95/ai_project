class Bank {
  final int? id;
  final String code;
  final String name;
  final String? logo;

  const Bank({this.id, required this.code, required this.name, this.logo});

  factory Bank.fromMap(Map<String, dynamic> m) => Bank(
        id: m['id'] as int?,
        code: m['code'] as String,
        name: m['name'] as String,
        logo: m['logo'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'code': code,
        'name': name,
        if (logo != null) 'logo': logo,
      };
}
