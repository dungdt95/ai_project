class Borrower {
  final int? id;
  final String name;
  final String? phone;
  final String? note;

  const Borrower({this.id, required this.name, this.phone, this.note});

  factory Borrower.fromMap(Map<String, dynamic> m) => Borrower(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        note: m['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        if (phone != null) 'phone': phone,
        if (note != null) 'note': note,
      };
}
