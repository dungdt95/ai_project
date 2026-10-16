import 'package:flutter/foundation.dart';

import '../../core/notification/notification_access.dart';
import '../../data/models/notification_app.dart';
import '../../data/repositories/notification_app_repository.dart';

class NotificationAppsController extends ChangeNotifier {
  final NotificationAppRepository _repo = NotificationAppRepository();

  List<NotificationApp> _apps = [];
  bool _isLoading = false;
  bool _permissionGranted = false;
  bool _batteryOptimizationIgnored = false;

  List<NotificationApp> get apps => _apps;
  bool get isLoading => _isLoading;
  bool get permissionGranted => _permissionGranted;
  bool get batteryOptimizationIgnored => _batteryOptimizationIgnored;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _apps = await _repo.getAll();
    _permissionGranted = await NotificationAccess.isGranted();
    _batteryOptimizationIgnored =
        await NotificationAccess.isIgnoringBatteryOptimizations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshPermissionStatus() async {
    _permissionGranted = await NotificationAccess.isGranted();
    _batteryOptimizationIgnored =
        await NotificationAccess.isIgnoringBatteryOptimizations();
    notifyListeners();
  }

  Future<void> openSettings() async {
    await NotificationAccess.openSettings();
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    await NotificationAccess.requestIgnoreBatteryOptimizations();
  }

  Future<void> toggleEnabled(NotificationApp app) async {
    await _repo.update(app.copyWith(enabled: !app.enabled));
    await load();
  }

  Future<void> updatePackageName(
      NotificationApp app, String packageName) async {
    await _repo.update(app.copyWith(packageName: packageName));
    await load();
  }
}
