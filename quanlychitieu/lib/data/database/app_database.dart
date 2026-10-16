import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  static Database? _db;

  AppDatabase._();
  factory AppDatabase() => _instance;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'quanlychitieu.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE calendar_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_calendar_notes_date ON calendar_notes(date)');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        is_default INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        payment_method TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE banks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        logo TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_deposits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        interest_rate REAL,
        start_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        term_months INTEGER,
        status TEXT DEFAULT 'active',
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (bank_id) REFERENCES banks(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE borrowers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        borrower_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        loan_date TEXT NOT NULL,
        expected_return_date TEXT NOT NULL,
        interest_rate REAL DEFAULT 0,
        status TEXT DEFAULT 'unpaid',
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (borrower_id) REFERENCES borrowers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE loan_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        paid_date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE calendar_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_calendar_notes_date ON calendar_notes(date)');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // Seed default expense categories
    final expenseCategories = [
      {'name': 'Ăn uống', 'type': 'expense', 'icon': 'restaurant', 'color': '#F44336', 'is_default': 1},
      {'name': 'Đi lại', 'type': 'expense', 'icon': 'directions_car', 'color': '#FF9800', 'is_default': 1},
      {'name': 'Mua sắm', 'type': 'expense', 'icon': 'shopping_bag', 'color': '#9C27B0', 'is_default': 1},
      {'name': 'Hóa đơn', 'type': 'expense', 'icon': 'receipt', 'color': '#3F51B5', 'is_default': 1},
      {'name': 'Giải trí', 'type': 'expense', 'icon': 'movie', 'color': '#E91E63', 'is_default': 1},
      {'name': 'Sức khỏe', 'type': 'expense', 'icon': 'local_hospital', 'color': '#F44336', 'is_default': 1},
      {'name': 'Học tập', 'type': 'expense', 'icon': 'school', 'color': '#2196F3', 'is_default': 1},
      {'name': 'Khác', 'type': 'expense', 'icon': 'more_horiz', 'color': '#9E9E9E', 'is_default': 1},
    ];
    for (final c in expenseCategories) {
      await db.insert('categories', c);
    }

    // Seed default income categories
    final incomeCategories = [
      {'name': 'Lương', 'type': 'income', 'icon': 'payments', 'color': '#4CAF50', 'is_default': 1},
      {'name': 'Thưởng', 'type': 'income', 'icon': 'card_giftcard', 'color': '#8BC34A', 'is_default': 1},
      {'name': 'Đầu tư', 'type': 'income', 'icon': 'trending_up', 'color': '#009688', 'is_default': 1},
      {'name': 'Quà tặng', 'type': 'income', 'icon': 'redeem', 'color': '#FF4081', 'is_default': 1},
      {'name': 'Khác', 'type': 'income', 'icon': 'more_horiz', 'color': '#9E9E9E', 'is_default': 1},
    ];
    for (final c in incomeCategories) {
      await db.insert('categories', c);
    }

    // Seed banks
    await db.insert('banks', {'code': 'MB', 'name': 'Ngân hàng Quân Đội (MB)', 'logo': 'mb'});
    await db.insert('banks', {'code': 'TPB', 'name': 'TPBank', 'logo': 'tpb'});
    await db.insert('banks', {'code': 'TCB', 'name': 'Techcombank', 'logo': 'tcb'});

    // Seed default settings
    await db.insert('settings', {'key': 'theme', 'value': 'light'});
    await db.insert('settings', {'key': 'due_reminder_days', 'value': '3'});
    await db.insert('settings', {'key': 'pin_enabled', 'value': 'false'});
  }
}
