# Game Hub - Kế hoạch xây dựng app mobile chơi game

> File này được dùng làm **prompt input** cho AI sinh code (Claude Code, Cursor, v.v.). Đọc kỹ toàn bộ trước khi triển khai.

---

## 1. Tổng quan

**Tên dự án (tạm):** `game_hub`

**Mô tả:** Một app mobile (Android + iOS) đóng vai trò "trung tâm game" — quản lý và chạy nhiều mini-game do người phát triển tự viết. App được thiết kế theo **plugin/module pattern** để dễ dàng thêm game mới mà không phải sửa core.

**Game đầu tiên:** Cờ Caro (luật Việt Nam) — chơi với máy 4 cấp độ + chơi 2 người qua LAN.

**Đối tượng người dùng:** Người chơi giải trí trên điện thoại, không cần tài khoản, không cần internet.

---

## 2. Mục tiêu sản phẩm

### Mục tiêu chính
1. Có 1 launcher (màn hình chính) liệt kê các game đã cài sẵn, mỗi game là 1 ô bấm vào để chơi.
2. Game đầu tiên (Cờ Caro) hoạt động đầy đủ với các chế độ: **vs AI (4 cấp độ)**, **vs Người (LAN cùng Wi-Fi)**.
3. Kiến trúc cho phép developer thêm game mới chỉ bằng cách viết 1 module mới implement interface `GameModule`, không sửa code core.

### Mục tiêu phi chức năng
- Hoạt động offline hoàn toàn (trừ phần LAN cần cùng mạng Wi-Fi).
- AI cấp "Siêu khó" phải ra nước đi trong **≤ 2 giây** trên thiết bị tầm trung (Snapdragon 6xx trở lên).
- App khởi động ≤ 2 giây.
- Hỗ trợ Việt + Anh, theme sáng/tối.
- Không thu thập dữ liệu người dùng.

### Ngoài phạm vi (v1)
- Không có tài khoản người dùng, không cloud sync.
- Không có chế độ online qua server trung gian (chỉ LAN).
- Không có hệ thống mua trong app (IAP), không quảng cáo.

---

## 3. Tech Stack

| Hạng mục | Lựa chọn | Lý do |
|---|---|---|
| **Framework** | Flutter (Dart, SDK ≥ 3.x) | 1 codebase Android + iOS, UI mượt, hiệu năng cao cho game 2D. |
| **State management** | Riverpod (≥ 2.x) | Type-safe, dễ test, hỗ trợ tốt cho game state phức tạp. |
| **Routing** | go_router | Khai báo route rõ ràng, hỗ trợ deep link cho LAN join. |
| **Local storage** | Hive (key-value) + Drift (SQLite cho lịch sử) | Hive cho settings nhanh, Drift cho query lịch sử ván đấu. |
| **Networking LAN** | `dart:io` Socket (TCP) + `network_info_plus` + `qr_flutter` / `mobile_scanner` | Host mở TCP server, client join qua IP hoặc QR. |
| **i18n** | `flutter_localizations` + `intl` + ARB files | Chuẩn Flutter, dễ thêm ngôn ngữ. |
| **Audio** | `audioplayers` | Nhẹ, đủ dùng cho hiệu ứng đánh cờ. |
| **Haptic** | `flutter`/`HapticFeedback` (built-in) | Không cần package ngoài. |
| **Testing** | `flutter_test` (unit + widget), `integration_test` | AI engine và checkWin phải có test kỹ. |

**Lưu ý:** Tất cả package phải dùng phiên bản stable mới nhất tại thời điểm code; tránh package bỏ rơi (last update > 1 năm).

---

## 4. Kiến trúc tổng thể

### 4.1 Sơ đồ tầng
```
┌──────────────────────────────────────────────┐
│              UI Layer (Flutter)              │
│  - HomeScreen (game launcher)                │
│  - SettingsScreen                            │
│  - GameScreen (host các game module)         │
└──────────────────────────────────────────────┘
                      │
┌──────────────────────────────────────────────┐
│         Core Framework (game_core)           │
│  - GameModule interface                      │
│  - GameRegistry (đăng ký game)               │
│  - GameSession (vòng đời 1 ván)              │
│  - Storage / Settings / i18n / Audio / Theme │
└──────────────────────────────────────────────┘
                      │
┌──────────────────────────────────────────────┐
│          Game Modules (plug-in)              │
│  - caro/    (game đầu tiên)                  │
│  - chess/   (tương lai)                      │
│  - sudoku/  (tương lai)                      │
└──────────────────────────────────────────────┘
```

### 4.2 Interface `GameModule`
Mỗi game phải implement interface sau (Dart pseudo-code):

```dart
abstract class GameModule {
  /// Định danh duy nhất, dùng cho routing và lưu trữ
  String get id;                 // ví dụ: "caro"

  /// Tên hiển thị (key trong i18n)
  String get nameKey;            // ví dụ: "game.caro.name"

  /// Icon hiển thị trên launcher
  Widget buildIcon(BuildContext context);

  /// Mô tả ngắn (key i18n)
  String get descriptionKey;

  /// Màn hình chính của game (chứa menu chọn chế độ, settings game...)
  Widget buildEntryScreen(BuildContext context);

  /// (Tuỳ chọn) Danh sách màn settings riêng của game
  List<Widget> buildSettingsPanels(BuildContext context) => const [];

  /// (Tuỳ chọn) Initialize tài nguyên (sound, model AI...) khi app khởi động
  Future<void> onAppStart() async {}
}
```

### 4.3 `GameRegistry`
- Singleton chứa danh sách `GameModule` đã đăng ký.
- Đăng ký ở `main()` hoặc qua 1 file `registered_games.dart` để dễ thêm/bớt.

```dart
void registerGames() {
  GameRegistry.instance.register(CaroGame());
  // GameRegistry.instance.register(ChessGame());  // tương lai
}
```

### 4.4 Cấu trúc thư mục
```
game_hub/
├── lib/
│   ├── main.dart
│   ├── app.dart                          # MaterialApp + router
│   ├── core/
│   │   ├── game_module.dart              # interface
│   │   ├── game_registry.dart
│   │   ├── theme/
│   │   ├── i18n/
│   │   ├── storage/                      # Hive + Drift wrapper
│   │   ├── audio/
│   │   └── widgets/                      # nút, dialog dùng chung
│   ├── features/
│   │   ├── home/                         # launcher
│   │   ├── settings/                     # settings chung
│   │   └── stats/                        # thống kê tổng
│   └── games/
│       └── caro/
│           ├── caro_game.dart            # implements GameModule
│           ├── domain/
│           │   ├── board.dart            # state bàn cờ
│           │   ├── rules.dart            # luật caro VN
│           │   └── move.dart
│           ├── ai/
│           │   ├── ai_engine.dart        # interface AI
│           │   ├── easy_ai.dart
│           │   ├── medium_ai.dart
│           │   ├── hard_ai.dart
│           │   └── super_ai.dart         # threat-space search
│           ├── network/
│           │   ├── lan_host.dart
│           │   ├── lan_client.dart
│           │   └── protocol.dart         # định nghĩa packet
│           ├── presentation/
│           │   ├── caro_menu_screen.dart
│           │   ├── caro_game_screen.dart
│           │   ├── caro_lan_lobby_screen.dart
│           │   └── widgets/
│           │       ├── board_widget.dart
│           │       └── stone_widget.dart
│           └── data/
│               └── caro_history_dao.dart
├── assets/
│   ├── images/
│   ├── audio/
│   └── translations/
│       ├── app_vi.arb
│       └── app_en.arb
├── test/
│   ├── core/
│   └── games/caro/
│       ├── rules_test.dart
│       ├── ai_engine_test.dart
│       └── ...
└── pubspec.yaml
```

---

## 5. Game đầu tiên: Cờ Caro

### 5.1 Luật chơi (Caro Việt Nam)
- Bàn cờ: **15 × 15** ô.
- 2 người chơi: **X** (đi trước) và **O**.
- Ai tạo được **đúng 5 quân liên tiếp** (ngang/dọc/chéo) và **không bị quân đối thủ chặn cả 2 đầu** thì thắng.
- Chuỗi 6 quân trở lên **không tính thắng** (theo luật VN).
- Hết ô mà không ai thắng → hoà.

### 5.2 Màn hình & Flow
1. **HomeScreen** → tap ô "Cờ Caro" → **CaroMenuScreen**
2. **CaroMenuScreen** chứa các nút:
   - Chơi với máy → chọn cấp độ (Dễ / Vừa / Khó / Siêu khó) → chọn quân (X/O/Random) → **CaroGameScreen**
   - Chơi với người (LAN) → **CaroLanLobbyScreen** (chọn "Tạo phòng" hoặc "Tham gia")
   - Lịch sử / Thống kê
   - Cài đặt game (âm thanh, gợi ý, hiển thị toạ độ...)
3. **CaroGameScreen**:
   - Hiển thị bàn cờ 15×15 (pinch zoom + pan vì màn hình nhỏ).
   - Thanh trên: tên 2 bên + đồng hồ đếm thời gian từng nước (chỉ LAN).
   - Thanh dưới: nút **Undo** (chỉ vs AI), **Hint** (chỉ vs AI), **Đầu hàng**, **Ván mới**.
   - Khi thắng: highlight 5 quân thắng + dialog kết quả.

### 5.3 AI – 4 cấp độ

| Cấp | Thuật toán | Mô tả | Mục tiêu trình độ |
|---|---|---|---|
| **Dễ** | Random + ưu tiên ô cạnh quân vừa đánh | Đánh ngẫu nhiên trong vùng 2 ô quanh quân cuối; chặn nếu đối thủ có 4 liền. | Người mới chơi cũng thắng được. |
| **Vừa** | Heuristic 1-ply | Đánh giá điểm cho từng ô trống (đếm chuỗi mở/đóng), chọn ô tốt nhất. Có chặn 4 và 3 mở. | Người chơi trung bình thắng 50-70%. |
| **Khó** | Minimax + Alpha-Beta depth 4-6 | Chỉ xét các ô trong bán kính 2 quanh quân đã đặt. Heuristic chuỗi VCT/VCF cơ bản. | Người chơi khá thắng <30%. |
| **Siêu khó** | Minimax + Alpha-Beta + **Threat-Space Search** + Iterative deepening | Tìm chuỗi đe doạ (4-mở, 4-đóng, 3-mở...), VCF (victory by continuous fours), VCT (victory by continuous threats). Time-limited (≤2s/nước). | Đánh thắng người chơi giỏi, chấp nhận thua chuyên nghiệp. |

#### 5.3.1 Interface AI
```dart
abstract class AiEngine {
  /// Trả về nước đi tốt nhất cho `currentPlayer` trên `board`.
  /// `timeLimit` là deadline mềm — engine nên trả kết quả trong khoảng này.
  Future<Move> chooseMove(Board board, Player currentPlayer, Duration timeLimit);
}
```

#### 5.3.2 Heuristic chấm điểm cho chuỗi
| Mẫu | Tên | Điểm |
|---|---|---|
| `_XXXXX_` (5 liền không bị chặn) | Win | +∞ |
| `_XXXX_` | 4 mở | 10,000 |
| `XXXX_` hoặc `_XXXX` (chặn 1 đầu) | 4 đóng | 1,000 |
| `_XXX_` | 3 mở | 1,000 |
| `XXX__` / `__XXX` / `_XXX` | 3 đóng | 100 |
| `_XX_` | 2 mở | 100 |
| `_X_` | 1 | 10 |

Tổng điểm = điểm của AI − điểm của đối thủ (nhân hệ số phòng thủ 1.1).

#### 5.3.3 Tối ưu hiệu năng (cho "Siêu khó")
- Chỉ sinh nước đi trong **bán kính 2** quanh các quân đã đặt (đa số nước đáng cân nhắc).
- **Move ordering**: ưu tiên nước có heuristic cao trước → tăng cắt tỉa alpha-beta.
- **Zobrist hashing** + **transposition table** lưu trạng thái đã đánh giá.
- **Iterative deepening** kết hợp time limit: tăng độ sâu dần đến khi gần hết thời gian.
- Chạy AI trong **Isolate** (background thread) để không block UI.

### 5.4 LAN Multiplayer (peer-to-peer Wi-Fi)

#### 5.4.1 Mô hình
- **Host**: 1 thiết bị mở TCP server (port ngẫu nhiên trong dải 40000-50000).
- **Client**: kết nối tới IP của host.
- Cả 2 phải cùng Wi-Fi (cùng subnet).
- Không cần internet, không cần server trung gian.

#### 5.4.2 Cách kết nối
- **Host**: app hiển thị IP nội bộ (lấy bằng `network_info_plus`) + sinh QR code chứa `caro://{ip}:{port}/{roomId}`.
- **Client**:
  - Cách 1: nhập tay IP + port.
  - Cách 2: quét QR.
- (v1.1 có thể thêm mDNS auto-discovery.)

#### 5.4.3 Giao thức (JSON over TCP, mỗi message kết thúc bằng `\n`)
```json
// Client → Host khi vừa kết nối
{ "type": "hello", "name": "Player A", "version": 1 }

// Host → Client xác nhận
{ "type": "welcome", "yourSide": "O", "hostName": "Player B", "boardSize": 15 }

// Cả 2 chiều khi đánh nước
{ "type": "move", "row": 7, "col": 7, "moveNo": 1, "ts": 1735000000 }

// Khi có người thắng/đầu hàng
{ "type": "end", "result": "win|lose|draw|resign", "winningLine": [[7,7],...] }

// Heartbeat mỗi 5s
{ "type": "ping" }
{ "type": "pong" }

// Yêu cầu ván mới
{ "type": "rematch_request" }
{ "type": "rematch_accept" }
```

#### 5.4.4 Edge cases LAN
- Mất kết nối > 10s → hiển thị dialog "Mất kết nối", cho phép chờ reconnect hoặc thoát.
- Host thoát → client tự về lobby + thông báo.
- Race condition: cả 2 cùng nhấn cùng lúc → host là **source of truth** về thứ tự nước đi.
- Validation: mỗi nước nhận về phải verify (ô trống, đúng lượt) — chống cheat đơn giản.

### 5.5 Tính năng bổ sung (v1)

| Tính năng | Mô tả |
|---|---|
| **Lịch sử ván** | Lưu mọi ván (Drift/SQLite): chế độ, kết quả, danh sách nước đi, thời gian. |
| **Replay** | Mở 1 ván cũ → tua tới/lui từng nước. |
| **Thống kê** | Tổng số ván, tỉ lệ thắng theo chế độ, streak hiện tại. |
| **Undo** | Chỉ vs AI: rút lại 1 cặp nước (của người và AI). Tối đa 3 lần/ván. |
| **Hint** | Chỉ vs AI: dùng AI cấp Khó tính nước đề xuất, highlight ô gợi ý. Tối đa 3 lần/ván. |
| **Theme sáng/tối** | Tự động theo hệ thống + nút override trong settings. |
| **Âm thanh** | Tiếng đánh quân, tiếng thắng/thua. Bật/tắt trong settings. |
| **Haptic** | Rung nhẹ khi đánh, rung mạnh khi thắng/thua. |
| **i18n VI/EN** | ARB files, mặc định theo locale hệ thống. |

---

## 6. Data Models (chính)

```dart
enum Player { x, o }

class Position {
  final int row;   // 0..14
  final int col;   // 0..14
}

class Move {
  final Position pos;
  final Player player;
  final DateTime timestamp;
}

class Board {
  final int size;                       // 15
  final List<List<Player?>> cells;
  final List<Move> history;
  Player get currentTurn;
  GameStatus get status;                // playing | xWon | oWon | draw
  List<Position>? get winningLine;
}

enum GameMode { vsAiEasy, vsAiMedium, vsAiHard, vsAiSuper, vsHumanLan }

class GameRecord {                      // lưu vào DB
  final String id;
  final String gameId;                  // "caro"
  final GameMode mode;
  final String? opponentName;
  final GameResult result;
  final List<Move> moves;
  final DateTime startedAt;
  final Duration duration;
}
```

---

## 7. Lưu trữ local

- **Hive box `settings`**: theme, locale, sound on/off, haptic on/off, last player name.
- **Hive box `caro_settings`**: cấp AI mặc định, hiển thị toạ độ, hiệu ứng động.
- **Drift DB `game_history.db`**:
  - Bảng `game_records` (id, game_id, mode, result, started_at, duration, opponent_name).
  - Bảng `game_moves` (record_id, move_no, row, col, player).

---

## 8. Theme & i18n

### Theme
- 2 theme: `lightTheme`, `darkTheme` định nghĩa trong `core/theme/`.
- Màu chủ đạo: xanh đậm `#1976D2` (light), xanh navy `#0D47A1` (dark).
- Bàn cờ: nền gỗ nhạt (light) / xám đậm (dark). Lưới đen mảnh. Quân X đỏ, O xanh.

### i18n
- Sử dụng `flutter_localizations` + ARB.
- File: `assets/translations/app_vi.arb`, `app_en.arb`.
- Key đặt theo dạng `{feature}.{screen}.{element}`, ví dụ `caro.menu.play_with_ai`.

---

## 9. Roadmap triển khai (đề xuất thứ tự)

### Sprint 1 — Foundation (3-4 ngày)
1. Setup project Flutter, cấu hình lint, format.
2. Cài Riverpod, go_router, Hive, Drift, intl.
3. Implement `GameModule` interface + `GameRegistry`.
4. Build `HomeScreen` (launcher) và `SettingsScreen` chung.
5. Setup theme + i18n VI/EN.

### Sprint 2 — Cờ Caro core (3-4 ngày)
1. `Board`, `Move`, `Rules` (luật caro VN) + unit test.
2. `BoardWidget` (render bàn cờ, tap đánh quân, highlight nước cuối).
3. `CaroMenuScreen` + `CaroGameScreen` (chế độ 2 người cùng máy — local).
4. Logic check win + highlight 5 quân thắng.

### Sprint 3 — AI (4-5 ngày)
1. `AiEngine` interface + chạy trong Isolate.
2. `EasyAi` + `MediumAi` (heuristic 1-ply).
3. `HardAi` (Minimax + Alpha-Beta + move pruning).
4. `SuperAi` (Threat-Space + Zobrist + transposition table + iterative deepening).
5. Test: super AI thắng hard AI ≥ 80% trong 100 ván tự đấu.

### Sprint 4 — LAN multiplayer (3-4 ngày)
1. `lan_host.dart`, `lan_client.dart`, `protocol.dart`.
2. `CaroLanLobbyScreen` (tạo phòng / nhập IP / quét QR).
3. Sync nước đi, xử lý mất kết nối, rematch.
4. Test 2 thiết bị thật.

### Sprint 5 — Tính năng bổ sung (3 ngày)
1. Lưu lịch sử (Drift) + màn hình danh sách + replay.
2. Thống kê.
3. Undo + Hint.
4. Âm thanh + haptic.

### Sprint 6 — Polish & release (2-3 ngày)
1. Test integration toàn flow.
2. Tinh chỉnh UI, animation, dark theme.
3. Build APK/AAB + IPA, chuẩn bị icon, splash, screenshot.

**Tổng:** ~3 tuần phát triển full-time.

---

## 10. Testing

### Unit test (bắt buộc)
- `rules_test.dart`: tất cả case win/lose/draw, đặc biệt luật chặn 2 đầu.
- `ai_engine_test.dart`:
  - AI luôn chặn nước thắng tức thì của đối thủ.
  - AI luôn đi nước thắng nếu có.
  - AI siêu khó thắng AI khó ≥ 80%.
- `protocol_test.dart`: serialize/deserialize JSON.

### Widget test
- `BoardWidget` render đúng kích thước, tap vào ô gọi callback đúng toạ độ.
- `CaroGameScreen` hiển thị dialog thắng khi nhận event win.

### Integration test
- Chơi 1 ván vs AI Dễ từ menu đến kết thúc.
- Tạo phòng LAN giả lập (loopback) và join thành công.

---

## 11. Build & Deploy

### Android
- Min SDK: 23 (Android 6.0).
- Target SDK: 34.
- Permissions: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CAMERA` (cho QR), `VIBRATE`.
- Output: APK (debug) + AAB (release, Play Store).

### iOS
- Min iOS: 13.
- Permissions trong `Info.plist`: `NSCameraUsageDescription` (QR), `NSLocalNetworkUsageDescription` (LAN).
- Output: IPA (cần Mac + Xcode).

### Versioning
- Semantic: `MAJOR.MINOR.PATCH+BUILD` trong `pubspec.yaml`.
- v1.0.0 = release đầu tiên có Caro.

---

## 12. Tiêu chí "Hoàn thành" (Definition of Done) cho v1

- [ ] App build thành công cho Android (APK) và iOS (chạy trên simulator).
- [ ] Launcher hiển thị 1 game "Cờ Caro" với icon.
- [ ] Chơi đủ 4 chế độ AI, mỗi chế độ chơi ít nhất 1 ván trọn vẹn không crash.
- [ ] AI "Siêu khó" trả nước trong ≤ 2 giây trên thiết bị test.
- [ ] 2 thiết bị cùng Wi-Fi chơi LAN xuyên suốt 1 ván + rematch.
- [ ] Lịch sử lưu, replay chạy đúng, thống kê chính xác.
- [ ] Theme sáng/tối + chuyển VI/EN không cần restart.
- [ ] Âm thanh + haptic hoạt động, có thể tắt.
- [ ] Toàn bộ test pass: `flutter test`.
- [ ] Không có warning lint nghiêm trọng: `flutter analyze`.

---

## 13. Game tương lai (định hướng, không làm v1)

Để chứng minh kiến trúc plugin hoạt động, danh sách game cân nhắc thêm:
- **Cờ vua** (chess) — dùng package `chess` cho rule engine.
- **Sudoku** — generator + solver tự code.
- **2048** — game lưới đơn giản.
- **Minesweeper** — kinh điển.
- **Đoán số / Hangman** — đơn giản, làm warmup test plugin.

Mỗi game tương lai chỉ cần:
1. Tạo thư mục `lib/games/{tên}/`.
2. Implement `GameModule`.
3. Đăng ký trong `registered_games.dart`.
4. Không sửa code core hay launcher.

---

## 14. Ghi chú cho AI sinh code

Khi dùng file này làm prompt:
- **Không** sinh tất cả code 1 lần — sinh theo sprint trong mục 9.
- **Bắt đầu từ Sprint 1**, hoàn thiện foundation trước khi đụng tới Caro.
- Tuân thủ cấu trúc thư mục mục 4.4.
- Code Dart phải dùng `null-safety`, `const` constructor khi có thể, đặt tên rõ ràng tiếng Anh.
- Comment chỉ viết khi giải thích **why**, không giải thích **what**.
- Mọi class public phải có dartdoc 1 dòng.
- Sau mỗi sprint, chạy `flutter analyze` và `flutter test`, sửa hết warning trước khi qua sprint sau.
