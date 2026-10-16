import 'package:hive_flutter/hive_flutter.dart';
import '../domain/sudoku_board.dart';
import '../domain/variant.dart';

/// One auto-save slot per variant.
class SudokuSaveService {
  SudokuSaveService._();
  static final SudokuSaveService instance = SudokuSaveService._();

  static const _boxName = 'sudoku_save';
  late Box _box;

  Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  Future<void> save(SudokuBoard board) async {
    await _box.put(board.variant.index.toString(), board.toJsonString());
  }

  SudokuBoard? load(SudokuVariant variant) {
    final raw = _box.get(variant.index.toString()) as String?;
    if (raw == null) return null;
    try {
      return SudokuBoard.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(SudokuVariant variant) async {
    await _box.delete(variant.index.toString());
  }

  bool hasSave(SudokuVariant variant) =>
      _box.containsKey(variant.index.toString());
}
