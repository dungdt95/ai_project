import 'package:sqflite/sqflite.dart';
import '../config/constants.dart';
import '../models/room.dart';
import '../models/tenant.dart';

class SeedData {
  static Future<void> seedIfEmpty(Database db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM rooms');
    final count = (rows.first['c'] as int?) ?? 0;
    if (count > 0) return;

    // Fresh install: seed location → settings → rooms/tenants
    final locationId = await _seedDefaultLocation(db);
    await _seedSettings(db);
    await _seedRoomsAndTenants(db, locationId);
  }

  static Future<int> _seedDefaultLocation(Database db) async {
    return db.insert('locations', {
      'name': AppConstants.defaultBuildingName,
      'address': '37 Đại Linh, Trung Văn, Nam Từ Liêm, Hà Nội',
      'owner_name': AppConstants.defaultOwnerName,
      'owner_phone': AppConstants.defaultOwnerPhone,
      'bank_name': AppConstants.defaultBankName,
      'bank_account': AppConstants.defaultBankAccount,
      'bank_holder': 'Đào Thúy Linh',
      'transfer_template': AppConstants.defaultTransferTemplate,
      'elec_price': AppConstants.defaultElecPrice,
      'water_price': AppConstants.defaultWaterPrice,
      'invoice_footer':
          '- Khách hàng khi tắm hãy tắt điện bình nóng lạnh để đảm bảo không bị điện giật.\n'
              '- Không hút thuốc trong phòng, nơi để xe và khu vực chung.\n'
              '- Thanh toán từ ngày 27 - 30 hàng tháng.',
      'sort_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> _seedSettings(Database db) async {
    // Giữ settings table cho backward compat nhưng không còn dùng cho location info
    final defaults = {
      AppConstants.keyBuildingName: AppConstants.defaultBuildingName,
      AppConstants.keyBuildingAddress: '37 Đại Linh',
      AppConstants.keyOwnerName: AppConstants.defaultOwnerName,
      AppConstants.keyOwnerPhone: AppConstants.defaultOwnerPhone,
      AppConstants.keyBankAccount: AppConstants.defaultBankAccount,
      AppConstants.keyBankName: AppConstants.defaultBankName,
      AppConstants.keyBankHolder: 'Đào Thúy Linh',
      AppConstants.keyTransferTemplate: AppConstants.defaultTransferTemplate,
      AppConstants.keyElecPrice: AppConstants.defaultElecPrice.toString(),
      AppConstants.keyWaterPrice: AppConstants.defaultWaterPrice.toString(),
      AppConstants.keyInvoiceFooter:
          '- Khách hàng khi tắm hãy tắt điện bình nóng lạnh để đảm bảo không bị điện giật.\n'
              '- Không hút thuốc trong phòng, nơi để xe và khu vực chung.\n'
              '- Thanh toán từ ngày 27 - 30 hàng tháng.',
    };
    final batch = db.batch();
    defaults.forEach((k, v) {
      batch.insert('settings', {'key': k, 'value': v});
    });
    await batch.commit(noResult: true);
  }

  static Future<void> _seedRoomsAndTenants(Database db, int locationId) async {
    final rooms = <_RoomSeed>[
      _RoomSeed('101', 1, 2800000, 100000, 60000, 50000, 'Thủy', '0327337638',
          DateTime(2025, 12, 28), DateTime(2026, 2, 28)),
      _RoomSeed('201', 2, 3300000, 100000, 200000, 100000, 'Niên', '0966506007',
          DateTime(2025, 12, 28), DateTime(2026, 6, 28)),
      _RoomSeed('202', 2, 3200000, 100000, 300000, 150000, 'Huyền',
          '0358556572', DateTime(2025, 12, 26), DateTime(2026, 12, 26)),
      _RoomSeed('301', 3, 3300000, 100000, 300000, 0, 'Vũ', '0982196305',
          DateTime(2025, 12, 28), DateTime(2026, 12, 28)),
      _RoomSeed('302', 3, 2800000, 100000, 200000, 0, 'Hằng', '0348530871',
          DateTime(2025, 12, 26), DateTime(2026, 12, 26)),
      _RoomSeed('401', 4, 3300000, 100000, 100000, 50000, 'Chi', '0966381640',
          DateTime(2025, 12, 26), DateTime(2026, 8, 1)),
      _RoomSeed('402', 4, 3000000, 0, 200000, 0, 'Công', '0981352489',
          DateTime(2026, 1, 6), DateTime(2027, 1, 6)),
      _RoomSeed('501', 5, 3200000, 100000, 200000, 0, 'Mai', '0968046691',
          DateTime(2025, 12, 26), DateTime(2026, 6, 26)),
      _RoomSeed('502', 5, 3200000, 0, 200000, 100000, 'Ngọc Anh',
          '0915954773', DateTime(2026, 3, 1), DateTime(2026, 9, 1)),
      _RoomSeed('601', 6, 3200000, 100000, 200000, 100000, 'Chúc',
          '0398610020', DateTime(2026, 4, 1), DateTime(2026, 10, 1)),
    ];

    for (final r in rooms) {
      final room = Room(
        locationId: locationId,
        roomNumber: r.number,
        floor: r.floor,
        baseRent: r.rent,
        internetFee: r.internet,
        elevatorFee: r.elevator,
        washingFee: r.washing,
        status: 'occupied',
      );
      final roomId = await db.insert('rooms', room.toMap()..remove('id'));

      final tenant = Tenant(
        roomId: roomId,
        fullName: r.tenantName,
        phone: r.phone,
        contractStart: r.start,
        contractEnd: r.end,
        isCurrent: true,
      );
      await db.insert('tenants', tenant.toMap()..remove('id'));
    }
  }
}

class _RoomSeed {
  final String number;
  final int floor;
  final int rent;
  final int internet;
  final int elevator;
  final int washing;
  final String tenantName;
  final String phone;
  final DateTime start;
  final DateTime end;
  _RoomSeed(this.number, this.floor, this.rent, this.internet, this.elevator,
      this.washing, this.tenantName, this.phone, this.start, this.end);
}
