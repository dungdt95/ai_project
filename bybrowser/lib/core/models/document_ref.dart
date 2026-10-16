import 'dart:convert';

/// Loại tài liệu mà app có thể xử lý, xác định theo phần mở rộng / mime.
enum DocumentKind {
  text,
  xlsx,
  csv,
  docx,
  unsupported;

  /// Tên hiển thị tiếng Việt.
  String get label => switch (this) {
        DocumentKind.text => 'Văn bản',
        DocumentKind.xlsx => 'Bảng tính Excel',
        DocumentKind.csv => 'Bảng CSV',
        DocumentKind.docx => 'Tài liệu Word',
        DocumentKind.unsupported => 'Không hỗ trợ',
      };
}

/// Các phần mở rộng được coi là file text (mở bằng text editor).
const kTextExtensions = <String>{
  'txt', 'md', 'markdown', 'json', 'xml', 'yaml', 'yml',
  'log', 'ini', 'cfg', 'conf', 'properties', 'env', 'toml',
  'html', 'htm', 'css', 'scss', 'js', 'ts', 'jsx', 'tsx', 'dart', 'java',
  'kt', 'kts', 'py', 'rb', 'go', 'rs', 'c', 'h', 'cpp', 'hpp', 'cs', 'php',
  'sh', 'bat', 'ps1', 'sql', 'gradle', 'lock', 'gitignore',
};

/// File bảng dữ liệu dạng chữ, mặc định mở bằng lưới bảng tính.
const kCsvExtensions = <String>{'csv', 'tsv'};

const kCsvMimeTypes = <String>{
  'text/csv',
  'text/comma-separated-values',
  'text/tab-separated-values',
};

/// Tham chiếu tới một file đã được người dùng chọn qua SAF.
///
/// [uri] là content URI của Android (ví dụ `content://com.android...`),
/// đã được cấp quyền đọc/ghi lâu dài (persistable permission).
class DocumentRef {
  const DocumentRef({
    required this.uri,
    required this.name,
    this.size,
    this.mime,
    this.lastOpened,
  });

  final String uri;
  final String name;
  final int? size;
  final String? mime;
  final DateTime? lastOpened;

  /// Phần mở rộng viết thường, không có dấu chấm; rỗng nếu không có.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  DocumentKind get kind {
    final ext = extension;
    if (ext == 'xlsx' || ext == 'xlsm') return DocumentKind.xlsx;
    if (ext == 'docx') return DocumentKind.docx;
    if (kCsvExtensions.contains(ext)) return DocumentKind.csv;
    if (kTextExtensions.contains(ext)) return DocumentKind.text;
    // Không có đuôi hoặc đuôi lạ nhưng mime là text → vẫn mở dạng text.
    final m = mime ?? '';
    if (kCsvMimeTypes.contains(m)) return DocumentKind.csv;
    if (m.startsWith('text/') ||
        m == 'application/json' ||
        m == 'application/xml') {
      return DocumentKind.text;
    }
    if (m == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return DocumentKind.xlsx;
    }
    if (m == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return DocumentKind.docx;
    }
    return DocumentKind.unsupported;
  }

  DocumentRef copyWith({
    String? uri,
    String? name,
    int? size,
    String? mime,
    DateTime? lastOpened,
  }) =>
      DocumentRef(
        uri: uri ?? this.uri,
        name: name ?? this.name,
        size: size ?? this.size,
        mime: mime ?? this.mime,
        lastOpened: lastOpened ?? this.lastOpened,
      );

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'name': name,
        'size': size,
        'mime': mime,
        'lastOpened': lastOpened?.toIso8601String(),
      };

  factory DocumentRef.fromJson(Map<String, dynamic> json) => DocumentRef(
        uri: json['uri'] as String,
        name: json['name'] as String,
        size: json['size'] as int?,
        mime: json['mime'] as String?,
        lastOpened: json['lastOpened'] == null
            ? null
            : DateTime.tryParse(json['lastOpened'] as String),
      );

  String encode() => jsonEncode(toJson());

  factory DocumentRef.decode(String s) =>
      DocumentRef.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) => other is DocumentRef && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Định dạng kích thước file dễ đọc (B, KB, MB).
String formatFileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}
