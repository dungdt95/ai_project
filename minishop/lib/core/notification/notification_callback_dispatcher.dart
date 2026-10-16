import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notification_handler.dart';

const _backgroundChannel = MethodChannel('vn.minishop/notification_bg');

/// Entry point for the headless background isolate the native
/// NotificationListenerService spins up when the app isn't running.
/// Registered via `PluginUtilities.getCallbackHandle` in main.dart — the
/// name/signature must stay stable since native code resolves it by
/// compiled callback handle, not by import path.
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  _backgroundChannel.setMethodCallHandler((call) async {
    if (call.method == 'onNotificationPosted') {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      await NotificationHandler.handle(
        packageName: args['packageName'] as String,
        rawText: args['text'] as String,
      );
      await _backgroundChannel.invokeMethod('done');
    }
    return null;
  });

  _backgroundChannel.invokeMethod('initialized');
}
