import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SudokuSettings {
  const SudokuSettings({
    this.notesMode = false,
    this.autoCheck = true,
    this.popupInput = false,
  });

  final bool notesMode;
  final bool autoCheck;
  final bool popupInput;

  SudokuSettings copyWith({bool? notesMode, bool? autoCheck, bool? popupInput}) =>
      SudokuSettings(
        notesMode: notesMode ?? this.notesMode,
        autoCheck: autoCheck ?? this.autoCheck,
        popupInput: popupInput ?? this.popupInput,
      );
}

final sudokuSettingsProvider =
    StateNotifierProvider<SudokuSettingsNotifier, SudokuSettings>(
  (_) => SudokuSettingsNotifier(),
);

class SudokuSettingsNotifier extends StateNotifier<SudokuSettings> {
  SudokuSettingsNotifier() : super(const SudokuSettings()) {
    _load();
  }

  static const _boxName = 'sudoku_settings';

  Future<void> _load() async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    state = SudokuSettings(
      notesMode: box.get('notesMode', defaultValue: false) as bool,
      autoCheck: box.get('autoCheck', defaultValue: true) as bool,
      popupInput: box.get('popupInput', defaultValue: false) as bool,
    );
  }

  Future<void> toggleNotes() => _set(state.copyWith(notesMode: !state.notesMode));
  Future<void> toggleAutoCheck() => _set(state.copyWith(autoCheck: !state.autoCheck));
  Future<void> togglePopupInput() => _set(state.copyWith(popupInput: !state.popupInput));
  Future<void> setNotesMode(bool v) => _set(state.copyWith(notesMode: v));

  Future<void> _set(SudokuSettings s) async {
    state = s;
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    await box.putAll({
      'notesMode': s.notesMode,
      'autoCheck': s.autoCheck,
      'popupInput': s.popupInput,
    });
  }
}
