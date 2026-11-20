/// Tách id thư mục từ liên kết Google Drive hoặc id trần.
class DriveLink {
  const DriveLink._();

  static final RegExp _rawId = RegExp(r'^[A-Za-z0-9_-]{10,}$');
  static final RegExp _folders = RegExp(r'/folders/([A-Za-z0-9_-]{10,})');

  /// Chấp nhận `/drive/folders/ID`, `/drive/u/0/folders/ID`, `?id=ID`, hoặc ID
  /// trần. Trả `null` nếu không nhận ra.
  static String? parseFolderId(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    if (_rawId.hasMatch(s)) return s;
    final m = _folders.firstMatch(s);
    if (m != null) return m.group(1);
    final uri = Uri.tryParse(s.contains('://') ? s : 'https://$s');
    final id = uri?.queryParameters['id'];
    if (id != null && _rawId.hasMatch(id)) return id;
    return null;
  }
}
