import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }
  }

  static Future<void> scheduleDepositReminder({
    required int id,
    required String bankName,
    required double amount,
    required DateTime dueDate,
    required int reminderDays,
  }) async {
    final notifyDate = dueDate.subtract(Duration(days: reminderDays));
    if (notifyDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(notifyDate, tz.local);
    await _plugin.zonedSchedule(
      id,
      'Sổ tiết kiệm sắp đáo hạn',
      '$bankName - Đáo hạn sau $reminderDays ngày',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'deposit_channel',
          'Nhắc đáo hạn sổ tiết kiệm',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleLoanReminder({
    required int id,
    required String borrowerName,
    required double amount,
    required DateTime returnDate,
  }) async {
    final notifyDate = returnDate.subtract(const Duration(days: 1));
    if (notifyDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(notifyDate, tz.local);
    await _plugin.zonedSchedule(
      id + 10000,
      'Khoản vay sắp đến hạn trả',
      '$borrowerName cần trả ngày mai',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'loan_channel',
          'Nhắc đến hạn trả nợ',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
  static Future<void> cancelLoan(int id) => _plugin.cancel(id + 10000);
  static Future<void> cancelAll() => _plugin.cancelAll();
}
