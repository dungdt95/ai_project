import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/audio/audio_service.dart';
import '../data/achievement_service.dart';
import '../data/daily_streak_service.dart';
import '../data/sudoku_history_service.dart';
import '../data/sudoku_save_service.dart';
import '../domain/cell.dart';
import '../domain/rules.dart';
import '../domain/sudoku_board.dart';
import '../domain/sudoku_pos.dart';
import '../domain/variant.dart';
import '../solver/daily_seed.dart';
import '../solver/generator.dart';
import 'sudoku_settings_notifier.dart';

class SudokuGameState {
  const SudokuGameState({
    this.board,
    this.isGenerating = false,
    this.selectedPos,
    this.errorCells = const {},
    this.undoStack = const [],
    this.redoStack = const [],
    this.elapsed = Duration.zero,
    this.isComplete = false,
    this.hintPos,
    this.hintsUsed = 0,
    this.mistakeCount = 0,
    this.newAchievements = const [],
    this.gameId,
    this.startedAt,
  });

  final SudokuBoard? board;
  final bool isGenerating;
  final SudokuPos? selectedPos;
  final Set<SudokuPos> errorCells;
  final List<SudokuBoard> undoStack;
  final List<SudokuBoard> redoStack;
  final Duration elapsed;
  final bool isComplete;
  final SudokuPos? hintPos;
  final int hintsUsed;
  final int mistakeCount;
  final List<SudokuAchievement> newAchievements;
  final String? gameId;
  final DateTime? startedAt;

  static const maxHints = 3;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get canHint => hintsUsed < maxHints && !isComplete && board != null;

  SudokuGameState copyWith({
    SudokuBoard? board,
    bool? isGenerating,
    SudokuPos? selectedPos,
    bool clearSelected = false,
    Set<SudokuPos>? errorCells,
    List<SudokuBoard>? undoStack,
    List<SudokuBoard>? redoStack,
    Duration? elapsed,
    bool? isComplete,
    SudokuPos? hintPos,
    bool clearHint = false,
    int? hintsUsed,
    int? mistakeCount,
    List<SudokuAchievement>? newAchievements,
    String? gameId,
    DateTime? startedAt,
  }) =>
      SudokuGameState(
        board: board ?? this.board,
        isGenerating: isGenerating ?? this.isGenerating,
        selectedPos:
            clearSelected ? null : (selectedPos ?? this.selectedPos),
        errorCells: errorCells ?? this.errorCells,
        undoStack: undoStack ?? this.undoStack,
        redoStack: redoStack ?? this.redoStack,
        elapsed: elapsed ?? this.elapsed,
        isComplete: isComplete ?? this.isComplete,
        hintPos: clearHint ? null : (hintPos ?? this.hintPos),
        hintsUsed: hintsUsed ?? this.hintsUsed,
        mistakeCount: mistakeCount ?? this.mistakeCount,
        newAchievements: newAchievements ?? this.newAchievements,
        gameId: gameId ?? this.gameId,
        startedAt: startedAt ?? this.startedAt,
      );
}

final sudokuGameProvider =
    StateNotifierProvider<SudokuGameNotifier, SudokuGameState>(
  (ref) => SudokuGameNotifier(ref),
);

class SudokuGameNotifier extends StateNotifier<SudokuGameState> {
  SudokuGameNotifier(this._ref) : super(const SudokuGameState());

  final Ref _ref;
  Timer? _timer;
  Timer? _saveDebounce;
  final _audio = AudioService.instance;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> startNew({
    required SudokuVariant variant,
    required SudokuDifficulty difficulty,
    bool isDaily = false,
  }) async {
    _stopTimer();
    state = state.copyWith(isGenerating: true, isComplete: false);

    final seed = isDaily ? todaysDailySeed() : DateTime.now().millisecondsSinceEpoch;

    final output = await compute(
      generatePuzzle,
      GeneratorParams(
        variant: variant.index,
        difficulty: difficulty.index,
        seed: seed,
      ),
    );

    final cells = List.generate(
      9,
      (r) => List.generate(
        9,
        (c) {
          final v = output.given[r][c];
          return Cell(value: v, isGiven: v != null);
        },
      ),
    );

    final board = SudokuBoard(
      cells: cells,
      solution: output.solution,
      variant: variant,
      difficulty: difficulty,
      cages: output.cages,
      isDaily: isDaily,
    );

    state = SudokuGameState(
      board: board,
      isGenerating: false,
      gameId: const Uuid().v4(),
      startedAt: DateTime.now(),
    );
    _startTimer();
    _scheduleSave();
  }

  Future<void> resume(SudokuVariant variant) async {
    final saved = SudokuSaveService.instance.load(variant);
    if (saved == null) return;
    state = SudokuGameState(
      board: saved,
      gameId: const Uuid().v4(),
      startedAt: DateTime.now(),
    );
    _startTimer();
  }

  void selectCell(int row, int col) {
    if (state.isComplete) return;
    final cur = state.selectedPos;
    if (cur != null && cur.row == row && cur.col == col) {
      state = state.copyWith(clearSelected: true);
    } else {
      state = state.copyWith(selectedPos: SudokuPos(row, col));
    }
  }

  void placeValue(int value, {bool notesMode = false}) {
    final board = state.board;
    final pos = state.selectedPos;
    if (board == null || pos == null || state.isComplete) return;
    final cell = board.cellAt(pos.row, pos.col);
    if (cell.isGiven) return;

    final settings = _ref.read(sudokuSettingsProvider);
    final isNotes = notesMode || settings.notesMode;

    final SudokuBoard newBoard;
    if (isNotes) {
      final notes = Set<int>.from(cell.notes);
      if (notes.contains(value)) {
        notes.remove(value);
      } else {
        notes.add(value);
      }
      newBoard = board.withCell(pos.row, pos.col, cell.copyWith(notes: notes, clearValue: true));
      _audio.playMove();
    } else {
      if (cell.value == value) return; // no change
      newBoard = board.withCell(pos.row, pos.col, cell.copyWith(value: value, notes: const {}));
      _audio.playMove();
      HapticFeedback.lightImpact();
    }

    final errors = _computeErrors(newBoard);
    final newMistakes = !isNotes && errors.contains(pos)
        ? state.mistakeCount + 1
        : state.mistakeCount;

    state = state.copyWith(
      board: newBoard,
      undoStack: [...state.undoStack, board],
      redoStack: [],
      errorCells: errors,
      mistakeCount: newMistakes,
      clearHint: true,
    );

    if (newBoard.isSolved) {
      _onComplete(newBoard);
    } else if (!isNotes) {
      // Remove pencil marks from peers when a value is placed.
      _eliminatePeerNotes(newBoard, pos, value);
    }

    _scheduleSave();
  }

  void erase() {
    final board = state.board;
    final pos = state.selectedPos;
    if (board == null || pos == null || state.isComplete) return;
    final cell = board.cellAt(pos.row, pos.col);
    if (cell.isGiven) return;
    if (cell.value == null && cell.notes.isEmpty) return;

    final newBoard = board.withCell(
      pos.row, pos.col,
      const Cell(),
    );
    state = state.copyWith(
      board: newBoard,
      undoStack: [...state.undoStack, board],
      redoStack: [],
      errorCells: _computeErrors(newBoard),
      clearHint: true,
    );
    _scheduleSave();
  }

  void undo() {
    if (!state.canUndo) return;
    final prev = state.undoStack.last;
    state = state.copyWith(
      board: prev,
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [if (state.board != null) state.board!, ...state.redoStack],
      errorCells: _computeErrors(prev),
      clearHint: true,
    );
    _scheduleSave();
  }

  void redo() {
    if (!state.canRedo) return;
    final next = state.redoStack.first;
    state = state.copyWith(
      board: next,
      undoStack: [...state.undoStack, if (state.board != null) state.board!],
      redoStack: state.redoStack.sublist(1),
      errorCells: _computeErrors(next),
      clearHint: true,
    );
    _scheduleSave();
  }

  Future<void> requestHint() async {
    final board = state.board;
    if (!state.canHint || board == null) return;

    final grid = board.toGrid();
    // Remove wrong values so solver can work on a clean grid.
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board.cells[r][c].value != null &&
            board.cells[r][c].value != board.solution[r][c]) {
          grid[r][c] = null;
        }
      }
    }

    final result = await compute(
      _computeHint,
      _HintParams(
        grid: grid,
        solution: board.solution,
        variant: board.variant.index,
      ),
    );

    if (result != null && mounted) {
      state = state.copyWith(
        hintPos: SudokuPos(result.row, result.col),
        hintsUsed: state.hintsUsed + 1,
      );
    }
  }

  void clearNewAchievements() {
    state = state.copyWith(newAchievements: []);
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) state = state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });
  }

  void _stopTimer() => _timer?.cancel();

  void pauseTimer() => _stopTimer();
  void resumeTimer() => _startTimer();

  // ── Game completion ───────────────────────────────────────────────────────

  void _onComplete(SudokuBoard board) {
    _stopTimer();
    _audio.playWin();
    HapticFeedback.heavyImpact();

    state = state.copyWith(
      isComplete: true,
      errorCells: {},
    );

    _saveRecord(board);
    SudokuSaveService.instance.clear(board.variant);
  }

  Future<void> _saveRecord(SudokuBoard board) async {
    final record = SudokuGameRecord(
      id: state.gameId ?? const Uuid().v4(),
      variant: board.variant,
      difficulty: board.difficulty,
      duration: state.elapsed,
      completedAt: DateTime.now(),
      moves: const [],
      mistakeCount: state.mistakeCount,
      hintsUsed: state.hintsUsed,
      isDaily: board.isDaily,
    );

    await SudokuHistoryService.instance.save(record);

    if (board.isDaily) {
      await DailyStreakService.instance.onDailyCompleted(DateTime.now());
    }

    final stats = SudokuHistoryService.instance.computeStats();
    final streak = DailyStreakService.instance.currentStreak;
    final newAch = await AchievementService.instance.checkAfterGame(
      record: record,
      stats: stats,
      currentStreak: streak,
    );
    if (newAch.isNotEmpty && mounted) {
      state = state.copyWith(newAchievements: newAch);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Set<SudokuPos> _computeErrors(SudokuBoard board) {
    if (!_ref.read(sudokuSettingsProvider).autoCheck) return {};
    final errors = <SudokuPos>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = board.cells[r][c].value;
        if (v != null && v != board.solution[r][c]) {
          errors.add(SudokuPos(r, c));
        }
      }
    }
    return errors;
  }

  void _eliminatePeerNotes(SudokuBoard board, SudokuPos pos, int value) {
    var current = board;
    final peers = SudokuRules.peersOf(
        pos.row, pos.col, board.variant, board.cages);
    for (final p in peers) {
      final cell = current.cellAt(p.row, p.col);
      if (cell.notes.contains(value)) {
        current = current.withCell(
          p.row, p.col,
          cell.copyWith(notes: Set<int>.from(cell.notes)..remove(value)),
        );
      }
    }
    if (current != board) {
      state = state.copyWith(
        board: current,
        errorCells: _computeErrors(current),
      );
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), () {
      final board = state.board;
      if (board != null && !state.isComplete) {
        SudokuSaveService.instance.save(board);
      }
    });
  }

  @override
  void dispose() {
    _stopTimer();
    _saveDebounce?.cancel();
    super.dispose();
  }
}

// ── Isolate helpers ───────────────────────────────────────────────────────────

class _HintParams {
  const _HintParams({required this.grid, required this.solution, required this.variant});
  final List<List<int?>> grid;
  final List<List<int>> solution;
  final int variant;
}

class _HintResult {
  const _HintResult({required this.row, required this.col});
  final int row, col;
}

_HintResult? _computeHint(_HintParams p) {
  // Find first empty cell that doesn't match solution yet (use solution directly).
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (p.grid[r][c] == null) {
        return _HintResult(row: r, col: c);
      }
    }
  }
  return null;
}
