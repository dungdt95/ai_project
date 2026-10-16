import '../../core/db/app_database.dart';
import '../models/bank_account.dart';

class BankAccountRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<List<BankAccount>> getAll() async {
    final db = await _appDb.database;
    final rows = await db.query('bank_accounts',
        orderBy: 'is_default DESC, bank_name ASC');
    return rows.map(BankAccount.fromMap).toList();
  }

  Future<BankAccount?> getDefault() async {
    final db = await _appDb.database;
    final rows =
        await db.query('bank_accounts', where: 'is_default = 1', limit: 1);
    return rows.isEmpty ? null : BankAccount.fromMap(rows.first);
  }

  Future<int> create(BankAccount account) async {
    final db = await _appDb.database;
    return db.transaction((txn) async {
      if (account.isDefault) {
        await txn.update('bank_accounts', {'is_default': 0});
      }
      return txn.insert('bank_accounts', account.toMap());
    });
  }

  Future<void> update(BankAccount account) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      if (account.isDefault) {
        await txn.update('bank_accounts', {'is_default': 0});
      }
      await txn.update(
        'bank_accounts',
        account.toMap(),
        where: 'id = ?',
        whereArgs: [account.id],
      );
    });
  }

  Future<void> setDefault(int id) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.update('bank_accounts', {'is_default': 0});
      await txn.update(
        'bank_accounts',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> delete(int id) async {
    final db = await _appDb.database;
    await db.delete('bank_accounts', where: 'id = ?', whereArgs: [id]);
  }
}
