class NotificationApp {
  final int? id;
  final String label;
  final String packageName;
  final bool enabled;

  const NotificationApp({
    this.id,
    required this.label,
    required this.packageName,
    this.enabled = true,
  });

  NotificationApp copyWith({
    int? id,
    String? label,
    String? packageName,
    bool? enabled,
  }) {
    return NotificationApp(
      id: id ?? this.id,
      label: label ?? this.label,
      packageName: packageName ?? this.packageName,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'label': label,
      'package_name': packageName,
      'enabled': enabled ? 1 : 0,
    };
  }

  factory NotificationApp.fromMap(Map<String, dynamic> map) {
    return NotificationApp(
      id: map['id'] as int,
      label: map['label'] as String,
      packageName: map['package_name'] as String,
      enabled: (map['enabled'] as int) == 1,
    );
  }
}
