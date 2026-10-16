import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  static const String dbName = 'quanlynhatro.db';
  static const int dbVersion = 2;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (_isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, dbName);
    return openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeV1toV2(db);
      },
    );
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<String> getDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dbName);
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE locations (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT NOT NULL,
        address          TEXT,
        owner_name       TEXT,
        owner_phone      TEXT,
        bank_name        TEXT,
        bank_account     TEXT,
        bank_holder      TEXT,
        transfer_template TEXT,
        elec_price       INTEGER DEFAULT 3500,
        water_price      INTEGER DEFAULT 32000,
        invoice_footer   TEXT,
        qr_image_path    TEXT,
        sort_order       INTEGER DEFAULT 0,
        created_at       TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id INTEGER NOT NULL DEFAULT 1,
        room_number TEXT NOT NULL,
        floor INTEGER,
        base_rent INTEGER NOT NULL,
        internet_fee INTEGER DEFAULT 0,
        elevator_fee INTEGER DEFAULT 0,
        washing_fee INTEGER DEFAULT 0,
        status TEXT DEFAULT 'occupied',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tenants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT,
        id_card TEXT,
        contract_start TEXT,
        contract_end TEXT,
        deposit INTEGER DEFAULT 0,
        is_current INTEGER DEFAULT 1,
        notes TEXT,
        FOREIGN KEY (room_id) REFERENCES rooms (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        tenant_id INTEGER,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        rent_fee INTEGER DEFAULT 0,
        internet_fee INTEGER DEFAULT 0,
        elevator_fee INTEGER DEFAULT 0,
        washing_fee INTEGER DEFAULT 0,
        elec_old INTEGER DEFAULT 0,
        elec_new INTEGER DEFAULT 0,
        elec_unit_price INTEGER DEFAULT 3500,
        water_old INTEGER DEFAULT 0,
        water_new INTEGER DEFAULT 0,
        water_unit_price INTEGER DEFAULT 32000,
        is_paid INTEGER DEFAULT 0,
        paid_date TEXT,
        created_at TEXT,
        FOREIGN KEY (room_id) REFERENCES rooms (id),
        FOREIGN KEY (tenant_id) REFERENCES tenants (id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_invoice_room_month ON invoices(room_id, year, month)',
    );
  }

  Future<void> _upgradeV1toV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS locations (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT NOT NULL,
        address          TEXT,
        owner_name       TEXT,
        owner_phone      TEXT,
        bank_name        TEXT,
        bank_account     TEXT,
        bank_holder      TEXT,
        transfer_template TEXT,
        elec_price       INTEGER DEFAULT 3500,
        water_price      INTEGER DEFAULT 32000,
        invoice_footer   TEXT,
        qr_image_path    TEXT,
        sort_order       INTEGER DEFAULT 0,
        created_at       TEXT
      )
    ''');

    // Đọc settings hiện tại để tạo location mặc định
    final settingsRows = await db.query('settings');
    final s = {for (final r in settingsRows) r['key'] as String: r['value'] as String?};

    await db.insert('locations', {
      'name': s['building_name'] ?? 'Nhà trọ',
      'address': s['building_address'],
      'owner_name': s['owner_name'],
      'owner_phone': s['owner_phone'],
      'bank_name': s['bank_name'],
      'bank_account': s['bank_account'],
      'bank_holder': s['bank_holder'],
      'transfer_template': s['transfer_template'],
      'elec_price': int.tryParse(s['elec_price'] ?? '') ?? 3500,
      'water_price': int.tryParse(s['water_price'] ?? '') ?? 32000,
      'invoice_footer': s['invoice_footer'],
      'sort_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Thêm cột location_id vào rooms; phòng cũ tự nhận location id=1
    await db.execute(
      'ALTER TABLE rooms ADD COLUMN location_id INTEGER NOT NULL DEFAULT 1',
    );
  }

  Future<void> resetDatabase() async {
    final database = await db;
    await database.close();
    _db = null;
    final path = await getDbPath();
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// Đóng kết nối DB (để có thể ghi đè file khi khôi phục backup).
  Future<void> closeDb() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
