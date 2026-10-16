import 'package:flutter/services.dart';

/// Bridges to the native side for the special "Notification access"
/// permission, which Android does not allow requesting via a normal
/// runtime dialog — the user must enable it from system Settings.
class NotificationAccess {
  static const _channel = MethodChannel('vn.minishop/notification_access');

  static Future<bool> isGranted() async {
    final result =
        await _channel.invokeMethod<bool>('isNotificationAccessGranted');
    return result ?? false;
  }

  static Future<void> openSettings() async {
    await _channel.invokeMethod('openNotificationAccessSettings');
  }

  /// OEM battery optimization is a common reason the background listener
  /// silently stops working (see SPEC.md risk notes) — exempting the app
  /// makes Android much less likely to kill it.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    final result =
        await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? false;
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
  }

  /// Registers the headless background callback so the native
  /// NotificationListenerService can run it even when the app is closed.
  /// Must be called on every app startup — callback handles are computed
  /// from compiled code offsets and can change between builds.
  static Future<void> setCallbackHandle(int handle) async {
    await _channel.invokeMethod('setCallbackHandle', {'handle': handle});
  }
}
