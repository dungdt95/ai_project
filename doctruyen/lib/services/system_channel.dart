import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

/// Tệp Android chuyển cho app qua "Mở bằng"/"Chia sẻ" (đã chép vào cache).
class SharedFile {
  const SharedFile({required this.path, required this.name});

  final String path;
  final String name;
}

/// Cầu nối tới MainActivity: mở cài đặt TTS, xin quyền thông báo, nhận tệp.
class SystemChannel {
  SystemChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedFile') {
        final f = _parse(call.arguments);
        if (f != null) _controller.add(f);
      }
    });
  }

  final MethodChannel _channel = const MethodChannel(
    AppConstants.systemChannel,
  );
  final StreamController<SharedFile> _controller =
      StreamController<SharedFile>.broadcast();

  /// Tệp nhận được khi app đang chạy.
  Stream<SharedFile> get sharedFiles => _controller.stream;

  /// Tệp đã mở app lúc khởi động (nếu có), chỉ trả một lần.
  Future<SharedFile?> initialSharedFile() async {
    try {
      return _parse(
        await _channel.invokeMethod<Object?>('getInitialSharedFile'),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> openTtsSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openTtsSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Xin quyền thông báo và chờ người dùng chọn. `true` nếu đã được cấp.
  Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('requestNotificationPermission: $e');
      return false;
    } on MissingPluginException {
      return true; // Không phải Android.
    }
  }

  /// Giữ CPU thức (partial wake lock) trong lúc đọc nền để các câu liền nhau
  /// không bị ngắt quãng khi tắt màn hình.
  Future<void> setKeepAwake(bool on) async {
    try {
      await _channel.invokeMethod<void>('setKeepAwake', on);
    } on PlatformException catch (e) {
      debugPrint('setKeepAwake: $e');
    } on MissingPluginException {
      // Không phải Android.
    }
  }

  static SharedFile? _parse(Object? raw) {
    if (raw is Map) {
      final path = raw['path'];
      final name = raw['name'];
      if (path is String && name is String) {
        return SharedFile(path: path, name: name);
      }
    }
    return null;
  }
}
