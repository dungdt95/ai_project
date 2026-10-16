# PLAN — Sudoku (Game #2)

> Game thứ 2 của Game Hub. Plug vào kiến trúc GameModule có sẵn (xem `PLAN.md` tổng và `lib/core/game_module.dart`). Tái sử dụng `SettingsService`, `AudioService`, theme, routing và Hive layer.

---

## 1. Phạm vi (scope)

### Variants
| Variant | Mô tả | Constraint thêm |
|---|---|---|
| **Classic 9x9** | Luật chuẩn: mỗi hàng/cột/box 3x3 chứa 1–9 không trùng | — |
| **Killer Sudoku** | Classic + chia bảng thành các "cage", tổng các ô trong cage = số cho trước, không trùng số trong cage | Cage sum, no-repeat-in-cage |
| **X-Sudoku** | Classic + hai đường chéo chính cũng phải chứa 1–9 không trùng | 2 diagonals |

### Difficulty (4 mức)
| Mức | Số ô cho sẵn | Kỹ thuật cần | Generator effort |
|---|---|---|---|
| Easy | ~40 | Naked Singles | Nhanh |
| Medium | ~32 | + Hidden Singles, Locked Candidates | Vừa |
| Hard | ~28 | + Naked/Hidden Pairs, Pointing | Chậm |
| Expert | ~24 | + X-Wing, Naked Triples | Chậm + cần solver mạnh |

### Nguồn puzzle
- **Algorithmic generator**: sinh full board (backtracking + random) → loại bỏ ô đảm bảo unique solution → rate difficulty bằng logical solver.
- **Daily puzzle**: seed sinh từ `YYYY-MM-DD` → cùng puzzle cho mọi user, hỗ trợ streak.
- Không bundled pack, không API ngoài.

### Tính năng
- ✅ Notes/pencil marks (ghi nhiều số nhỏ)
- ✅ Auto-check + highlight conflicts (đỏ ô sai, sáng cùng hàng/cột/box, sáng cùng số)
- ✅ Hint system: 3 hints/ván, dùng logical solver gợi ô kế tiếp
- ✅ Undo/Redo (không giới hạn) + Timer + Save/Resume (auto-save state)
- ✅ Input UI: cả **Number pad bottom** lẫn **Popup keypad** (toggle trong settings)
- ✅ Per-variant + per-difficulty stats
- ✅ Daily puzzle streak (đếm ngày liên tiếp giải xong daily)
- ✅ History + replay (lưu mọi ván hoàn thành, xem lại move-by-move)
- ✅ Achievements/badges
- ❌ Multiplayer (single-player only)

---

## 2. Kiến trúc thư mục

```
lib/games/sudoku/
├── sudoku_game.dart                # GameModule impl
├── domain/
│   ├── cell.dart                   # Cell: value, notes(Set<int>), isGiven, isError
│   ├── sudoku_board.dart           # 9x9 + history + currentSelection
│   ├── variant.dart                # enum + variant-specific data (cages, diagonals)
│   ├── killer_cage.dart            # cage: cells + sum
│   ├── move.dart                   # Move: position, oldValue/notes, newValue/notes
│   └── rules.dart                  # Validation per variant
├── solver/
│   ├── backtrack_solver.dart       # Brute-force solver (uniqueness check)
│   ├── logical_solver.dart         # Step-by-step technique solver (cho hint + difficulty rating)
│   ├── techniques/
│   │   ├── naked_single.dart
│   │   ├── hidden_single.dart
│   │   ├── locked_candidates.dart
│   │   ├── naked_pair.dart
│   │   ├── hidden_pair.dart
│   │   ├── x_wing.dart
│   │   └── technique.dart          # Abstract Technique interface
│   ├── generator.dart              # Sinh puzzle theo difficulty
│   └── daily_seed.dart             # Daily puzzle deterministic generator
├── data/
│   ├── sudoku_history_service.dart # Hive: completed puzzles
│   ├── sudoku_save_service.dart    # Hive: current in-progress state
│   ├── daily_streak_service.dart   # Hive: streak data
│   └── achievement_service.dart    # Hive: unlocked achievements
└── presentation/
    ├── sudoku_menu_screen.dart     # Variant + difficulty + daily + continue
    ├── sudoku_game_screen.dart     # Main game UI
    ├── sudoku_history_screen.dart  # List + replay
    ├── sudoku_stats_screen.dart    # Stats + streak + achievements
    ├── sudoku_game_notifier.dart   # StateNotifier
    ├── sudoku_settings_notifier.dart  # Input mode, auto-check toggle
    └── widgets/
        ├── sudoku_board_widget.dart    # 9x9 grid
        ├── sudoku_cell_widget.dart     # Single cell (value/notes/highlight)
        ├── number_pad.dart             # Bottom number pad
        ├── popup_keypad.dart           # Floating keypad at cell
        ├── timer_widget.dart
        ├── action_bar.dart             # Undo/Redo/Hint/Notes toggle/Erase
        └── cage_painter.dart           # CustomPainter for Killer cages
```

---

## 3. Thiết kế chi tiết

### 3.1 Domain

**Cell**
```dart
class Cell {
  final int? value;            // 1-9 or null
  final Set<int> notes;        // pencil marks
  final bool isGiven;          // initial clue, không sửa được
  final bool isError;          // auto-check flag (computed, not stored)
}
```

**SudokuBoard**
- Immutable 9x9 `List<List<Cell>>`
- `applyMove(Move m) → SudokuBoard` (return new board)
- `undo()`, `redo()` qua move history
- `Variant variant`, `List<KillerCage>? cages`, `bool xDiagonals`

**CaroRules tương đương** trong `rules.dart`:
- `isLegal(board, pos, value)` — check row/col/box conflict (+ cage/diagonal nếu variant)
- `isComplete(board)` — full & valid
- `conflictingCells(board, pos)` — set ô đang xung đột với pos (cho auto-check highlight)

### 3.2 Solver/Generator

**Backtrack solver**: tìm 1 solution → dùng để verify uniqueness (đếm ≥2 solutions thì stop).

**Logical solver**: chain các Technique theo thứ tự độ khó:
1. `NakedSingle` (Easy)
2. `HiddenSingle` (Easy)
3. `LockedCandidates` (Medium)
4. `NakedPair`, `HiddenPair` (Hard)
5. `XWing`, `NakedTriple` (Expert)

Mỗi technique trả về `TechniqueResult { Position pos, int value, String description }` để dùng cho **Hint** ("Ô (3,5) là 7 vì chỉ ô này có thể là 7 trong box 4 — Hidden Single").

**Generator algorithm**:
```
1. Sinh full valid board (random backtracking)
2. Cho difficulty target → tính số ô cần remove
3. Loop: pick random ô filled, remove, check uniqueness (backtrack count ≤ 1)
   → giữ nếu unique, restore nếu không
4. Sau khi remove đủ → rate difficulty bằng logical solver
5. Nếu mismatch level → discard + retry (max 5 attempts)
```

Mục tiêu: < 2s sinh xong 1 puzzle Hard, < 5s cho Expert (dùng Isolate).

**Daily seed**:
```dart
final seed = DateTime.now().toUtc().toIso8601String().substring(0, 10).hashCode;
final rng = Random(seed);
// generator dùng rng cố định → cùng puzzle cho mọi user trong cùng ngày
```

### 3.3 Variant logic

**Classic**: chỉ row/col/box.

**Killer**:
- Sinh cages: chia bảng thành cages 2–5 ô liền kề (BFS từ ô chưa thuộc cage)
- Mỗi cage có `sum = sum(values trong cage)` và rule "không lặp số trong cage"
- Generator phải chạy sau khi có full board (để biết sum)

**X-Sudoku**:
- Thêm 2 diagonals vào tập constraints
- Generator/solver chỉ cần thêm 2 `Region` (diagonal NE-SW, NW-SE)

### 3.4 Presentation

**`sudoku_menu_screen`**
- Cards cho 3 variants
- Mỗi card: chọn difficulty (chips) + nút "Bắt đầu"
- Banner "Daily Puzzle" trên cùng (1 nút cho cả 3 variants, mặc định Classic)
- Nút "Tiếp tục" nếu có save game (auto-detect qua `sudoku_save_service`)

**`sudoku_game_screen`**
- Layout dọc: Timer + variant label / Board / Action bar (Undo/Redo/Notes/Hint/Erase) / Number pad
- Tap cell → highlight cell + cùng số (peers + same value)
- Tap số → fill value hoặc notes (tùy Notes toggle)
- Long-press cell → popup keypad (nếu chọn popup mode)
- Hoàn thành puzzle → dialog: time/streak/Next puzzle/Về menu

**`sudoku_board_widget`**
- 9x9 GridView hoặc CustomMultiChildLayout
- Box borders đậm hơn (3 lines), cell borders mỏng
- Cho Killer: overlay CustomPainter vẽ cage outlines dashed + sum number ở góc top-left mỗi cage
- Cho X-Sudoku: tô nền nhẹ 2 đường chéo

**`sudoku_cell_widget`**
- Hiển thị value (lớn, đen) hoặc grid 3x3 notes (số nhỏ xám)
- Background: white | selected (blue) | same-peer (blue nhạt) | same-value (xanh lá nhạt) | error (đỏ)
- Given cells: bold đen, không sửa được

**`number_pad`** (bottom mode)
- 9 nút số + nút Erase + nút Notes toggle
- Badge nhỏ trên mỗi số: hiển thị số ô còn lại cần điền số đó (count remaining)
- Số đã đủ 9 ô → disable

**`popup_keypad`** (popup mode)
- 3x3 grid số float lên trên ô được tap
- Tap số → đóng popup
- Tap ngoài → đóng

### 3.5 Data persistence (Hive)

**Boxes**:
- `sudoku_save` — `Map<variant, savedGameJson>` (1 save slot mỗi variant)
- `sudoku_history` — completed games: id, variant, difficulty, duration, moves, completedAt
- `sudoku_streak` — `{lastDailyDate, currentStreak, longestStreak}`
- `sudoku_achievements` — Set<achievementId>

**Auto-save**: mỗi move trigger save (debounce 1s) → resume seamless.

### 3.6 Achievements (initial set)

| ID | Tên | Điều kiện |
|---|---|---|
| `first_win` | Tân binh | Hoàn thành puzzle đầu tiên |
| `easy_master` | Khởi đầu thuận lợi | 10 Easy classic |
| `expert_5` | Cao thủ Expert | 5 Expert (mọi variant) |
| `no_mistakes` | Tinh mắt | Hoàn thành 1 puzzle không sai ô nào |
| `no_hints` | Tự lực | Hoàn thành 1 Hard+ không dùng hint |
| `streak_7` | Tuần lễ vàng | Daily streak 7 ngày |
| `streak_30` | Bền bỉ | Daily streak 30 ngày |
| `speed_demon` | Tốc độ | Hoàn thành Easy < 3 phút |
| `killer_first` | Sát thủ | Hoàn thành Killer đầu tiên |
| `x_first` | Chéo cánh | Hoàn thành X-Sudoku đầu tiên |
| `all_variants` | Đa di năng | Hoàn thành cả 3 variants ở mọi difficulty |

---

## 4. Routing

Thêm vào `lib/app.dart`:
```
/sudoku                   → SudokuMenuScreen
/sudoku/game              → SudokuGameScreen
/sudoku/history           → SudokuHistoryScreen
/sudoku/history/:id       → SudokuReplayScreen
/sudoku/stats             → SudokuStatsScreen
```

Đăng ký `SudokuGame()` trong `main.dart` `_registerGames()`.

---

## 5. Audio assets

Tái dụng pattern Caro, thêm vào `assets/audio/`:
- `sudoku_place.mp3` — đặt số
- `sudoku_note.mp3` — ghi note
- `sudoku_error.mp3` — sai
- `sudoku_complete.mp3` — hoàn thành
- `sudoku_achievement.mp3` — unlock achievement

Khởi tạo silent placeholder y như Caro (xem `assets/audio/move.mp3`).

---

## 6. Testing

Unit tests (target ≥ 30 cases):
- `rules_test.dart` — Classic/Killer/X validation, conflict detection
- `backtrack_solver_test.dart` — solve correctness + uniqueness
- `logical_solver_test.dart` — mỗi technique cho board mẫu
- `generator_test.dart` — sinh ra puzzle đúng uniqueness, đúng difficulty range (smoke ≥ 5 puzzles/level)
- `daily_seed_test.dart` — cùng date → cùng puzzle
- `cell_notes_test.dart` — notes add/remove/clear
- `cage_validation_test.dart` — Killer sum constraint

Widget tests:
- Cell highlight states render đúng
- Number pad disable đúng số
- Popup keypad mở/đóng

---

## 7. Sprint roadmap (~2.5 tuần)

### Sprint 1: Domain + Solver core (3 ngày)
- Cell, SudokuBoard, Move, Variant enum
- Rules cho Classic (row/col/box validation, conflict detection)
- Backtrack solver + uniqueness check
- Logical solver: Naked Single, Hidden Single
- Unit tests pass

### Sprint 2: Generator + Difficulty (3 ngày)
- Generator Classic: sinh full board → remove cells
- Difficulty rater dùng logical solver
- Thêm techniques: Locked Candidates, Naked/Hidden Pairs
- Daily seed
- Sinh < 5s cho Expert (chạy trong Isolate)

### Sprint 3: UI cơ bản (3 ngày)
- SudokuBoardWidget + CellWidget với highlight states
- NumberPad bottom
- Game notifier: tap cell, place value, notes, undo/redo, timer
- Auto-check + conflict highlighting
- Menu screen + game screen

### Sprint 4: Hint + Save/Resume + Variants (3 ngày)
- Hint dùng logical solver, animation highlight ô gợi ý
- Auto-save với debounce → resume
- X-Sudoku variant (chỉ thêm constraints)
- Popup keypad mode + settings toggle

### Sprint 5: Killer Sudoku (2 ngày)
- KillerCage domain + cage generator
- CagePainter (dashed outline + sum number)
- Logical solver mở rộng cho cage rules

### Sprint 6: Stats + History + Achievements (2 ngày)
- HistoryService + ReplayScreen (re-render move-by-move)
- StatsScreen (per-variant + per-difficulty breakdown)
- Daily streak tracking
- Achievement engine + unlock toasts

### Sprint 7: Polish (1 ngày)
- Audio, haptic
- Loading states (generator), error handling
- Empty states cho history/stats
- Manual test trên emulator: Classic + Killer + X, 4 difficulties, daily, achievements

---

## 8. Định nghĩa hoàn thành (DoD)

- [ ] `flutter analyze` — 0 errors
- [ ] `flutter test` — toàn bộ pass (Caro 17 cũ + Sudoku mới)
- [ ] Chơi được Classic 9x9 cả 4 difficulty
- [ ] Killer Sudoku: cage hiển thị đúng, sum constraint hoạt động
- [ ] X-Sudoku: 2 diagonals enforced
- [ ] Generator sinh puzzle Hard < 2s, Expert < 5s (P95)
- [ ] Daily puzzle cùng kết quả cho 2 lần chạy trong cùng ngày
- [ ] Hint hiển thị ô đúng + giải thích technique
- [ ] Auto-save → kill app → mở lại "Tiếp tục" khôi phục đúng state
- [ ] Undo/Redo qua mọi move (kể cả notes)
- [ ] Highlight: cùng peer, cùng value, error — đúng trạng thái
- [ ] Streak tăng đúng khi giải daily, reset khi bỏ ngày
- [ ] Achievements unlock đúng điều kiện + toast hiển thị

---

## 9. Rủi ro & mitigations

| Rủi ro | Mitigation |
|---|---|
| Generator Expert chậm (> 10s) | Cache pool ~50 puzzles/level sinh nền (Isolate idle), pop ra khi user chọn |
| Logical solver thiếu kỹ thuật cho Expert | Fallback: rate bằng số backtrack steps; chấp nhận đôi khi Expert thực ra phải đoán 1 chỗ |
| Killer cage UI vẽ phức tạp | Dùng `path.computeMetrics` + dashed PathEffect; nếu khó, fallback solid outline mỏng |
| Save/resume conflict với daily (đổi ngày giữa chừng) | Save có timestamp + variant + isDaily flag; nếu mở lại sau nửa đêm → vẫn cho tiếp ván cũ, daily mới là 1 entry riêng |
| Auto-check spoil người chơi muốn tự kiểm tra | Toggle trong settings (mặc định ON) |

---

## 10. Cấu trúc plan này tương quan với Caro

| Aspect | Caro | Sudoku |
|---|---|---|
| Domain core | Board 15x15 + moves | Board 9x9 + cells với notes |
| AI/Engine | 4 AI engines | Backtrack + Logical solver + Generator |
| Network | LAN TCP | Không |
| Persistence | History only | History + Save + Streak + Achievements |
| UI complexity | Trung bình (1 board + actions) | Cao (board + cells phức tạp + 2 input modes) |
| Variants | 1 | 3 |
| Effort | ~3 tuần (đã xong) | ~2.5 tuần |
