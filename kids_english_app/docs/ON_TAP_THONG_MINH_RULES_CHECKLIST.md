# Rules & Checklist phát triển: Ôn Tập Thông Minh (Smart Review)

> Tài liệu nguồn: [BAO_CAO_Y_TUONG_ON_TAP_THONG_MINH.md](BAO_CAO_Y_TUONG_ON_TAP_THONG_MINH.md) · [KE_HOACH_TRIEN_KHAI_ON_TAP_THONG_MINH.md](KE_HOACH_TRIEN_KHAI_ON_TAP_THONG_MINH.md)
> Áp dụng cho mọi người/agent phát triển tính năng này. Khi tài liệu kế hoạch và file này khác nhau, **file này thắng** (đã chốt sau khi đối chiếu với code thực tế ngày 25/11/2026).

Thư mục làm việc: `kids_english_app/app/`. Mọi lệnh `flutter` chạy trong thư mục đó.

---

## 0. Phân giai đoạn & cổng nghiệm thu

| Giai đoạn | Nội dung | Cổng để sang giai đoạn sau |
|---|---|---|
| **GĐ1** | Sửa Leitner · `ReviewPlanner` · 4 activity đa `baseDir` · `ReviewSessionScreen` · nút Review ⭐ · Kho từ vựng phụ huynh | Checklist GĐ1 (mục 9) đủ 100%, `flutter analyze` không thêm issue, `flutter test` xanh, reviewer duyệt |
| **GĐ2** | `BalloonPopActivity` · `FeedMomoActivity` · xoay vòng mini-game | Checklist GĐ2 đủ 100% |

Không làm GĐ2 khi GĐ1 chưa được duyệt.

---

## 1. Quy tắc chung (bắt buộc)

- **R1 – Không phá luồng bài học.** `LessonPlayerScreen` và mọi lời gọi activity hiện có phải chạy y nguyên. Tham số mới của activity luôn là **tuỳ chọn**, mặc định giữ hành vi cũ.
- **R2 – Không thêm dependency** vào `pubspec.yaml` (mọi thứ cần đã có: riverpod, go_router, hive_ce, just_audio, flutter_animate, confetti).
- **R3 – Offline 100%.** Không gọi mạng trong tính năng ôn tập.
- **R4 – Không `print`** mới (dùng `debugPrint` nếu thật cần). Không thêm issue mới cho `flutter analyze` (hiện có 8 info `avoid_print` cũ — giữ nguyên, không tăng).
- **R5 – Không đụng** `content_packs/`, `docs/packs/`, `assets/` (trừ khi checklist ghi rõ), dữ liệu chủ đề, tính năng Google Drive, bài nói ghi âm (chỉ được thêm tham số `wordBaseDirs` cho `RepeatRecordActivity`).
- **R6 – Không commit.** Để thay đổi trong working tree cho reviewer.
- **R7 – Ngôn ngữ:** giao diện của bé = tiếng Anh ngắn gọn (+ gợi ý tiếng Việt qua `viHints` sẵn có); Khu phụ huynh = tiếng Việt có dấu. Comment code tiếng Việt như code hiện tại.
- **R8 – An toàn trẻ em:** không "Game Over", không trừ điểm, không âm thanh/màu báo lỗi gắt. Vùng chạm tối thiểu `kKidTouch` (80dp). Phiên ôn ~3–4 phút.
- **R9 – Testable:** logic thuần (planner, gom kết quả) không phụ thuộc Flutter UI; nhận `DateTime now` và `Random` qua tham số để test tất định.

---

## 2. Quy tắc Leitner (sửa lõi — bắt buộc ở GĐ1)

Hiện trạng có 2 lỗi khiến ôn tập vô nghĩa:
1. `_completeLesson` gọi `recordWordAttempt(correct: true)` cho **mọi** từ của bài → học xong 1 bài là từ lên box cao.
2. `WordStat.update` lên 1 box **mỗi lần** đúng, kể cả nhiều lần trong cùng ngày → một bài học có thể đẩy từ lên box 4–5 ("đã thuộc") ngay.

Quy tắc mới:
- **L1 – Chỉ thăng box khi từ đang đến hạn.** Trong `WordStat.update`: nếu `isCorrect` và `isDue(now)` → `box+1` (tối đa 5), `nextReview = hôm nay + leitnerIntervalDays[newBox]`. Nếu `isCorrect` nhưng **chưa** đến hạn → chỉ tăng `exposures`, `correct`; giữ nguyên `box` và `nextReview`.
- **L2 – Sai thì về box 1**, `nextReview = hôm nay` (giữ như cũ), tăng `wrong`.
- **L3 – Hoàn thành bài học không tự cộng "đúng".** Thay vòng `recordWordAttempt(correct: true)` trong `_completeLesson` bằng `storage.ensureWordIntroduced(profileId, wordId)` cho các từ của bài (`lesson.newWords` + các từ của bước). `ensureWordIntroduced`: nếu chưa có `WordStat` → tạo `WordStat(exposures: 1, box: 1, nextReview: hôm nay)`; nếu đã có → không đổi.
- **L4 – Trong phiên ôn tập, mỗi từ chỉ ghi Leitner 1 lần**, vào lúc kết thúc phiên, theo **lần trả lời có chấm điểm đầu tiên** của từ đó trong phiên (đúng → `correct: true`, sai → `false`). Từ không có lần chấm điểm nào → không ghi. Thoát giữa phiên → không ghi gì.
- **L5 – Chỉ Tap & Find, Drag & Drop (và GĐ2: Balloon Pop, Feed Momo) được chấm điểm.** Memory Match và Repeat & Record **không** ghi Leitner.
- **L6 – Mốc thời gian theo ngày địa phương** (`DateTime(now.year, now.month, now.day)`), như code hiện tại.
- Cập nhật test cũ trong `test/data_test.dart` cho đúng L1 (đúng 2 lần cùng ngày: box 1 → 2, lần 2 giữ 2; sang ngày đến hạn mới lên 3).

---

## 3. Quy tắc `ReviewPlanner` (`lib/data/review_planner.dart`)

- **P1 – Mô hình** theo kế hoạch: `ReviewMode { smartMix, weakWordsOnly }`, `ReviewWord { word, topicId, topicTitleEn, topicTitleVi, baseDir, stat }`, `ReviewSummary`.
- **P2 – Kho từ đã học** = hợp của (a) từ trong `lesson.newWords` của bài `isLessonDone`, (b) mọi từ có `WordStat` của hồ sơ. Chỉ lấy từ **tìm được trong danh sách chủ đề đang nạp** (gói đã bị gỡ → bỏ qua, không crash). Loại trùng theo `word.id`; giữ `baseDir` của chủ đề chứa từ.
- **P3 – Phân nhóm (không chồng lấn):**
  - `dueOrWeakWords`: `stat == null` **hoặc** `box == 1` **hoặc** `isDue(now)`.
  - `learningWords`: còn lại có `box == 2`.
  - `masteredWords`: còn lại có `box >= 3`.
  - Mỗi từ thuộc đúng 1 nhóm; `learned = due ∪ learning ∪ mastered`.
  - Badge trên nút Review và số "Cần ôn tập" phụ huynh = `dueOrWeakWords.length`.
- **P4 – Mở ôn tập** khi `learnedWords.length >= 4`. `sessionSize = min(6, learned)`.
- **P5 – smartMix:** 3 từ từ `dueOrWeak` (sắp: `box` tăng dần → `wrong` giảm dần → `nextReview` cũ nhất), 2 từ `learning` (ngẫu nhiên), 1 từ `mastered` (`nextReview` cũ nhất). Thiếu thì bù theo thứ tự nhóm 1 → 2 → 3. Kết quả không trùng, xáo trộn thứ tự hiển thị.
- **P6 – weakWordsOnly:** tối đa 6 từ từ `dueOrWeak` theo thứ tự sắp ở P5; nếu < 4 từ thì bù từ `learning` rồi `mastered` cho đủ tối thiểu 4 (để các game có đủ thẻ).
- **P7 – Đáp án nhiễu** cho Tap & Find lấy từ toàn bộ `learnedWords` (không chỉ 6 từ phiên).
- **P8 – Thuần Dart:** hàm nhận `topics`, các hàm đọc trạng thái (`isLessonDone`, `wordStat`) hoặc `Storage`, `profileId`, `now`, `Random`. Provider `reviewSummaryProvider` tính lại khi `topicsProvider`, `activeProfileProvider`, `progressVersionProvider` đổi.

---

## 4. Quy tắc đa nguồn `baseDir` (cross-topic)

- **B1 –** 4 activity (`TapFind`, `MemoryMatch`, `DragDrop`, `RepeatRecord`) thêm tham số tuỳ chọn `Map<String, String?>? wordBaseDirs` và helper `_dirFor(Word w)` (map có → dùng map, kể cả giá trị `null` = built-in; map không có → `widget.baseDir`). Mọi `MediaImage` của từ dùng `_dirFor(w)`.
- **B2 – Âm thanh:** `ReviewSessionScreen` dựng map `audioPath → baseDir` từ `word.audio` và `word.sentenceAudio` của mọi từ trong kho. `playAudio(path, text)` tra map; không có → `baseDir: null` (assets) → `AudioService` tự fallback TTS nếu thiếu file.
- **B3 –** Không đổi chữ ký callback `playAudio` hiện có của các activity (trừ `RepeatRecordActivity` vốn đã là `Future<void> Function`).
- **B4 –** `DragDropActivity` thêm `int rounds = 1` (mặc định = hành vi hiện tại). Mỗi vòng một từ mục tiêu khác nhau khi đủ từ.

---

## 5. Quy tắc `ReviewSessionScreen` (`lib/features/review/review_session_screen.dart`)

- **S1 – Route** `/review` trong `lib/app/app.dart`, query `mode=smart|weak` (mặc định `smart`).
- **S2 – Chốt danh sách từ 1 lần khi mở màn** (không tính lại giữa phiên khi provider đổi).
- **S3 – 4 chặng + chúc mừng**, thanh tiến trình 4 ngôi sao trên cùng, nút thoát (X) về bản đồ:
  1. Tap & Find: `rounds: 6`, `words: sessionWords`, `allTopicWords: learnedWords` (P7).
  2. Memory Match: 3 từ ngẫu nhiên trong phiên (6 thẻ).
  3. Drag & Drop: `rounds: 4`, 4 từ ưu tiên đầu.
  4. Repeat & Record: 2 từ yếu nhất (box thấp nhất, `wrong` cao nhất).
  5. Celebrate: "You are a Review Super Star!" (+ `viText` khi bật gợi ý), khi xong → ghi Leitner (L4), `progressVersionProvider.bump()`, quay về `/home`.
- **S4 – Không có hồ sơ đang chọn** hoặc kho < 4 từ → không vào phiên, quay về `/home` an toàn.
- **S5 – Giới hạn thời gian màn hình:** khi mở `/review` mà `screenTimeProvider.isTimeUp` → chuyển `/sleep` (như `KidHomeScreen`); đang giữa phiên thì không ngắt (giống bài học hiện tại).

## 6. Nút Review ⭐ (`KidHomeScreen` – `lib/features/screens.dart`)

- **H1 –** Ẩn khi kho < 4 từ; hiện khi ≥ 4. Badge số = `dueOrWeakWords.length` khi > 0. Hiệu ứng mời gọi nhẹ (flutter_animate), không nhấp nháy gắt.
- **H2 –** Đặt ở top bar, không che avatar/nút khoá phụ huynh, kích thước ≥ `kKidTouch`. Chạm → `context.push('/review')`.
- **H3 –** Không làm hỏng đồng bộ ngầm Google Drive và kiểm tra giờ chơi đang có trong `KidHomeScreen`.

## 7. Kho từ vựng phụ huynh (`progress_report_tab.dart`)

- **K1 –** Giữ biểu đồ 7 ngày. Thêm 3 ô: 📚 Đã học · 🟢 Đã thuộc · 🔴 Cần ôn tập (số theo P3).
- **K2 –** Nút "Cho bé ôn ngay nhóm từ cần luyện" chỉ bật khi có từ cần ôn **và** kho ≥ 4 → `context.go('/home')` rồi `context.push('/review?mode=weak')`.
- **K3 –** 3 `ExpansionTile`: 🔴 Cần ôn tập (mở sẵn), 🟡 Đang củng cố, 🟢 Đã thuộc. Mỗi từ: ảnh 40×40 (đúng `baseDir`), tiếng Anh, nghĩa `vi`, 5 sao theo box; chạm → phát âm (đúng `baseDir`).
- **K4 –** Không có hồ sơ / kho rỗng → thông báo thân thiện, không lỗi.

## 8. Quy tắc GĐ2

- **G1 –** Không có ảnh `momo_think.png`; Feed Momo dùng `momo_idle.png` + hiệu ứng lắc đầu, `momo_cheer.png` khi đúng.
- **G2 – Balloon Pop:** 3–4 bóng 120–140dp, ~8 giây/lượt, lắc nhẹ hình sin; bóng mục tiêu trôi hết thì bay lại (không thua); chạm nhầm → bóng nảy + đọc tên từ đó + nhắc mục tiêu; 2 lần nhầm → viền vàng gợi ý. 6 vòng. Dispose `AnimationController` đúng.
- **G3 – Feed Momo:** 4 vòng, 3–4 thẻ kéo, đúng → cheer + khen, nhầm → lắc đầu + đọc tên thẻ + nhắc mục tiêu.
- **G4 –** Cả hai có `onWordAttempt`, `onFinished`, `playAudio`, `wordBaseDirs` theo chuẩn mục 4; chấm điểm theo L4/L5.
- **G5 – Xoay vòng:** chặng 1 ngẫu nhiên TapFind/BalloonPop, chặng 3 ngẫu nhiên DragDrop/FeedMomo, chọn 1 lần khi mở phiên (Random có thể inject để test).

---

## 9. Checklist GĐ1

**Leitner**
- [ ] `WordStat.update` theo L1/L2; test cũ trong `data_test.dart` cập nhật đúng L1
- [ ] `Storage.ensureWordIntroduced` + test
- [ ] `_completeLesson` dùng `ensureWordIntroduced` thay vì cộng "đúng" (L3)

**Planner**
- [ ] `lib/data/review_planner.dart` (P1–P8)
- [ ] `reviewSummaryProvider` trong `lib/app/providers.dart`
- [ ] Bộ gom kết quả phiên (L4) — thuần Dart, có test

**Activity đa nguồn**
- [ ] `wordBaseDirs` cho TapFind, MemoryMatch, DragDrop, RepeatRecord (B1)
- [ ] `DragDropActivity.rounds` (B4)
- [ ] Bài học thường vẫn chạy như cũ (R1)

**Màn hình**
- [ ] `/review` + `ReviewSessionScreen` (S1–S5)
- [ ] Nút Review ⭐ + badge (H1–H3)
- [ ] Kho từ vựng trong `ProgressReportTab` (K1–K4)

**Test tự động** (`test/review_planner_test.dart`, `test/review_ui_test.dart`)
- [ ] < 4 từ → không mở ôn tập
- [ ] 10 từ đa chủ đề (built-in + gói) → 6 từ đúng tỷ lệ 3/2/1, không trùng, giữ đúng `baseDir`
- [ ] Bù nhóm khi thiếu (ví dụ toàn box 1)
- [ ] `weakWordsOnly` ưu tiên box 1 / `wrong` cao; bù đủ 4
- [ ] Từ của gói đã gỡ bị bỏ qua
- [ ] Gom kết quả: lần chấm đầu tiên quyết định; Memory/Repeat không ghi; thoát giữa chừng không ghi
- [ ] Nút Review ẩn < 4, hiện + badge ≥ 4
- [ ] `ProgressReportTab` hiển thị đúng 3 con số
- [ ] Activity dùng `wordBaseDirs` tải ảnh theo đúng thư mục (kiểm tra `MediaImage.baseDir`)

**Nghiệm thu**
- [ ] `flutter analyze`: không thêm issue so với 8 info cũ
- [ ] `flutter test`: 100% xanh (gồm toàn bộ test cũ)
- [ ] `flutter build apk --debug` thành công

## 10. Checklist GĐ2
- [ ] `balloon_pop_activity.dart` (G2, G4) + widget test hoàn thành đủ vòng và gọi `onWordAttempt`
- [ ] `feed_momo_activity.dart` (G1, G3, G4) + widget test
- [ ] Xoay vòng trong `ReviewSessionScreen` (G5) + test với Random cố định
- [ ] analyze/test/build như GĐ1

## 11. Báo cáo khi bàn giao (agent → reviewer)
1. Danh sách file tạo/sửa, mỗi file 1 dòng.
2. Điểm lệch so với kế hoạch/rules và lý do.
3. Kết quả nguyên văn dòng tổng kết của `flutter analyze`, `flutter test`, `flutter build apk --debug`.
4. Những gì chưa kiểm chứng được (ví dụ: chưa chạy trên thiết bị).
