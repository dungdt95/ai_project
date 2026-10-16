
import 'package:flutter/services.dart';

import '../models/document_ref.dart';

/// Lỗi phát sinh từ tầng SAF (Storage Access Framework) phía Android.
class SafException implements Exception {
  const SafException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'SafException($code): $message';
}

/// Cầu nối tới plugin Kotlin `SafPlugin` qua MethodChannel.
///
/// Toàn bộ việc chọn / đọc / ghi file đi qua đây, dùng content URI của
/// Android thay vì đường dẫn file — nhờ đó không cần quyền truy cập toàn bộ
/// bộ nhớ và vẫn ghi đè được đúng file người dùng đã chọn.
class SafService {
  SafService._();

  static const _channel = MethodChannel('com.dtdung.bybrowser/saf');

  static const _allMimeTypes = <String>[
    'text/*',
    'application/json',
    'application/xml',
    'application/octet-stream',
    // Một số trình quản lý file gán .csv là mime của Excel cũ.
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ];

  /// Mở hộp thoại chọn file của hệ thống. Trả về `null` nếu người dùng hủy.
  static Future<DocumentRef?> openDocument({List<String>? mimeTypes}) async {
    final result = await _invoke<Map<Object?, Object?>?>('openDocument', {
      'mimeTypes': mimeTypes ?? _allMimeTypes,
    });
    return result == null ? null : _refFromMap(result);
  }

  /// Mở hộp thoại "Lưu thành…" để tạo file mới. Trả về `null` nếu hủy.
  static Future<DocumentRef?> createDocument({
    required String suggestedName,
    required String mime,
  }) async {
    final result = await _invoke<Map<Object?, Object?>?>('createDocument', {
      'name': suggestedName,
      'mime': mime,
    });
    return result == null ? null : _refFromMap(result);
  }

  /// Đọc toàn bộ nội dung file.
  static Future<Uint8List> readBytes(String uri) async {
    final bytes = await _invoke<Uint8List>('readBytes', {'uri': uri});
    return bytes ?? Uint8List(0);
  }

  /// Ghi đè toàn bộ nội dung file.
  static Future<void> writeBytes(String uri, Uint8List bytes) async {
    await _invoke<void>('writeBytes', {'uri': uri, 'bytes': bytes});
  }

  /// Lấy lại thông tin (tên, kích thước, mime) của một URI đã lưu.
  /// Ném [SafException] với code `not_found`/`no_permission` nếu không còn
  /// truy cập được (file bị xóa, quyền bị thu hồi…).
  static Future<DocumentRef> getInfo(String uri) async {
    final result = await _invoke<Map<Object?, Object?>>('getInfo', {'uri': uri});
    return _refFromMap(result!);
  }

  /// Thả quyền truy cập lâu dài với URI (khi xóa khỏi danh sách gần đây).
  static Future<void> releasePermission(String uri) async {
    await _invoke<void>('releasePermission', {'uri': uri});
  }

  static Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw SafException(e.code, e.message ?? 'Lỗi không xác định');
    }
  }

  static DocumentRef _refFromMap(Map<Object?, Object?> m) => DocumentRef(
        uri: m['uri'] as String,
        name: (m['name'] as String?) ?? 'Không tên',
        size: (m['size'] as num?)?.toInt(),
        mime: m['mime'] as String?,
        lastOpened: DateTime.now(),
      );
}
