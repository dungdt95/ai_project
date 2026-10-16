class NotificationLog {
  static const matchAuto = 'auto_matched';
  static const matchAmbiguous = 'ambiguous';
  static const matchNone = 'no_match';

  final int? id;
  final String sourceApp;
  final String rawText;
  final int? parsedAmount;
  final String? parsedCode;
  final DateTime receivedAt;
  final int? matchedInvoiceId;
  final String matchStatus;

  const NotificationLog({
    this.id,
    required this.sourceApp,
    required this.rawText,
    this.parsedAmount,
    this.parsedCode,
    required this.receivedAt,
    this.matchedInvoiceId,
    required this.matchStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'source_app': sourceApp,
      'raw_text': rawText,
      'parsed_amount': parsedAmount,
      'parsed_code': parsedCode,
      'received_at': receivedAt.toIso8601String(),
      'matched_invoice_id': matchedInvoiceId,
      'match_status': matchStatus,
    };
  }

  factory NotificationLog.fromMap(Map<String, dynamic> map) {
    return NotificationLog(
      id: map['id'] as int,
      sourceApp: map['source_app'] as String,
      rawText: map['raw_text'] as String,
      parsedAmount: map['parsed_amount'] as int?,
      parsedCode: map['parsed_code'] as String?,
      receivedAt: DateTime.parse(map['received_at'] as String),
      matchedInvoiceId: map['matched_invoice_id'] as int?,
      matchStatus: map['match_status'] as String,
    );
  }
}
