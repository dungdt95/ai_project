import 'package:flutter/foundation.dart';

import '../models/invoice.dart';
import '../models/location.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/location_repository.dart';
import '../repositories/room_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tenant_repository.dart';

class AppState extends ChangeNotifier {
  final RoomRepository _roomRepo = RoomRepository();
  final TenantRepository _tenantRepo = TenantRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final LocationRepository _locationRepo = LocationRepository();

  List<Location> locations = [];
  int _currentLocationId = -1;

  List<Room> rooms = [];
  Map<int, Tenant> currentTenantByRoom = {};
  Map<String, String> settings = {};

  bool _loading = false;
  bool get loading => _loading;

  RoomRepository get roomRepo => _roomRepo;
  TenantRepository get tenantRepo => _tenantRepo;
  InvoiceRepository get invoiceRepo => _invoiceRepo;
  SettingsRepository get settingsRepo => _settingsRepo;
  LocationRepository get locationRepo => _locationRepo;

  Location? get currentLocation => _currentLocationId == -1
      ? null
      : locations.where((l) => l.id == _currentLocationId).firstOrNull;

  int get currentLocationId => _currentLocationId;

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();

    locations = await _locationRepo.getAll();
    // Nếu chưa chọn, hoặc location đang chọn không còn tồn tại (vd sau restore)
    final valid = locations.any((l) => l.id == _currentLocationId);
    if (!valid && locations.isNotEmpty) {
      _currentLocationId = locations.first.id!;
    }

    await _loadRoomsForCurrentLocation();
    settings = await _settingsRepo.getAll();

    _loading = false;
    notifyListeners();
  }

  Future<void> switchLocation(int locationId) async {
    if (_currentLocationId == locationId) return;
    _currentLocationId = locationId;
    await _loadRoomsForCurrentLocation();
    notifyListeners();
  }

  Future<void> _loadRoomsForCurrentLocation() async {
    final locId = _currentLocationId == -1 ? null : _currentLocationId;
    rooms = await _roomRepo.getAll(locationId: locId);
    final tenants = await _tenantRepo.getAll(currentOnly: true);
    final roomIds = rooms.map((r) => r.id!).toSet();
    currentTenantByRoom = {
      for (final t in tenants)
        if (roomIds.contains(t.roomId)) t.roomId: t
    };
  }

  Future<void> reloadRooms() async {
    await _loadRoomsForCurrentLocation();
    notifyListeners();
  }

  Future<void> reloadLocations() async {
    locations = await _locationRepo.getAll();
    // Ensure currentLocationId still valid
    if (locations.isNotEmpty &&
        !locations.any((l) => l.id == _currentLocationId)) {
      _currentLocationId = locations.first.id!;
      await _loadRoomsForCurrentLocation();
    }
    notifyListeners();
  }

  Future<void> reloadSettings() async {
    settings = await _settingsRepo.getAll();
    notifyListeners();
  }

  Tenant? tenantOf(Room room) =>
      room.id == null ? null : currentTenantByRoom[room.id!];

  int get expiringCount =>
      currentTenantByRoom.values.where((t) => t.isExpiring && !t.isExpired).length;
  int get expiredCount =>
      currentTenantByRoom.values.where((t) => t.isExpired).length;

  /// Hóa đơn của location hiện tại trong tháng/năm cho trước.
  Future<List<Invoice>> invoicesOfMonth(int month, int year) async {
    if (_currentLocationId == -1) return [];
    final roomIds = await _roomRepo.getIdsByLocation(_currentLocationId);
    return _invoiceRepo.getByMonthAndRooms(month, year, roomIds);
  }

  /// Hóa đơn của TẤT CẢ location (dùng cho báo cáo tổng hợp).
  Future<List<Invoice>> invoicesOfMonthAll(int month, int year) =>
      _invoiceRepo.getByMonth(month, year);
}
