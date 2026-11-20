import 'drive_models.dart';

/// Phân tích HTML của `drive.google.com/embeddedfolderview?id=...`.
class DriveListingParser {
  const DriveListingParser._();

  static final RegExp _entryStart = RegExp(r'<div class="flip-entry"');
  static final RegExp _href = RegExp(
    r'href="https://(?:drive|docs)\.google\.com/([^"]*)"',
  );
  static final RegExp _fileId = RegExp(
    r'/(?:file|document|spreadsheets|presentation|forms|drawings)/d/([A-Za-z0-9_-]+)',
  );
  static final RegExp _folderId = RegExp(r'/folders/([A-Za-z0-9_-]+)');
  static final RegExp _title = RegExp(
    r'<div class="flip-entry-title">(.*?)</div>',
    dotAll: true,
  );
  static final RegExp _modified = RegExp(
    r'<div class="flip-entry-last-modified"><div>(.*?)</div>',
    dotAll: true,
  );
  static final RegExp _icon = RegExp(
    r'flip-entry-list-icon"><img src="[^"]*?/type/([^"?]+)',
  );
  static final RegExp _pageTitle = RegExp(
    r'<title>(.*?)</title>',
    dotAll: true,
  );

  /// Trang trả về có phải trang đăng nhập (thư mục riêng tư) không.
  static bool isSignInPage(String html) {
    if (html.contains('flip-entries') || html.contains('flip-entry')) {
      return false;
    }
    return html.contains('accounts.google.com') ||
        html.contains('ServiceLogin') ||
        RegExp(
          r'<title>\s*(Sign in|Đăng nhập)',
          caseSensitive: false,
        ).hasMatch(html);
  }

  static DriveListing parse(String html) {
    if (isSignInPage(html)) throw const DriveSignInRequiredException();
    if (!html.contains('flip-contents')) {
      throw const DriveException(
        'Không đọc được danh sách thư mục (liên kết sai hoặc thư mục không tồn tại).',
      );
    }
    final name = _unescape(_pageTitle.firstMatch(html)?.group(1) ?? '').trim();
    final starts = _entryStart.allMatches(html).map((m) => m.start).toList();
    final entries = <DriveEntry>[];
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] : html.length;
      final block = html.substring(starts[i], end);
      final href = _href.firstMatch(block)?.group(1) ?? '';
      final title = _unescape(_title.firstMatch(block)?.group(1) ?? '').trim();
      if (title.isEmpty) continue;
      final isFolder = href.contains('/folders/');
      final id = isFolder
          ? _folderId.firstMatch(href)?.group(1)
          : _fileId.firstMatch('/$href')?.group(1);
      if (id == null) continue;
      var mime = _icon.firstMatch(block)?.group(1) ?? '';
      if (isFolder) mime = 'application/vnd.google-apps.folder';
      entries.add(
        DriveEntry(
          id: id,
          title: title,
          isDoc: href.startsWith('document/'),
          mime: mime,
          modified: _unescape(_modified.firstMatch(block)?.group(1) ?? '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        ),
      );
    }
    return DriveListing(folderName: name, entries: entries);
  }

  static String _unescape(String s) {
    return s
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          return String.fromCharCode(int.parse(m.group(1)!));
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
        })
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }
}
