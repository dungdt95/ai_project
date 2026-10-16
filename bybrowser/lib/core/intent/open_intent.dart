import 'package:flutter/services.dart';

/// Nhận URI từ "Mở bằng…" (ACTION_VIEW) của Android.
///
/// - Lúc khởi động: gọi [takePending] để lấy URI đã nhận trước khi Dart chạy.
/// - Khi app đang chạy: Kotlin gọi ngược `onOpen` → [onOpen] được gọi.
class OpenIntent {
  OpenIntent._();

  static const _channel = MethodChannel('com.dtdung.bybrowser/intent');
  static void Function(String uri)? onOpen;
  static bool _bound = false;

  static void bind() {
    if (_bound) return;
    _bound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpen' && call.arguments is String) {
        onOpen?.call(call.arguments as String);
      }
    });
  }

  static Future<String?> takePending() async {
    try {
      return await _channel.invokeMethod<String>('takePendingOpen');
    } on PlatformException {
      return null;
    }
  }
}
