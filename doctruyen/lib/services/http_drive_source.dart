import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/drive/drive_listing_parser.dart';
import '../domain/drive/drive_models.dart';

/// Đọc thư mục Drive công khai qua các điểm cuối web không cần khóa API.
///
/// Lưu ý: `embeddedfolderview` là giao diện nhúng không có tài liệu chính thức,
/// Google có thể đổi hoặc giới hạn bất cứ lúc nào.
class HttpDriveSource implements DriveSource {
  HttpDriveSource({
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.8',
  };

  @override
  Future<DriveListing> listFolder(String folderId) async {
    final res = await _get(
      Uri.https('drive.google.com', '/embeddedfolderview', {'id': folderId}),
    );
    final html = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode == 404) {
      throw const DriveException(
        'Không tìm thấy thư mục Drive (sai liên kết?).',
      );
    }
    // 200 hoặc trang đăng nhập/lỗi: để bộ phân tích quyết định.
    if (res.statusCode >= 500 || res.statusCode == 429) {
      throw DriveException(
        'Google Drive đang bận (mã ${res.statusCode}), thử lại sau.',
      );
    }
    return DriveListingParser.parse(html);
  }

  @override
  Future<DriveFile> fetchChapter(DriveEntry entry) async {
    if (entry.isDoc) {
      for (final format in const ['md', 'txt']) {
        final res = await _get(
          Uri.https('docs.google.com', '/document/d/${entry.id}/export', {
            'format': format,
          }),
        );
        if (res.statusCode == 200 && !_looksLikeHtml(res)) {
          return DriveFile(bytes: res.bodyBytes);
        }
        if (res.statusCode == 401 || res.statusCode == 403) {
          throw const DriveSignInRequiredException();
        }
      }
      throw DriveException('Không xuất được "${entry.title}" từ Google Docs.');
    }
    var res = await _get(
      Uri.https('drive.google.com', '/uc', {
        'export': 'download',
        'id': entry.id,
      }),
    );
    if (_looksLikeHtml(res)) {
      // Trang xác nhận (tệp lớn/quét virus): lấy biểu mẫu tải về.
      final next = _confirmUri(
        utf8.decode(res.bodyBytes, allowMalformed: true),
      );
      if (next != null) res = await _get(next);
    }
    if (res.statusCode != 200 || _looksLikeHtml(res)) {
      throw DriveException(
        'Không tải được "${entry.title}" (mã ${res.statusCode}).',
      );
    }
    return DriveFile(
      bytes: res.bodyBytes,
      fileName: _fileName(res.headers['content-disposition']),
    );
  }

  bool _looksLikeHtml(http.Response r) {
    final type = (r.headers['content-type'] ?? '').toLowerCase();
    return type.contains('text/html');
  }

  static final RegExp _formAction = RegExp(
    r'<form[^>]*id="download-form"[^>]*action="([^"]+)"',
  );
  static final RegExp _hidden = RegExp(
    r'<input[^>]*type="hidden"[^>]*name="([^"]+)"[^>]*value="([^"]*)"',
  );

  /// Lấy URL tải thật từ trang xác nhận của Drive.
  static Uri? _confirmUri(String html) {
    final action = _formAction.firstMatch(html)?.group(1);
    if (action == null) return null;
    final params = <String, String>{
      for (final m in _hidden.allMatches(html))
        m.group(1)!: m.group(2)!.replaceAll('&amp;', '&'),
    };
    final base = Uri.parse(action.replaceAll('&amp;', '&'));
    return base.replace(queryParameters: {...base.queryParameters, ...params});
  }

  static String _fileName(String? disposition) {
    if (disposition == null) return '';
    final star = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    if (star != null) {
      try {
        return Uri.decodeComponent(star);
      } catch (_) {}
    }
    final plain = RegExp(
      r'filename="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    return plain ?? '';
  }

  /// GET có hạn thời gian và thử lại khi lỗi mạng tạm thời/429/5xx.
  Future<http.Response> _get(Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 600 * attempt * attempt),
        );
      }
      try {
        final res = await _client.get(uri, headers: _headers).timeout(timeout);
        if (res.statusCode == 429 || res.statusCode >= 500) {
          lastError = DriveException('Google Drive trả mã ${res.statusCode}.');
          if (attempt == 2) return res;
          continue;
        }
        return res;
      } on SocketException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
    }
    if (lastError is DriveException) throw lastError;
    throw const DriveException(
      'Không kết nối được tới Google Drive. Kiểm tra mạng rồi thử lại.',
    );
  }

  void close() => _client.close();
}
