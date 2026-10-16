# PLAN — Bida (Game #3)

> Game thứ 3 của Game Hub. Plug vào `GameModule` (xem `lib/core/game_module.dart`). Tái sử dụng `SettingsService`, `AudioService`, theme, routing và Hive layer.
>
> ⚠️ **Cảnh báo scope**: Bida khác hoàn toàn Caro/Sudoku — là game **real-time physics**, không turn-based logic thuần. Với 4 variants (gồm Carom 3-băng) + AI 3 mức + spin + 2.5D + daily challenge, scope này **xấp xỉ 2–3× Sudoku**. Khuyến nghị ship theo phase (xem §9 Roadmap), MVP = 8-ball + vs Human local, các variant/feature khác mở rộng sau.

---

## 1. Phạm vi (scope)

### Variants
| Variant | Mô tả | Đặc thù physics/luật |
|---|---|---|
| **Pool 8-ball** | 15 bi (7 sọc + 7 trơn + bi đen 8) + bi cái, 6 lỗ | Phân nhóm sau cú đầu vào lỗ, foul scratch, đen cuối cùng theo nhóm |
| **Pool 9-ball** | Bi 1→9 + bi cái, 6 lỗ | Phải chạm bi số nhỏ nhất trước, vào bi 9 thắng |
| **Bida lỗ VN** | Giống 8-ball nhưng luật VN: đánh tự do, lỗ trước thắng | Đơn giản hơn 8-ball, không phân nhóm |
| **Carom 3 băng** | Không lỗ, 3 bi (đỏ + 2 trắng/vàng), tính điểm theo cú chạm 2 bi + ≥3 băng | Physics chính xác cực cao + spin bắt buộc, AI riêng |

### Modes
- **vs AI** (Easy/Medium/Hard) — single AI engine, behavior khác theo level
- **vs Human local** (hot-seat, 2 người chung máy, đổi lượt)
- **Practice** (đặt lại bi tuỳ ý, không tính điểm, có thể chia layout preset)
- **Daily challenge** (setup bi cố định theo `YYYY-MM-DD.hashCode`, vào hết trong N gậy, leaderboard local theo streak)

### Controls
- **Aim line + power slider**:
  - Drag ngang trên màn để xoay cần ngắm (aim line từ bi cái, hiển thị first-bounce prediction)
  - Power slider dọc bên phải, kéo lên = lực tăng
  - **Spin widget**: mini-bi cái ở góc, tap chọn điểm tiếp xúc (top/back/left/right/center) → ảnh hưởng góc spin

### View
- **2.5D perspective nhẹ**: bàn tilt ~15° so với top-down, dùng `Matrix4` projection trong Flame
- Camera follow bi cái khi cú đang chạy (zoom out nhẹ để thấy toàn bàn)
- Khi ngắm: zoom in vào vùng bi cái + đích

### Audio + Haptic
- ✅ SFX va chạm: bi–bi, bi–băng, bi–lỗ (volume theo độ mạnh va chạm)
- ✅ Background music tuỳ chọn (settings toggle)
- ✅ Haptic feedback (`HapticFeedback.lightImpact` khi bi va, `mediumImpact` khi vào lỗ)
- ✅ Voice line: "Nice shot!", "Foul", "Game!", "Combo!" — 1 voice EN + 1 voice VN

---

## 2. Kiến trúc thư mục

```
lib/games/bida/
├── bida_game.dart                  # GameModule impl
├── domain/
│   ├── ball.dart                   # Ball: id, position, velocity, color, number, isCue, isPocketed
│   ├── table.dart                  # Table dimensions + pocket positions + cushion polygons
│   ├── variant.dart                # enum BidaVariant
│   ├── shot.dart                   # Shot: direction, power, spin(x,y)
│   ├── shot_result.dart            # Pocketed balls, fouls, cushion bounces, first-ball-hit
│   ├── rules/
│   │   ├── rules.dart              # Abstract Rules interface
│   │   ├── eight_ball_rules.dart
│   │   ├── nine_ball_rules.dart
│   │   ├── vn_rules.dart
│   │   └── carom_rules.dart        # Đếm băng + 2-ball touch
│   └── game_state.dart             # Current player, score, foul state, history
├── physics/
│   ├── physics_world.dart          # Wrapper quanh Forge2DWorld
│   ├── ball_body.dart              # Forge2D body factory cho bi
│   ├── cushion_body.dart           # Edge fixtures + restitution
│   ├── pocket.dart                 # Sensor fixtures cho 6 lỗ
│   ├── spin_model.dart             # Tính masse / draw / follow ảnh hưởng v lên bi cái
│   └── shot_predictor.dart         # Ray-cast aim line + ghost ball
├── ai/
│   ├── ai_player.dart              # Abstract AI interface
│   ├── easy_ai.dart                # Random shot về phía pocket gần nhất
│   ├── medium_ai.dart              # Tìm shot không che bởi bi khác
│   ├── hard_ai.dart                # Monte-Carlo simulate N shots, chọn shot có score cao nhất + position cho lượt sau
│   └── shot_simulator.dart         # Run physics headless để AI thử shot
├── data/
│   ├── bida_save_service.dart      # Hive: in-progress game
│   ├── bida_history_service.dart   # Hive: completed games + replay frames
│   ├── daily_challenge_service.dart # Hive: today's puzzle + streak
│   └── achievement_service.dart    # Hive: unlocked achievements
└── presentation/
    ├── bida_menu_screen.dart       # Variant + mode + AI level + continue
    ├── bida_game_screen.dart       # Main UI: FlameGame widget + HUD
    ├── bida_history_screen.dart    # List + replay
    ├── bida_practice_screen.dart   # Practice mode setup
    ├── bida_daily_screen.dart      # Daily challenge entry
    ├── bida_game_notifier.dart     # StateNotifier điều phối FlameGame
    ├── flame/
    │   ├── bida_flame_game.dart    # FlameGame chính + Forge2DGame
    │   ├── table_component.dart    # Sprite bàn + cushions + pockets
    │   ├── ball_component.dart     # BodyComponent cho mỗi bi + sprite số
    │   ├── aim_component.dart      # Hover aim line + ghost ball
    │   └── camera_controller.dart  # Follow bi cái
    └── widgets/
        ├── power_slider.dart
        ├── spin_widget.dart        # Mini cue ball để chọn spin
        ├── score_hud.dart
        ├── player_bar.dart
        └── result_dialog.dart
```

---

## 3. Tech stack chi tiết

### Dependencies thêm vào `pubspec.yaml`
```yaml
dependencies:
  flame: ^1.18.0
  flame_forge2d: ^0.18.0
  forge2d: ^0.13.0
```

### Physics — Forge2D config
- World scale: 1m = 100px (chuẩn Box2D), bàn vật lý ~2.84m × 1.42m (kích thước WPA 9-foot table)
- **Ball**: `CircleShape` r=0.0285m (≈2.86cm bi pool), density=1.7, friction=0.2, restitution=0.96
- **Cushion**: `EdgeShape` chain, restitution=0.7 (bi nảy ~70% năng lượng)
- **Pocket**: `CircleShape` sensor (no collision), r=0.06m, listener detect bi vào lỗ → mark `isPocketed=true`, remove body
- **Damping**: linearDamping=0.5, angularDamping=0.4 → simulate friction với fabric
- **Sleep threshold**: bi đứng yên khi |v| < 0.005 m/s liên tục 200ms → end shot

### Spin model (custom, ngoài Forge2D)
Forge2D không native support cue spin. Tự code:
- Lưu `Vector2 spin` riêng cho bi cái sau cú đánh
- Mỗi frame: áp thêm impulse nhỏ vào bi cái theo `spin × elapsedTime × decay`
- Khi bi cái va bi khác: giảm spin theo factor (energy transferred)

### 2.5D Rendering
- Flame `World` + `CameraComponent` với perspective transform: `Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(0.25)`
- Bi vẫn vật lý 2D, render dùng matrix project → top-down position thành 2.5D screen position
- Sprite bi: dùng image bi pool kèm số (asset `assets/bida/balls/1.png` … `15.png`, `cue.png`)

---

## 4. Domain & Rules chi tiết

### Ball
```dart
class Ball {
  final int id;              // 0 = cue, 1-15 = pool balls, 16/17 = white/yellow carom, 18 = red carom
  Vector2 position;
  Vector2 velocity;
  final Color color;
  final BallType type;       // cue, solid, stripe, eight, numbered, caromWhite, caromYellow, caromRed
  bool isPocketed;
  Vector2 spin;              // for cue ball
}

enum BallType { cue, solid, stripe, eight, numbered, caromWhite, caromYellow, caromRed }
```

### Rules — quan trọng
| Rule | 8-ball | 9-ball | VN | Carom |
|---|---|---|---|---|
| Foul: scratch (bi cái vào lỗ) | ✓ | ✓ | ✓ | N/A (no pocket) |
| Foul: không chạm bi nào | ✓ | ✓ | ✓ | ✓ |
| Foul: chạm sai bi đầu tiên | ✓ (sau khi phân nhóm) | ✓ (phải chạm bi nhỏ nhất) | ✗ | N/A |
| Phân nhóm sau cú đầu | ✓ | ✗ | ✗ | ✗ |
| Điều kiện thắng | Hết nhóm + đen 8 đúng lỗ | Vào bi 9 | Lỗ trước thắng (free shot) | Đủ N điểm (vd 20) |
| Đếm băng | ✗ | ✗ | ✗ | ✓ (≥3 băng trước khi chạm bi thứ 2) |

### ShotResult (sau khi physics đứng yên)
```dart
class ShotResult {
  final List<Ball> pocketed;
  final Ball? firstBallHit;
  final List<CushionHit> cushionHits;   // theo thứ tự thời gian
  final bool cueBallScratched;
  final List<Ball> ballsLeftTable;      // bi văng khỏi bàn (foul)
}
```

---

## 5. AI chi tiết

### Easy
- Chọn bi mục tiêu hợp lệ ngẫu nhiên
- Tính vector từ bi cái → bi mục tiêu, thêm noise ±10°
- Power random 50–80%

### Medium
- Với mỗi bi mục tiêu hợp lệ: tính ghost ball (vị trí bi cái cần ở để cụng bi mục tiêu vào pocket gần nhất)
- Loại bi bị che bởi bi khác (raycast)
- Chọn shot có angle ≤ 45°, distance ≤ 60% bàn
- Noise ±5°, power 60–90%

### Hard
- Monte-Carlo: với mỗi shot candidate, run physics headless 30 lần với noise nhỏ
- Score = (số bi vào lỗ × 100) + (điểm position cho lượt sau, càng gần bi mục tiêu tiếp = càng cao) − (penalty foul)
- Chọn shot có expected score cao nhất
- Carom: thêm constraint đếm băng trong simulation

### Shot simulator
- Headless Forge2D world (không render), fixed timestep 1/60s
- Max 5s simulated time → reject shot nếu chưa đứng yên
- Reuse cùng physics constants với main world

---

## 6. Routing (go_router)

```dart
// Trong app_router.dart, thêm:
GoRoute(path: '/bida', builder: (_, __) => const BidaMenuScreen()),
GoRoute(path: '/bida/play', builder: (_, st) => BidaGameScreen(config: st.extra as BidaConfig)),
GoRoute(path: '/bida/practice', builder: (_, __) => const BidaPracticeScreen()),
GoRoute(path: '/bida/history', builder: (_, __) => const BidaHistoryScreen()),
GoRoute(path: '/bida/daily', builder: (_, __) => const BidaDailyScreen()),
```

`BidaConfig`: `{variant, mode, aiLevel?, playerNames}`.

---

## 7. Assets cần chuẩn bị

```
assets/bida/
├── table/
│   ├── felt_green.png         # Texture nỉ xanh
│   ├── rail_wood.png          # Texture viền gỗ
│   └── pocket.png             # Sprite lỗ
├── balls/
│   ├── cue.png
│   ├── 1.png … 15.png         # Bi số
│   ├── carom_white.png
│   ├── carom_yellow.png
│   └── carom_red.png
├── audio/
│   ├── hit_soft.mp3           # Va chạm nhẹ
│   ├── hit_hard.mp3
│   ├── cushion.mp3            # Va băng
│   ├── pocket.mp3             # Vào lỗ
│   ├── break.mp3              # Phá rổ
│   ├── voice_nice.mp3
│   ├── voice_foul.mp3
│   ├── voice_combo.mp3
│   ├── voice_win.mp3
│   └── bgm_lounge.mp3         # Nhạc nền (loop)
```

---

## 8. Testing

| Loại | Target | Tool |
|---|---|---|
| Unit | Rules (foul detection cho 4 variants), spin model, shot result classification | `flutter_test` |
| Unit | AI shot simulator deterministic với fixed seed | `flutter_test` |
| Widget | Power slider, spin widget, aim line render | `flutter_test` |
| Golden | Bàn 2.5D rendering, ball sprites | `golden_toolkit` |
| Integration | Full game flow: break → pocket → win 8-ball | `integration_test` |
| Performance | 60fps khi 16 bi chuyển động đồng thời | DevTools profiler |

**Mục tiêu coverage**: ≥ 70% domain + rules + AI logic. Physics/render = manual smoke test.

---

## 9. Roadmap — 7 phases (~5–6 tuần)

> **Khuyến nghị mạnh**: Ship theo phase, mỗi phase = 1 release nội bộ chạy được. KHÔNG cố làm hết 4 variants cùng lúc.

### Phase 1 — Foundation + Physics (Sprint 1, ~5 ngày)
- [ ] Thêm Flame + Forge2D vào pubspec, init `BidaFlameGame`
- [ ] Table component (8-foot pool, 2.5D matrix, sprite felt)
- [ ] 16 bi pool với Forge2D bodies, racked vị trí break đúng
- [ ] Cushion + 6 pocket sensors
- [ ] Tap màn → bi cái nhận impulse → physics chạy → đứng yên
- [ ] Pocket detection: bi vào lỗ → remove body + log
- **DoD**: Mở /bida/play, thấy bàn 2.5D, tap đánh bi tự do, bi nảy băng, vào lỗ thì biến mất.

### Phase 2 — UI cú đánh + Spin (Sprint 2, ~4 ngày)
- [ ] Aim line từ bi cái (raycast 1 lần va băng để hiển thị first-bounce)
- [ ] Ghost ball ở vị trí va chạm với bi mục tiêu
- [ ] Power slider widget
- [ ] Spin widget + apply vào physics
- [ ] Camera zoom-in khi ngắm, zoom-out khi shot chạy
- **DoD**: Người chơi điều khiển hoàn chỉnh 1 cú đánh, aim line khớp đường bi thật.

### Phase 3 — 8-ball Rules + vs Human local (Sprint 3, ~5 ngày)
- [ ] `EightBallRules` đầy đủ: phân nhóm, foul, scratch, đen 8
- [ ] ShotResult classification từ physics events
- [ ] Player bar + score HUD + turn indicator
- [ ] Result dialog: thắng/thua/foul
- [ ] Audio: hit, cushion, pocket SFX kèm volume theo lực va
- [ ] Voice line + haptic
- **DoD**: 2 người chơi 1 ván 8-ball trọn vẹn, foul + thắng đúng luật.

### Phase 4 — vs AI 3 mức (Sprint 4, ~5 ngày)
- [ ] Headless shot simulator
- [ ] Easy/Medium/Hard AI cho 8-ball
- [ ] AI run trong Isolate (tránh block UI), animate cú đánh sau khi quyết định
- [ ] Indicator "AI đang nghĩ..."
- **DoD**: Chơi vs AI Hard ván 8-ball, AI hợp lý, không lag UI.

### Phase 5 — Mở rộng variants (Sprint 5, ~5 ngày)
- [ ] 9-ball rules + setup + AI adapt
- [ ] Bida lỗ VN rules (đơn giản hơn 8-ball)
- [ ] Variant selector trong menu
- [ ] Save/Resume per-variant
- **DoD**: 3 variants pool playable vs AI và Human.

### Phase 6 — Carom 3 băng (Sprint 6, ~5 ngày)
- [ ] Bàn không lỗ (skip pocket sensors)
- [ ] 3 bi setup
- [ ] Cushion-hit counter + 2-ball-touch detection
- [ ] Điểm số theo điều kiện (≥3 băng trước khi chạm bi thứ 2)
- [ ] AI Carom riêng (Monte-Carlo focus vào multi-cushion paths)
- **DoD**: Ván Carom vs AI Medium chạy đúng luật.

### Phase 7 — Daily + Practice + Stats + Polish (Sprint 7, ~4 ngày)
- [ ] Practice mode: drag bi tự do để setup
- [ ] Daily challenge: setup cố định theo seed ngày
- [ ] Stats per-variant + per-mode (win rate, best score, longest streak)
- [ ] Achievements (xem §10)
- [ ] History + replay (lưu init state + list shots, replay = re-simulate)
- [ ] Settings panel: BGM volume, voice on/off, haptic on/off
- [ ] Performance pass: 60fps target
- **DoD**: Ship-ready. Tất cả features hoạt động, perf ok.

---

## 10. Achievements (10 initial)

| ID | Mô tả |
|---|---|
| `first_win` | Thắng ván đầu tiên |
| `combo_3` | Vào 3 bi trong 1 cú |
| `combo_5` | Vào 5 bi trong 1 cú (rare) |
| `break_master` | Vào ≥2 bi từ cú phá rổ |
| `no_foul_game` | Thắng 1 ván không foul nào |
| `expert_8ball` | Thắng 10 ván 8-ball vs Hard AI |
| `carom_10` | Đạt 10 điểm Carom trong 1 ván |
| `daily_7` | 7 ngày liên tiếp hoàn thành daily |
| `daily_30` | 30 ngày liên tiếp |
| `all_variants` | Thắng ít nhất 1 ván mỗi variant |

---

## 11. Performance targets

| Metric | Target | Note |
|---|---|---|
| Frame rate (16 bi đang chuyển động) | 60fps | Pixel 6 / iPhone 12 |
| Shot animation completion | < 5s wall time | Damping đủ mạnh |
| AI Hard quyết định (1 lượt) | < 1.5s | Isolate + 30 sims × 5s sim time |
| Bundle size tăng | < 8MB | Sprites + audio |
| Daily challenge generation | < 100ms | Deterministic, không physics |

---

## 12. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Forge2D + Flame integration learning curve | Phase 1 = 5 ngày dành riêng để spike |
| Carom AI rất khó (multi-cushion planning) | Phase 6 cuối roadmap, có thể downgrade sang heuristic nếu Monte-Carlo không kịp |
| Spin model không khớp realistic | Có settings "arcade" (simplified) vs "realistic" |
| 2.5D + aim line projection bug khi tilt | Có thể fallback top-down nếu phát sinh blocker |
| AI Isolate gây lag transition | Animate "AI thinking" che được, đo lại nếu < 1.5s |
| Bundle size lớn vì sprites/audio | Dùng audio nén low-bitrate, sprites resize 256px max |

---

## 13. So sánh với Caro / Sudoku

| Khía cạnh | Caro | Sudoku | Bida |
|---|---|---|---|
| Loại game | Turn-based | Puzzle | **Real-time physics** |
| Engine | Flutter widget | Flutter widget | **Flame + Forge2D** |
| AI | Minimax + heuristic | Logical solver | **Monte-Carlo simulation** |
| Asset | None | None | **Sprites + audio nhiều** |
| Test khả thi | Cao | Cao | **Trung bình (physics khó test)** |
| Phức tạp tương đối | 1× | 1.5× | **2.5–3×** |
| Sprint dự kiến | 4 | 7 | **7** (mỗi sprint dài hơn) |

---

## 14. Câu hỏi mở (cần chốt khi vào sprint)

1. **Spin widget UX**: dùng mini-bi 2D ở góc, hay mở dialog full-screen khi nhấn nút "Spin"?
2. **Daily challenge format**: setup bi ngẫu nhiên theo seed, hay layout curated từ bank ~30 puzzles?
3. **Replay rendering**: re-simulate từ shot history (deterministic-tốn CPU), hay lưu frame state mỗi 100ms?
4. **Voice line**: dùng TTS Flutter (`flutter_tts`) hay record sẵn mp3?
5. **Phase 5–7 có thể delay không**? MVP = Phase 1–4 (8-ball + AI + Human) đã đủ thử nghiệm chất lượng game.

---

## 15. Definition of Done — toàn game

- [ ] 4 variants playable trong tất cả 3 modes (AI/Human/Practice) + Daily
- [ ] AI 3 mức cho mỗi variant pool (8/9/VN); Carom có ít nhất 2 mức
- [ ] Spin + aim line + power slider hoạt động chính xác
- [ ] Audio + haptic + voice line đầy đủ, settings toggle
- [ ] Stats + achievements + daily streak + history persistence
- [ ] 60fps khi physics chạy với 16 bi
- [ ] Coverage domain/rules/AI ≥ 70%
- [ ] 0 analyzer errors, 0 lint warnings
- [ ] Bundle size game_hub tăng < 8MB sau khi add Bida
