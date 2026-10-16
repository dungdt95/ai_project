import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton wrapper around the local SQLite database.
/// All app data lives only on-device — no remote sync.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static const String dbName = 'minishop.db';
  static const int dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<String> get path async {
    final dir = await getDatabasesPath();
    return join(dir, dbName);
  }

  Future<Database> _open() async {
    return openDatabase(
      await path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Closes the connection so the underlying file can be safely copied
  /// (backup) or replaced (restore). Reopens lazily on next access.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createNotificationAppsTable(db);
      await _seedNotificationApps(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        unit TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        image_path TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'unpaid',
        paid_at TEXT,
        paid_method TEXT,
        matched_notification_id INTEGER,
        FOREIGN KEY (matched_notification_id) REFERENCES notification_logs (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        item_id INTEGER,
        item_name_snapshot TEXT NOT NULL,
        price_snapshot INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_bin TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL,
        account_name TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE notification_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_app TEXT NOT NULL,
        raw_text TEXT NOT NULL,
        parsed_amount INTEGER,
        parsed_code TEXT,
        received_at TEXT NOT NULL,
        matched_invoice_id INTEGER,
        match_status TEXT NOT NULL,
        FOREIGN KEY (matched_invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
      )
    ''');

    await _createNotificationAppsTable(db);

    await db.insert('categories', {'name': 'Trà sữa'});
    await db.insert('categories', {'name': 'Cà phê'});
    await db.insert('categories', {'name': 'Nước ép'});

    await _seedNotificationApps(db);
  }

  Future<void> _createNotificationAppsTable(Database db) async {
    await db.execute('''
      CREATE TABLE notification_apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        package_name TEXT NOT NULL UNIQUE,
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  // Best-known package names at time of writing — banks change these
  // occasionally, so they're editable in Settings rather than hardcoded
  // elsewhere in the app.
  Future<void> _seedNotificationApps(Database db) async {
    await db.insert('notification_apps',
        {'label': 'MBBank', 'package_name': 'com.mbmobile', 'enabled': 1});
    await db.insert('notification_apps',
        {'label': 'Vietcombank', 'package_name': 'com.VCB', 'enabled': 1});
    await db.insert('notification_apps', {
      'label': 'Techcombank',
      'package_name': 'com.techcombank.bb.app.te',
      'enabled': 1
    });
    await db.insert('notification_apps', {
      'label': 'Momo',
      'package_name': 'com.mservice.momotransfer',
      'enabled': 1
    });
  }
}
