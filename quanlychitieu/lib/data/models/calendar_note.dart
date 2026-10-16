class CalendarNote {
  final int? id;
  final String date; // ISO 'YYYY-MM-DD'
  final String title;
  final String? content;
  final String createdAt;
  final String updatedAt;

  const CalendarNote({
    this.id,
    required this.date,
    required this.title,
    this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarNote.fromMap(Map<String, dynamic> m) => CalendarNote(
        id: m['id'] as int?,
        date: m['date'] as String,
        title: m['title'] as String,
        content: m['content'] as String?,
        createdAt: m['created_at'] as String? ?? DateTime.now().toIso8601String(),
        updatedAt: m['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'title': title,
        if (content != null) 'content': content,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  CalendarNote copyWith({
    int? id,
    String? date,
    String? title,
    String? content,
    String? updatedAt,
  }) =>
      CalendarNote(
        id: id ?? this.id,
        date: date ?? this.date,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
