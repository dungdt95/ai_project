import 'package:flutter/foundation.dart';

import '../../data/models/bank_account.dart';
import '../../data/repositories/bank_account_repository.dart';

class BankAccountsController extends ChangeNotifier {
  final BankAccountRepository _repo = BankAccountRepository();

  List<BankAccount> _accounts = [];
  bool _isLoading = false;

  List<BankAccount> get accounts => _accounts;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _accounts = await _repo.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAccount(BankAccount account) async {
    await _repo.create(account);
    await load();
  }

  Future<void> updateAccount(BankAccount account) async {
    await _repo.update(account);
    await load();
  }

  Future<void> setDefault(int id) async {
    await _repo.setDefault(id);
    await load();
  }

  Future<void> deleteAccount(int id) async {
    await _repo.delete(id);
    await load();
  }
}
