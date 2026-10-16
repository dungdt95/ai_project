# PLAN — Kế hoạch triển khai App Chia Hóa Đơn

> Phiên bản 1.0 · 2026-10-02 · Đọc kèm [SPEC.md](./SPEC.md)
> **Stack chốt:** Flutter 3.47.4 / Dart 3.13 · Riverpod · sqflite · fl_chart · **100% offline**

---

## 0. Tóm tắt điều hành

| | |
|---|---|
| **Tên app** | ChiaHoaDon (`chiahoadon`) |
| **Nền tảng** | Android (chính) · iOS (code sẵn sàng, cần máy Mac để build) |
| **Kiến trúc** | 3 lớp: `presentation` / `domain` / `data` — feature-first |
| **Lưu trữ** | SQLite local qua `sqflite`, 11 bảng |
| **Điểm rủi ro số 1** | Thuật toán chia tiền + làm tròn → **làm trước UI, phủ unit test ≥ 90%** |
| **Khối lượng** | ≈ **19,5 ngày-người** cho v1.0 (+2 ngày cho nhóm chức năng tùy chọn) |
| **Thứ tự ưu tiên** | Split engine → Thành viên → Hóa đơn/chia đều → Chia theo món → Thống kê → Quyết toán → Chia sẻ |

---

## 1. Phân tích yêu cầu

### 1.1 Đối chiếu yêu cầu gốc ↔ đặc tả

| Yêu cầu của bạn | Mã FR | Phase | Ghi chú phân tích |
|---|---|---|---|
| Nhập hóa đơn, chọn người tham gia | FR-3.1 → 3.7 | 4 | Tách **2 chế độ nhập**: nhập tổng (nhanh) và nhập theo món (chi tiết) — vì chia đều không cần liệt kê món |
| Quản lý thành viên | FR-1 | 3 | Cần **soft delete**: xóa thành viên không được làm vỡ hóa đơn cũ |
| Chia đều | FR-4.1 | 4 | Vấn đề thật là **phần dư**: 1.000.000/3 không chia hết → cần thuật toán phân bổ |
| Chia theo giá dịch vụ từng người | FR-4.2 | 5 | Mô hình đúng là **món ↔ nhiều người** (quan hệ n-n), không phải "mỗi người 1 số tiền" |
| Nhiều hóa đơn | FR-3.11 → 3.15 | 4 | Cần tìm kiếm + lọc ngay từ v1, nếu không sau 50 hóa đơn là không dùng được |
| Thống kê tổng + từng lần theo thành viên | FR-7.1, FR-7.2 | 8 | Query trực tiếp từ `bill_participants` — không cần bảng tổng hợp riêng |

### 1.2 Ba quyết định thiết kế then chốt

**① Tiền luôn là số nguyên (đơn vị: đồng).**
`double` gây lỗi `0.1 + 0.2 != 0.3`. Với tiền thì sai 1 đồng cũng làm `tổng các phần != tổng hóa đơn` → mất niềm tin vào app. Toàn bộ hệ thống dùng `int`. Phần trăm lưu **basis point** (`8%` → `800`) để cũng là `int`.

**② Split engine là pure function, tách khỏi Flutter và DB.**
```dart
SplitResult computeSplit(BillInput input)   // không async, không I/O, không Flutter
```
→ test được bằng `dart test` thuần, chạy 1000 test case trong < 1 giây, không cần emulator.

**③ Hóa đơn lưu snapshot, không chỉ lưu tham chiếu.**
`bill_participants` lưu cả `member_name_snapshot` và `share_amount` đã tính. Lý do: đổi tên thành viên hoặc sửa cấu hình làm tròn **không được** làm thay đổi hóa đơn đã chốt 6 tháng trước.

### 1.3 Những "cái bẫy" đã lường trước

| Bẫy | Hệ quả nếu bỏ qua | Cách xử lý |
|-----|-------------------|------------|
| 1.000.000 / 3 người | Lệch 1đ, tổng không khớp | Largest Remainder (SPEC FR-5) |
| Làm tròn 1.000đ nhưng tổng là 847.500 | Không thể chia thành các bội số 1.000 | Làm tròn **tổng** trước, rồi mới phân bổ |
| VAT tính trước hay sau giảm giá | Lệch vài chục nghìn | Cố định thứ tự: `discount → base → VAT/phí` |
| Món không ai chọn | Tiền "bốc hơi", tổng không khớp | Coi là món chung, chia đều toàn bộ + cảnh báo UI |
| Xóa thành viên đang có trong hóa đơn | Crash hoặc hóa đơn hiện "null" | Soft delete + snapshot tên |
| Sửa hóa đơn đã có người trả | Số tiền đã trả không còn khớp | Cảnh báo + giữ `paid_amount`, hiện "trả thừa/thiếu" |
| Người trả trước không tham gia ăn | Bị tính phần chia oan | Tách `bill_payers` khỏi `bill_participants` |
| 1.000 hóa đơn | Danh sách lag | Phân trang 50 + index trên `bill_date` |

---

## 2. Chức năng đề xuất thêm (ngoài yêu cầu gốc)

Xếp theo **giá trị / công sức**. Cột "v1.0?" là khuyến nghị của tôi.

| # | Chức năng | Giá trị | Công sức | v1.0? | Lý do |
|---|-----------|---------|----------|-------|-------|
| 1 | **Người trả trước + số dư ròng ai nợ ai** (FR-6.4) | ⭐⭐⭐⭐⭐ | Thấp | ✅ **Có** | Đây là câu hỏi thật sự của người dùng. Chia tiền xong mà không biết ai nợ ai thì chưa giải quyết được gì |
| 2 | **Phụ phí VAT / phí dịch vụ / giảm giá** (FR-5) | ⭐⭐⭐⭐⭐ | Trung bình | ✅ **Có** | Hầu hết hóa đơn nhà hàng VN đều có. Thiếu cái này là phải tính tay |
| 3 | **Đơn vị làm tròn 1.000đ** (FR-5.7) | ⭐⭐⭐⭐⭐ | Thấp | ✅ **Có** | Không ai chuyển khoản 333.333đ |
| 4 | **Đánh dấu đã trả / chưa trả từng người** (FR-6.1) | ⭐⭐⭐⭐⭐ | Thấp | ✅ **Có** | Thay thế việc ghi chú trên giấy |
| 5 | **Chia sẻ kết quả ra Zalo/Messenger** (FR-8.1) | ⭐⭐⭐⭐⭐ | Thấp | ✅ **Có** | Đây là cách kết quả đến được với người khác — app single-user thì bắt buộc phải có |
| 6 | **Nhóm thành viên** (FR-2) | ⭐⭐⭐⭐ | Thấp | ✅ **Có** | Nhóm 6 người đi ăn hàng tuần → tiết kiệm rất nhiều chạm |
| 7 | **Sao lưu / phục hồi file JSON** (FR-8.4) | ⭐⭐⭐⭐ | Thấp | ✅ **Có** | App offline = **không có cloud backup**. Mất máy là mất sạch → đây là chức năng *bắt buộc*, không phải tùy chọn |
| 8 | **Quyết toán tối thiểu giao dịch** (FR-6.5) | ⭐⭐⭐⭐ | Trung bình | ✅ **Có** | Thuật toán đã có sẵn trong SPEC, chỉ ~60 dòng code |
| 9 | **Chia theo số phần / tỷ lệ %** (FR-4.3, 4.4) | ⭐⭐⭐⭐ | Thấp | ✅ **Có** | Tái dùng ngay split engine, chỉ cần thêm UI nhập |
| 10 | **Nhân bản hóa đơn** (FR-3.15) | ⭐⭐⭐⭐ | Rất thấp | ✅ **Có** | Tiền nhà / internet hàng tháng. ~20 dòng code |
| 11 | **Trọng số trong 1 món** (2 lon bia vs 1 lon) | ⭐⭐⭐ | Thấp | ✅ **Có** | Schema đã thiết kế sẵn `weight_num/den`, thêm UI là xong |
| 12 | **Ảnh hóa đơn đính kèm** (FR-3.9) | ⭐⭐⭐ | Thấp | ✅ **Có** | Bằng chứng khi có tranh chấp |
| 13 | **Thống kê theo danh mục + biểu đồ** (FR-7.5 → 7.7) | ⭐⭐⭐ | Trung bình | ✅ **Có** | `fl_chart` làm nhanh |
| 14 | **QR chuyển khoản VietQR** (FR-6.7) | ⭐⭐⭐⭐ | Trung bình | ⚠️ v1.1 | Rất tiện ở VN và **sinh được hoàn toàn offline** (chuỗi EMVCo + `qr_flutter`, không cần API). Nhưng cần nhập đúng mã BIN ngân hàng và test với app bank thật |
| 15 | **Khóa app bằng vân tay** (FR-9.5) | ⭐⭐⭐ | Thấp | ⚠️ v1.1 | Dữ liệu tiền bạc nên nhạy cảm, nhưng không chặn luồng chính |
| 16 | **Xuất CSV** (FR-8.3) | ⭐⭐ | Thấp | ⚠️ v1.1 | Ít dùng khi đã có chia sẻ text |
| 17 | **Hóa đơn định kỳ / template** (FR-3.16) | ⭐⭐ | Trung bình | ⚠️ v1.1 | Nhân bản hóa đơn (#10) đã giải quyết 80% nhu cầu |
| 18 | **OCR chụp hóa đơn giấy** (FR-3.17) | ⭐⭐⭐ | **Cao** | ❌ v2.0 | On-device ML Kit nên vẫn offline, nhưng +30MB APK và độ chính xác với hóa đơn VN thấp → gõ tay còn nhanh hơn. Làm sau khi app đã ổn định |
| 19 | **Bàn phím tính nhanh `+ − × ÷`** (FR-9.7) | ⭐⭐⭐ | Trung bình | ❌ v2.0 | Tiện nhưng là widget tự viết, tốn thời gian |
| 20 | **Đa tiền tệ** | ⭐ | Cao | ❌ Không | Trái mục tiêu offline (cần tỷ giá). Bỏ hẳn |
| 21 | **Đồng bộ nhiều thiết bị** | ⭐⭐⭐⭐ | Rất cao | ❌ Không | Trái yêu cầu "chạy local hoàn toàn" |

**Kết luận:** nhận #1 → #13 vào v1.0. Chúng biến app từ "cái máy tính chia tiền" thành "cuốn sổ nợ của nhóm" — đó mới là giá trị thật.

---

## 3. Kiến trúc & cấu trúc thư mục

### 3.1 Ba lớp

```
┌──────────────────────────────────────────────────┐
│  PRESENTATION   Screens · Widgets · Providers    │  Flutter + Riverpod
├──────────────────────────────────────────────────┤
│  DOMAIN         Models · SPLIT ENGINE · Rules    │  Dart thuần — 0 import Flutter
├──────────────────────────────────────────────────┤
│  DATA           DAOs · Repositories · sqflite    │  SQLite local
└──────────────────────────────────────────────────┘
```

Quy tắc phụ thuộc: `presentation → domain ← data`. **`domain` không được import gì từ 2 lớp kia** → đây là điều kiện để test split engine mà không cần emulator.

### 3.2 Cây thư mục

```
chiahoadon/
├── PLAN.md                         ← file này
├── SPEC.md                         ← đặc tả chức năng
├── pubspec.yaml
├── analysis_options.yaml
├── android/  ios/
├── assets/
│   ├── fonts/                      Be Vietnam Pro
│   └── data/banks.json             mã BIN ngân hàng VN (cho VietQR, v1.1)
├── lib/
│   ├── main.dart
│   ├── app.dart                    MaterialApp + router + theme
│   │
│   ├── core/
│   │   ├── constants/              app_constants, db_constants, categories mặc định
│   │   ├── theme/                  app_theme, app_colors, app_text_styles
│   │   ├── utils/
│   │   │   ├── money_formatter.dart     1234567 → "1.234.567 đ"
│   │   │   ├── date_formatter.dart
│   │   │   ├── avatar_color.dart        hash(tên) → màu cố định
│   │   │   ├── vn_text.dart             bỏ dấu để tìm kiếm/so trùng
│   │   │   └── result.dart              Result<T, AppError>
│   │   ├── extensions/             int.toVnd(), DateTime.startOfDay()...
│   │   └── widgets/                AppButton, MoneyField, EmptyState,
│   │                               MemberAvatar, MemberChip, ConfirmDialog
│   │
│   ├── domain/                     ★ DART THUẦN, KHÔNG IMPORT FLUTTER
│   │   ├── models/
│   │   │   ├── member.dart
│   │   │   ├── member_group.dart
│   │   │   ├── bill.dart
│   │   │   ├── bill_item.dart
│   │   │   ├── bill_participant.dart
│   │   │   ├── bill_payer.dart
│   │   │   ├── payment.dart
│   │   │   ├── category.dart
│   │   │   └── enums.dart          SplitType, RoundingMode, BillStatus...
│   │   ├── split/                  ★★★ TRÁI TIM CỦA APP
│   │   │   ├── split_input.dart        input bất biến cho engine
│   │   │   ├── split_result.dart       output: phần từng người + breakdown
│   │   │   ├── split_engine.dart       computeSplit() — entry point
│   │   │   ├── strategies/
│   │   │   │   ├── equal_strategy.dart
│   │   │   │   ├── itemized_strategy.dart
│   │   │   │   ├── percentage_strategy.dart
│   │   │   │   ├── shares_strategy.dart
│   │   │   │   └── exact_strategy.dart
│   │   │   ├── surcharge_allocator.dart    phân bổ VAT/phí/giảm giá
│   │   │   ├── rounding.dart               làm tròn + Largest Remainder
│   │   │   └── split_validator.dart        kiểm tra input trước khi tính
│   │   ├── settlement/
│   │   │   ├── balance_calculator.dart     số dư ròng từng người
│   │   │   └── debt_simplifier.dart        greedy tối thiểu giao dịch
│   │   └── stats/
│   │       └── stats_models.dart           MemberStat, MonthlyStat...
│   │
│   ├── data/
│   │   ├── database/
│   │   │   ├── app_database.dart        mở DB, PRAGMA foreign_keys=ON
│   │   │   ├── migrations.dart          v1 → v2 → ...
│   │   │   └── seed_data.dart           danh mục mặc định + thành viên "Tôi"
│   │   ├── dao/
│   │   │   ├── member_dao.dart
│   │   │   ├── group_dao.dart
│   │   │   ├── bill_dao.dart            CRUD + transaction ghi hóa đơn
│   │   │   ├── payment_dao.dart
│   │   │   └── stats_dao.dart           các query tổng hợp
│   │   └── repositories/
│   │       ├── member_repository.dart
│   │       ├── group_repository.dart
│   │       ├── bill_repository.dart     gọi split engine rồi lưu kết quả
│   │       ├── settlement_repository.dart
│   │       └── stats_repository.dart
│   │
│   ├── features/
│   │   ├── home/                   dashboard
│   │   ├── members/                list · form · detail (lịch sử + tổng chi)
│   │   ├── groups/                 list · form
│   │   ├── bills/
│   │   │   ├── list/               danh sách + tìm kiếm + lọc
│   │   │   ├── form/               ★ wizard 3 bước nhập hóa đơn
│   │   │   └── detail/             kết quả chia + đánh dấu đã trả + chia sẻ
│   │   ├── settlement/             ai nợ ai · gợi ý chuyển tiền
│   │   ├── stats/                  báo cáo + biểu đồ
│   │   └── settings/               theme · làm tròn · danh mục · backup
│   │
│   └── services/
│       ├── share_service.dart          text + render widget → PNG
│       ├── backup_service.dart         export/import JSON
│       ├── image_service.dart          lưu ảnh hóa đơn vào documents dir
│       └── preferences_service.dart    shared_preferences
└── test/
    ├── domain/split/               ★ ưu tiên cao nhất, ≥ 90% coverage
    ├── domain/settlement/
    ├── data/                       DAO test với sqflite_common_ffi (in-memory)
    └── widget/                     smoke test các màn chính
```

### 3.3 Dependencies (`pubspec.yaml`)

Phiên bản dưới đây là **bản thật đã cài** (resolve ngày 2026-10-03, Flutter 3.47.4 / Dart 3.13.3):

```yaml
name: chiahoadon
description: "Chia hóa đơn nhóm - hoạt động hoàn toàn offline"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.13.3

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # State management
  flutter_riverpod: ^3.4.3   # ⚠ v3, không phải v2 — xem §12

  # Lưu trữ local
  sqflite: ^2.4.4
  path: ^1.9.1
  path_provider: ^2.1.6
  shared_preferences: ^2.5.5

  # Tiện ích
  intl: ^0.20.3
  uuid: ^4.6.0               # khóa chính
  collection: ^1.19.1        # firstOrNull, sortedBy, groupBy

  # UI
  fl_chart: ^1.2.0           # ⚠ v1, không phải 0.68 — API đổi, xem §12
  flutter_slidable: ^4.0.3   # swipe để xóa/sửa

  # Chia sẻ & file
  share_plus: ^13.3.1        # chia sẻ text/ảnh sang Zalo, Messenger
  image_picker: ^1.2.3       # ảnh hóa đơn
  file_picker: ^13.1.0       # chọn file để phục hồi backup

  # v1.1 (chưa thêm)
  # qr_flutter                 VietQR
  # local_auth                 khóa app bằng vân tay

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  sqflite_common_ffi: ^2.4.3   # test DAO trên máy tính, không cần emulator
  test: ^1.31.1

flutter:
  uses-material-design: true
  assets:
    - assets/icon/        # ảnh nguồn của icon & splash, không đóng vào app
  fonts:
    - family: BeVietnamPro
      fonts:
        - asset: assets/fonts/BeVietnamPro-Regular.ttf   # weight 400
        - asset: assets/fonts/BeVietnamPro-Medium.ttf     # weight 500
        - asset: assets/fonts/BeVietnamPro-SemiBold.ttf   # weight 600
        - asset: assets/fonts/BeVietnamPro-Bold.ttf       # weight 700
```

> Dùng `flutter pub add <tên>` thay vì gõ tay version — Flutter sẽ tự chọn bản tương thích.

**Font:** 4 weight của Be Vietnam Pro được copy từ `D:/ai_project/chitieu-expo/node_modules/@expo-google-fonts/be-vietnam-pro/` (dự án Expo cũ đã có sẵn), nên không cần tải từ mạng — phù hợp mục tiêu offline. Tổng 540 KB.

**Kiểm tra bắt buộc:** `android/app/src/main/AndroidManifest.xml` **không** được có
`<uses-permission android:name="android.permission.INTERNET" />` (NFR-1). Nếu plugin nào tự thêm vào, chặn bằng:
```xml
<uses-permission android:name="android.permission.INTERNET" tools:node="remove" />
```

---

## 4. Thiết kế cơ sở dữ liệu

### 4.1 Lược đồ quan hệ

```
members ──┬──< group_members >── member_groups ──< bills
          │                                          │
          ├──< bill_payers >────────────────────────┤  (ai ứng tiền, bao nhiêu)
          ├──< bill_participants >──────────────────┤  (ai chịu, phần bao nhiêu)
          ├──< bill_item_participants >─< bill_items ┘ (ai dùng món nào)
          └──< payments >──                            (chuyển tiền thực tế)
                                      categories ──< bills
                                      app_settings · bill_templates
```

### 4.2 DDL đầy đủ (schema v1)

```sql
PRAGMA foreign_keys = ON;

-- ───────────── THÀNH VIÊN ─────────────
CREATE TABLE members (
  id            TEXT PRIMARY KEY,
  name          TEXT    NOT NULL,
  name_norm     TEXT    NOT NULL,              -- bỏ dấu + lowercase, để tìm kiếm
  nickname      TEXT,
  phone         TEXT,
  bank_name     TEXT,
  bank_bin      TEXT,                          -- mã BIN cho VietQR (v1.1)
  bank_account  TEXT,
  bank_holder   TEXT,
  avatar_color  INTEGER NOT NULL,              -- ARGB
  note          TEXT,
  is_self       INTEGER NOT NULL DEFAULT 0,    -- 1 = "Tôi"
  is_active     INTEGER NOT NULL DEFAULT 1,    -- 0 = ngừng hoạt động
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  deleted_at    INTEGER
);
CREATE INDEX idx_members_norm   ON members(name_norm);
CREATE INDEX idx_members_active ON members(is_active, deleted_at);
-- chỉ cho phép đúng 1 thành viên là "Tôi"
CREATE UNIQUE INDEX idx_members_self ON members(is_self) WHERE is_self = 1;

-- ───────────── NHÓM ─────────────
-- Lưu ý: KHÔNG đặt tên bảng là "groups" — GROUPS là từ khóa SQLite 3.28+
CREATE TABLE member_groups (
  id          TEXT PRIMARY KEY,
  name        TEXT    NOT NULL,
  description TEXT,
  color       INTEGER NOT NULL,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  deleted_at  INTEGER
);

CREATE TABLE group_members (
  group_id  TEXT NOT NULL REFERENCES member_groups(id) ON DELETE CASCADE,
  member_id TEXT NOT NULL REFERENCES members(id)       ON DELETE CASCADE,
  PRIMARY KEY (group_id, member_id)
);
CREATE INDEX idx_gm_member ON group_members(member_id);

-- ───────────── DANH MỤC ─────────────
CREATE TABLE categories (
  id         TEXT PRIMARY KEY,
  name       TEXT    NOT NULL,
  icon       TEXT,                              -- tên icon Material
  color      INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_builtin INTEGER NOT NULL DEFAULT 0
);

-- ───────────── HÓA ĐƠN ─────────────
CREATE TABLE bills (
  id                TEXT PRIMARY KEY,
  title             TEXT    NOT NULL,
  -- Tên đã bỏ dấu, để gõ "an lau" tìm được "Ăn lẩu" (FR-3.12).
  -- BillDao tự sinh khi ghi; không nằm trong model Bill. Xem 13.11.
  title_norm        TEXT    NOT NULL DEFAULT '',
  note              TEXT,
  bill_date         INTEGER NOT NULL,           -- epoch ms, 00:00 giờ địa phương
  category_id       TEXT    REFERENCES categories(id)   ON DELETE SET NULL,
  group_id          TEXT    REFERENCES member_groups(id) ON DELETE SET NULL,

  split_type        TEXT    NOT NULL,           -- equal|itemized|percentage|shares|exact
  input_mode        TEXT    NOT NULL,           -- total | items

  subtotal          INTEGER NOT NULL DEFAULT 0, -- trước giảm giá & phụ phí

  -- Giảm giá & phụ phí. *_mode: none|percent|amount
  -- *_value: nếu percent thì là BASIS POINT (8% = 800); nếu amount thì là số đồng
  -- *_amount: số tiền đã tính ra (cache, luôn là đồng)
  discount_mode     TEXT    NOT NULL DEFAULT 'none',
  discount_value    INTEGER NOT NULL DEFAULT 0,
  discount_amount   INTEGER NOT NULL DEFAULT 0,
  tax_mode          TEXT    NOT NULL DEFAULT 'none',
  tax_value         INTEGER NOT NULL DEFAULT 0,
  tax_amount        INTEGER NOT NULL DEFAULT 0,
  service_mode      TEXT    NOT NULL DEFAULT 'none',
  service_value     INTEGER NOT NULL DEFAULT 0,
  service_amount    INTEGER NOT NULL DEFAULT 0,
  tip_amount        INTEGER NOT NULL DEFAULT 0,
  surcharge_alloc   TEXT    NOT NULL DEFAULT 'proportional', -- proportional|equal

  rounding_unit     INTEGER NOT NULL DEFAULT 1000,
  rounding_mode     TEXT    NOT NULL DEFAULT 'up',  -- none|up|nearest
  total_exact       INTEGER NOT NULL DEFAULT 0,     -- trước làm tròn
  total_amount      INTEGER NOT NULL DEFAULT 0,     -- sau làm tròn = Σ share_amount
  rounding_delta    INTEGER NOT NULL DEFAULT 0,     -- total_amount − total_exact

  status            TEXT    NOT NULL DEFAULT 'draft', -- draft|unpaid|partial|settled
  image_path        TEXT,                             -- đường dẫn tương đối
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  deleted_at        INTEGER
);
CREATE INDEX idx_bills_date     ON bills(bill_date DESC);
CREATE INDEX idx_bills_title_norm ON bills(title_norm);
CREATE INDEX idx_bills_status   ON bills(status, deleted_at);
CREATE INDEX idx_bills_group    ON bills(group_id);
CREATE INDEX idx_bills_category ON bills(category_id);

-- ───────────── NGƯỜI ỨNG TIỀN ─────────────
CREATE TABLE bill_payers (
  bill_id     TEXT    NOT NULL REFERENCES bills(id)  ON DELETE CASCADE,
  member_id   TEXT    NOT NULL REFERENCES members(id),
  paid_amount INTEGER NOT NULL,                  -- Σ phải = bills.total_amount
  PRIMARY KEY (bill_id, member_id)
);
CREATE INDEX idx_payers_member ON bill_payers(member_id);

-- ───────────── NGƯỜI THAM GIA (chịu chi phí) ─────────────
CREATE TABLE bill_participants (
  id                   TEXT    PRIMARY KEY,
  bill_id              TEXT    NOT NULL REFERENCES bills(id)  ON DELETE CASCADE,
  member_id            TEXT    NOT NULL REFERENCES members(id),
  member_name_snapshot TEXT    NOT NULL,         -- tên lúc chốt hóa đơn
  sort_order           INTEGER NOT NULL DEFAULT 0,

  -- tham số theo kiểu chia (chỉ 1 nhóm có nghĩa tùy split_type)
  weight_num           INTEGER NOT NULL DEFAULT 1,  -- SHARES: 1.5 phần = 3/2
  weight_den           INTEGER NOT NULL DEFAULT 1,
  percent_bp           INTEGER NOT NULL DEFAULT 0,  -- PERCENTAGE: 33,33% = 3333
  exact_amount         INTEGER NOT NULL DEFAULT 0,  -- EXACT

  base_share           INTEGER NOT NULL DEFAULT 0,  -- phần gốc trước phụ phí (cache)
  share_amount         INTEGER NOT NULL DEFAULT 0,  -- ★ KẾT QUẢ CUỐI (cache)
  paid_amount          INTEGER NOT NULL DEFAULT 0,  -- đã trả cho payer bao nhiêu
  settled_at           INTEGER,                     -- NULL = chưa trả xong
  UNIQUE (bill_id, member_id)
);
CREATE INDEX idx_bp_bill   ON bill_participants(bill_id);
CREATE INDEX idx_bp_member ON bill_participants(member_id);

-- ───────────── MÓN ─────────────
CREATE TABLE bill_items (
  id         TEXT    PRIMARY KEY,
  bill_id    TEXT    NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  name       TEXT    NOT NULL,
  unit_price INTEGER NOT NULL DEFAULT 0,
  quantity   INTEGER NOT NULL DEFAULT 1,
  amount     INTEGER NOT NULL DEFAULT 0,        -- unit_price × quantity
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_items_bill ON bill_items(bill_id, sort_order);

CREATE TABLE bill_item_participants (
  item_id    TEXT    NOT NULL REFERENCES bill_items(id) ON DELETE CASCADE,
  member_id  TEXT    NOT NULL REFERENCES members(id),
  weight_num INTEGER NOT NULL DEFAULT 1,        -- 2 lon bia vs 1 lon → 2/1
  weight_den INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (item_id, member_id)
);
CREATE INDEX idx_iip_member ON bill_item_participants(member_id);

-- ───────────── CHUYỂN TIỀN THỰC TẾ ─────────────
CREATE TABLE payments (
  id             TEXT    PRIMARY KEY,
  bill_id        TEXT    REFERENCES bills(id) ON DELETE SET NULL, -- NULL = quyết toán chung
  from_member_id TEXT    NOT NULL REFERENCES members(id),
  to_member_id   TEXT    NOT NULL REFERENCES members(id),
  amount         INTEGER NOT NULL,
  paid_at        INTEGER NOT NULL,
  method         TEXT,                          -- cash|transfer|other
  note           TEXT,
  created_at     INTEGER NOT NULL
);
CREATE INDEX idx_payments_from ON payments(from_member_id);
CREATE INDEX idx_payments_to   ON payments(to_member_id);
CREATE INDEX idx_payments_bill ON payments(bill_id);

-- ───────────── KHÁC ─────────────
CREATE TABLE bill_templates (
  id           TEXT    PRIMARY KEY,
  name         TEXT    NOT NULL,
  payload_json TEXT    NOT NULL,
  created_at   INTEGER NOT NULL
);

CREATE TABLE app_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

### 4.3 Dữ liệu khởi tạo (`seed_data.dart`)

- **Danh mục:** Ăn uống 🍜 · Du lịch ✈️ · Nhà cửa 🏠 · Đi lại 🚕 · Giải trí 🎮 · Mua sắm 🛒 · Khác 📦
- **Thành viên:** 1 bản ghi `name = 'Tôi'`, `is_self = 1`
- **Cài đặt:** `rounding_unit = 1000` · `rounding_mode = 'up'` · `theme = 'system'` · `schema_version = 1`

### 4.4 Các query quan trọng

**FR-7.1 — Tổng chi phí của từng thành viên**
```sql
SELECT m.id, m.name,
       SUM(bp.share_amount) AS total_spent,
       COUNT(*)             AS bill_count
FROM   bill_participants bp
JOIN   bills   b ON b.id = bp.bill_id
JOIN   members m ON m.id = bp.member_id
WHERE  b.deleted_at IS NULL
  AND  b.status <> 'draft'
  AND  b.bill_date BETWEEN :from AND :to
GROUP  BY m.id
ORDER  BY total_spent DESC;
```

**FR-7.2 — Chi phí từng lần của 1 thành viên**
```sql
SELECT b.id, b.title, b.bill_date, b.total_amount,
       bp.share_amount, bp.paid_amount, bp.settled_at,
       c.name AS category
FROM   bill_participants bp
JOIN   bills b      ON b.id = bp.bill_id
LEFT   JOIN categories c ON c.id = b.category_id
WHERE  bp.member_id = :memberId
  AND  b.deleted_at IS NULL
  AND  b.status <> 'draft'
ORDER  BY b.bill_date DESC, b.created_at DESC;
```

**FR-6.4 — Số dư ròng (ai nợ ai)**
```sql
WITH owed AS (                       -- phải chịu
  SELECT bp.member_id AS mid, SUM(bp.share_amount) AS s
  FROM bill_participants bp JOIN bills b ON b.id = bp.bill_id
  WHERE b.deleted_at IS NULL AND b.status <> 'draft' GROUP BY 1),
advanced AS (                        -- đã ứng trả
  SELECT p.member_id AS mid, SUM(p.paid_amount) AS s
  FROM bill_payers p JOIN bills b ON b.id = p.bill_id
  WHERE b.deleted_at IS NULL AND b.status <> 'draft' GROUP BY 1),
sent AS (SELECT from_member_id AS mid, SUM(amount) AS s FROM payments GROUP BY 1),
recv AS (SELECT to_member_id   AS mid, SUM(amount) AS s FROM payments GROUP BY 1)
SELECT m.id, m.name,
       COALESCE(advanced.s,0) - COALESCE(owed.s,0)
     + COALESCE(sent.s,0)     - COALESCE(recv.s,0) AS balance
FROM   members m
LEFT   JOIN owed     ON owed.mid     = m.id
LEFT   JOIN advanced ON advanced.mid = m.id
LEFT   JOIN sent     ON sent.mid     = m.id
LEFT   JOIN recv     ON recv.mid     = m.id
WHERE  m.deleted_at IS NULL
HAVING balance <> 0
ORDER  BY balance DESC;
```
> `balance > 0` → người khác nợ mình · `balance < 0` → mình nợ · Bất biến: **Σ balance = 0**.

**FR-7.6 — Tổng chi 12 tháng gần nhất**
```sql
SELECT strftime('%Y-%m', bill_date/1000, 'unixepoch', 'localtime') AS ym,
       SUM(total_amount) AS total, COUNT(*) AS cnt
FROM   bills
WHERE  deleted_at IS NULL AND status <> 'draft'
GROUP  BY ym ORDER BY ym DESC LIMIT 12;
```

### 4.5 Chiến lược migration
`app_database.dart` dùng `onCreate` + `onUpgrade` với `switch` tăng dần:
```dart
Future<void> _onUpgrade(Database db, int from, int to) async {
  for (var v = from + 1; v <= to; v++) {
    await migrations[v]!(db);        // mỗi version 1 hàm, chỉ ALTER/CREATE, không DROP
  }
}
```
Quy tắc: **không bao giờ** xóa cột trong migration; cột mới luôn có `DEFAULT` để bản ghi cũ vẫn đọc được.

---

## 5. Thiết kế màn hình

### 5.1 Điều hướng

```
Bottom Navigation (4 tab)
├── 🏠 Trang chủ        Dashboard
├── 🧾 Hóa đơn          Danh sách + tìm kiếm + lọc
├── 📊 Thống kê         Báo cáo + biểu đồ
└── ⚙️ Khác             Thành viên · Nhóm · Quyết toán · Cài đặt

FAB nổi (tab 1 & 2): + Tạo hóa đơn
```

### 5.2 Danh sách màn hình

| # | Màn hình | FR | Phase |
|---|----------|----|-------|
| S01 | Dashboard | FR-7.8 | 8 |
| S02 | Danh sách hóa đơn | FR-3.11, 3.12 | 4 |
| S03 | Tạo/sửa hóa đơn — **wizard 3 bước** | FR-3.1 → 3.8 | 4, 5, 6 |
| S04 | Chi tiết hóa đơn | FR-4, FR-6.1 | 4 |
| S05 | Danh sách thành viên | FR-1.1, 1.7 | 3 |
| S06 | Thêm/sửa thành viên | FR-1.1 → 1.6 | 3 |
| S07 | Chi tiết thành viên (lịch sử + tổng chi) | FR-7.1, 7.2 | 8 |
| S08 | Danh sách nhóm | FR-2.1 | 3 |
| S09 | Thêm/sửa nhóm | FR-2.1, 2.2 | 3 |
| S10 | Quyết toán | FR-6.4, 6.5 | 7 |
| S11 | Thống kê | FR-7.3 → 7.7 | 8 |
| S12 | Cài đặt | FR-9 | 9 |
| S13 | Sao lưu & phục hồi | FR-8.4, 8.5 | 9 |
| S14 | Xem trước chia sẻ | FR-8.1, 8.2 | 9 |

### 5.3 Phác thảo màn hình chính

**S03 — Wizard tạo hóa đơn**

```
┌─────────────────────────────────────┐
│ ←   Tạo hóa đơn           [Lưu]     │
├─────────────────────────────────────┤
│  ●━━━━━━━●━━━━━━━○                  │
│  Thông tin  Người   Chia tiền       │
├─────────────────────────────────────┤
│                                     │
│  BƯỚC 1 ─ THÔNG TIN                 │
│  Tên hóa đơn *                      │
│  ┌─────────────────────────────────┐│
│  │ Ăn lẩu tất niên                 ││
│  └─────────────────────────────────┘│
│  Ngày        02/10/2026       📅    │
│  Danh mục    🍜 Ăn uống        ▾    │
│  Nhóm        Team Dev          ▾    │
│  📷 Thêm ảnh hóa đơn                │
│                                     │
│  BƯỚC 2 ─ NGƯỜI THAM GIA            │
│  [Chọn cả nhóm] [Chọn tất cả]       │
│  ┌──────┐┌──────┐┌──────┐┌──────┐  │
│  │✓ Dũng││✓ An  ││✓ Bình││  Chi │  │
│  └──────┘└──────┘└──────┘└──────┘  │
│  Người trả trước:  Dũng        ▾    │
│  └ [+ Thêm người cùng ứng tiền]     │
│                                     │
│  BƯỚC 3 ─ CÁCH CHIA                 │
│  ┌────────┬──────────┬───────────┐  │
│  │ Đều ✓  │ Theo món │   Khác ▾  │  │
│  └────────┴──────────┴───────────┘  │
│  Tổng tiền                          │
│  ┌─────────────────────────────────┐│
│  │              750.000 đ          ││
│  └─────────────────────────────────┘│
│  ▸ Phụ phí & giảm giá        [mở]   │
│    VAT        8 %     →  60.000     │
│    Phí DV     5 %     →  37.500     │
│    Giảm giá   0                     │
│    Làm tròn   1.000đ · lên     ▾    │
│                                     │
│  ╔═══ XEM TRƯỚC ══════════════════╗ │
│  ║ Tổng       848.000đ (+500 l.tròn)║│
│  ║ Dũng 283.000   An   283.000     ║ │
│  ║ Bình 282.000                    ║ │
│  ╚════════════════════════════════╝ │
└─────────────────────────────────────┘
```
Khung **XEM TRƯỚC** cập nhật realtime mỗi lần đổi input (NFR-4 < 16ms) — đây là chi tiết UX quan trọng nhất, cho người dùng thấy ngay hệ quả thay đổi.

**S03 bước 3 — chế độ "Theo món"**

```
│  ┌────────┬──────────┬───────────┐  │
│  │  Đều   │Theo món ✓│   Khác ▾  │  │
│  └────────┴──────────┴───────────┘  │
│                                     │
│  Lẩu thái          2 × 250.000      │
│  → 500.000đ          [An, Bình, Chi]│
│    👤 An ✓   Bình ✓   Chi ✓         │
│                                     │
│  Bia Tiger        10 ×  20.000      │
│  → 200.000đ               [An, Bình]│
│    👤 An ✓   Bình ✓   Chi ○         │
│                        [⚖ Trọng số]  │
│                                     │
│  Nước ép           1 ×  50.000      │
│  → 50.000đ                     [Chi]│
│    👤 An ○   Bình ○   Chi ✓         │
│                                     │
│  [+ Thêm món]                       │
│  ───────────────────────────────    │
│  Tạm tính              750.000đ     │
```

Món nào **chưa chọn ai** sẽ hiện nhãn vàng `⚠️ chưa chọn ai → chia đều cho cả nhóm`
để người dùng biết tiền vẫn được tính, không bị bỏ sót (FR-4.2).

**S04 — Chi tiết hóa đơn**

```
┌─────────────────────────────────────┐
│ ←  Ăn lẩu tất niên      ⋮           │
├─────────────────────────────────────┤
│  02/10/2026 · 🍜 Ăn uống            │
│  ┌─────────────────────────────────┐│
│  │  Tổng cộng      848.000 đ       ││
│  │  Trả trước      Dũng            ││
│  │  Chia theo món · 3 người        ││
│  └─────────────────────────────────┘│
│                                     │
│  Tạm tính               750.000     │
│  VAT 8%                + 60.000     │
│  Phí dịch vụ 5%        + 37.500     │
│  Làm tròn lên             + 500     │
│  ─────────────────────────────────  │
│  TỔNG                   848.000     │
│                                     │
│  PHẦN MỖI NGƯỜI   [Tất cả đã trả]  │
│  🔴 An      302.000đ  [Đã trả]      │
│  🟢 Bình    301.000đ  ✓ 03/10       │
│  🟡 Chi     245.000đ  đã trả 100k   │
│  ───────────────────────────────    │
│  Dũng ứng trước 848.000đ, chưa      │
│  tham gia ăn → không chịu phần nào  │
│                                     │
│  ▸ Chi tiết theo món                │
│  📷 Ảnh hóa đơn                     │
│                                     │
│  [📤 Chia sẻ]  [✏️ Sửa]  [📋 Nhân bản]│
└─────────────────────────────────────┘
```

**S07 — Chi tiết thành viên** (đáp ứng trực tiếp FR-7.1 + FR-7.2)

```
┌─────────────────────────────────────┐
│ ←   An                      ✏️       │
├─────────────────────────────────────┤
│         ╭───╮                       │
│         │ A │   An                  │
│         ╰───╯   0912 345 678        │
│                 VCB · 0123456789    │
│  ┌───────────────┬─────────────────┐│
│  │ TỔNG CHI PHÍ  │  ĐANG NỢ        ││
│  │  4.250.000đ   │   302.000đ      ││
│  │  18 hóa đơn   │   2 hóa đơn     ││
│  └───────────────┴─────────────────┘│
│  [Tháng này ▾]                      │
│                                     │
│  LỊCH SỬ TỪNG HÓA ĐƠN               │
│  02/10  Ăn lẩu tất niên             │
│         302.000đ          🔴 chưa   │
│  28/09  Cà phê sáng                 │
│          45.000đ          🟢 đã trả │
│  15/09  Du lịch Đà Lạt              │
│       1.200.000đ          🟢 đã trả │
│  ...                                │
└─────────────────────────────────────┘
```

**S10 — Quyết toán**

```
┌─────────────────────────────────────┐
│ ←   Quyết toán                      │
├─────────────────────────────────────┤
│  SỐ DƯ RÒNG                         │
│  Dũng    +500.000đ  được nhận  🟢   │
│  An      −300.000đ  cần trả    🔴   │
│  Chi     −200.000đ  cần trả    🔴   │
│  Bình           0đ  xong       ⚪   │
│                                     │
│  💡 GỢI Ý: 2 giao dịch là đủ        │
│  ┌─────────────────────────────────┐│
│  │ An  →  Dũng    300.000đ         ││
│  │              [QR] [✓ Đã CK]     ││
│  ├─────────────────────────────────┤│
│  │ Chi →  Dũng    200.000đ         ││
│  │              [QR] [✓ Đã CK]     ││
│  └─────────────────────────────────┘│
│  [+ Ghi nhận chuyển tiền khác]      │
└─────────────────────────────────────┘
```

### 5.4 Hệ thống thiết kế

| Thành phần | Quy ước |
|-----------|---------|
| Theme | Material 3, `ColorScheme.fromSeed` |
| Màu chủ đạo | Xanh teal `#0D9488` (tin cậy, không giống app ngân hàng) |
| Màu trạng thái | Chưa trả `#DC2626` · Một phần `#F59E0B` · Đã trả `#16A34A` |
| Font | Be Vietnam Pro (hỗ trợ dấu tiếng Việt tốt, đã dùng ở `chitieu-expo`) |
| Spacing | Thang 4dp: 4 · 8 · 12 · 16 · 24 · 32 |
| Bán kính | Card 16 · Button 12 · Chip 20 |
| Avatar | Hình tròn, chữ cái đầu, màu từ `hash(name) % 12` trong bảng màu định sẵn |
| Tiền | `NumberFormat.decimalPattern('vi_VN')` + hậu tố ` đ`; **căn phải**, font tabular |

---

## 6. Quản lý state (Riverpod)

```dart
// ── Tầng hạ tầng ───────────────────────────────
databaseProvider              // FutureProvider<Database>, keepAlive
memberRepositoryProvider
billRepositoryProvider
statsRepositoryProvider
settlementRepositoryProvider
preferencesProvider

// ── Danh sách ──────────────────────────────────
membersProvider               // AsyncNotifier<List<Member>>
groupsProvider
billListProvider              // AsyncNotifier, nhận BillFilter, phân trang
billFilterProvider            // Notifier<BillFilter> (tìm kiếm, ngày, nhóm...)
billDetailProvider(billId)    // family

// ── Form hóa đơn (★ phức tạp nhất) ─────────────
billFormProvider              // AutoDisposeNotifier<BillFormState>
  // state bất biến: thông tin + participants + items + surcharges
  // mọi thao tác UI → copyWith → rebuild
splitPreviewProvider          // Provider<SplitResult>
  // = computeSplit(ref.watch(billFormProvider).toSplitInput())
  // ĐỒNG BỘ → khung xem trước cập nhật ngay trong frame

// ── Thống kê ───────────────────────────────────
statsPeriodProvider           // Notifier<DateRange>
memberStatsProvider           // FutureProvider, phụ thuộc statsPeriodProvider
memberTimelineProvider(id)    // family — FR-7.2
monthlyStatsProvider
categoryStatsProvider
balancesProvider              // FR-6.4
settlementPlanProvider        // FR-6.5, phụ thuộc balancesProvider

// ── Cài đặt ────────────────────────────────────
themeModeProvider
roundingSettingsProvider
```

**Quy tắc:** `splitPreviewProvider` **bắt buộc** là `Provider` đồng bộ (không `FutureProvider`) — vì `computeSplit` là pure và nhanh. Nếu dùng async, khung xem trước sẽ nhấp nháy khi gõ số tiền.

---

## 7. Lộ trình triển khai

> Đơn vị: **ngày-người**. Mỗi phase kết thúc phải **chạy được và test được**.

### Phase 0 — Khởi tạo · 0,5 ngày · ✅ XONG (2026-10-03)
- [x] `flutter create --org com.dtd --platforms android,ios chiahoadon` (chạy trong thư mục này, giữ lại PLAN.md/SPEC.md)
- [x] Thêm dependencies · cấu hình `analysis_options.yaml` (bật `flutter_lints` + `prefer_const`)
- [x] Tạo cây thư mục theo §3.2 · font Be Vietnam Pro
- [x] `app_theme.dart` sáng/tối · `money_formatter.dart` · `date_formatter.dart`
- [x] **Xóa quyền INTERNET** khỏi AndroidManifest + xác minh bằng `aapt dump permissions`
- ✅ *Done khi:* `flutter run` hiện màn hình trắng có AppBar đúng theme, `flutter analyze` sạch

### Phase 1 — Tầng dữ liệu · 1,5 ngày · ✅ XONG (2026-10-03)
- [x] `app_database.dart`: mở DB, `PRAGMA foreign_keys = ON`, `onCreate` toàn bộ DDL §4.2
- [x] `migrations.dart` khung switch · `seed_data.dart` §4.3
- [x] Toàn bộ model trong `domain/models/` (immutable, `copyWith`, `fromMap`/`toMap`)
- [x] DAO: member, group, bill, payment, stats
- [x] Repository bọc DAO, trả `Result<T, AppError>`
- [x] Cấu hình `sqflite_common_ffi` cho test
- ✅ *Done khi:* test tạo DB in-memory, insert/đọc 1 thành viên + 1 hóa đơn thành công

### Phase 2 — ★ SPLIT ENGINE · 2 ngày · ✅ XONG (2026-10-03)
- [x] `split_input.dart` / `split_result.dart` (bất biến, không phụ thuộc DB)
- [x] `rounding.dart`: `roundTotal()` + `largestRemainder()` — SPEC FR-5
- [x] `equal_strategy.dart` · `itemized_strategy.dart` (gồm trọng số + món không ai chọn)
- [x] `percentage_strategy.dart` · `shares_strategy.dart` · `exact_strategy.dart`
- [x] `surcharge_allocator.dart` — chế độ `proportional` và `equal`
- [x] `split_validator.dart` — trả danh sách lỗi có thể hiện lên UI
- [x] `split_engine.dart` ghép các bước theo đúng thứ tự §FR-5
- [x] **Unit test: toàn bộ 20 case ở §8.1 + property test 10.000 lần random**
- ✅ *Done khi:* `flutter test test/domain/split/` xanh 100%, coverage ≥ 90%, **không có case nào `Σ share != total`**

> ✅ **Điều kiện này đã đạt:** 159 test xanh, coverage split engine **98,0%**, 29.000 hóa đơn ngẫu nhiên không có trường hợp nào `Σ share != total`. Phase 4 được phép bắt đầu.

### Phase 3 — Thành viên & Nhóm · 1,5 ngày · ✅ XONG (2026-10-03)
- [x] S05 danh sách thành viên: avatar, tìm kiếm, swipe sửa/ngừng hoạt động
- [x] S06 form thành viên: tên, biệt danh, SĐT, ngân hàng, cảnh báo trùng tên
- [x] Soft delete + chặn xóa cứng khi đã có hóa đơn (FR-1.5)
- [x] Đánh dấu "Tôi" (FR-1.6) · nhập nhanh nhiều tên (FR-1.8)
- [x] S08 / S09 nhóm + chọn thành viên
- [x] `MemberAvatar`, `MemberChip`, `MemberPickerSheet` dùng chung
- ✅ *Done khi:* thêm 5 thành viên + 1 nhóm, kill app, mở lại vẫn còn đủ

### Phase 4 — Hóa đơn + Chia đều · 2,5 ngày · ✅ XONG (2026-10-03)
- [x] S03 khung wizard 3 bước (`PageView` + stepper)
- [x] `BillFormState` (lớp bất biến, **không** dùng provider — xem 13.10) + `MoneyField`
- [x] Bước 1 thông tin · Bước 2 chọn người & payer · Bước 3 chia đều
- [x] **Khung XEM TRƯỚC realtime** — `computeSplit` gọi thẳng trong `build`
- [x] Ghi hóa đơn trong 1 **transaction** (bills + payers + participants)
- [x] S02 danh sách: phân trang 50, tìm kiếm, lọc theo ngày/nhóm/danh mục/trạng thái
- [x] S04 chi tiết + breakdown + xóa có Undo + nhân bản
- [x] Auto-save draft mỗi 3 giây (NFR-10)
- ✅ *Done khi:* tạo hóa đơn 1.000.000đ / 3 người → UI hiện 334.000/333.000/333.000, tổng khớp

### Phase 5 — Chia theo món · 2 ngày · ✅ XONG (2026-10-03)
- [x] UI danh sách món: thêm/sửa/xóa, kéo sắp xếp, auto `amount = giá × SL`
- [x] Chọn người cho từng món (chip bật/tắt), mặc định chọn hết
- [x] Nút nhanh "của riêng…" / "chia đều món này"
- [x] Bảng nhập trọng số trong món (bottom sheet)
- [x] Cảnh báo vàng cho món chưa chọn ai (FR-4.2)
- [x] Mục "Chi tiết theo món" ở S04 — hiện rõ mỗi người chịu món nào
- ✅ *Done khi:* chạy đúng ví dụ SPEC FR-4.2 → phần gốc An 266.667 · Bình 266.667 · Chi 216.666 (số cuối sau làm tròn 1.000đ là 267.000 / 267.000 / 216.000 — xem 13.13)

### Phase 6 — Phụ phí & các kiểu chia còn lại · 1,5 ngày · ✅ XONG (2026-10-03)
- [x] Panel thu gọn "Phụ phí & giảm giá": VAT / phí DV / tip / giảm giá, chuyển % ↔ số tiền
- [x] Chọn đơn vị + cách làm tròn ngay trong form, hiện rõ `rounding_delta`
- [x] Công tắc phân bổ phụ phí: theo tỷ lệ / chia đều
- [x] UI chia theo % (thanh tiến trình + số % còn thiếu)
- [x] UI chia theo số phần (stepper +/−)
- [x] UI chia theo số tiền chỉ định (hiện số dư chưa phân bổ)
- [x] Hỏi xác nhận khi đổi kiểu chia
- ✅ *Done khi:* chạy đúng ví dụ kiểm chứng SPEC §FR-5 → 302.000 / 301.000 / 245.000

### Phase 7 — Thanh toán & Quyết toán · 1,5 ngày · ✅ XONG (2026-10-03)
- [x] Đánh dấu đã trả / trả một phần từng người ở S04
- [x] Tự suy ra `bills.status` · nút "Tất cả đã trả"
- [x] `balance_calculator.dart` + query §4.4
- [x] `debt_simplifier.dart` (greedy, 2 max-heap) + unit test
- [x] S10 Quyết toán: số dư + danh sách giao dịch gợi ý + "Đã chuyển khoản"
- [x] Ghi nhận chuyển tiền độc lập (FR-6.6)
- ✅ *Done khi:* Σ balance = 0 sau mọi thao tác; 3 người lệch nhau → đúng 2 giao dịch gợi ý

### Phase 8 — Thống kê · 2 ngày · ✅ XONG (2026-10-03)
- [x] S01 Dashboard: 4 chỉ số + hóa đơn gần đây + ai nợ tôi
- [x] S11 Thống kê: chọn kỳ, bảng xếp hạng, biểu đồ cột theo người (`fl_chart`)
- [x] Biểu đồ tròn tỷ trọng · biểu đồ 12 tháng · thống kê theo danh mục
- [x] **S07 Chi tiết thành viên: tổng chi + dòng thời gian từng hóa đơn** ← FR-7.1 + FR-7.2
- [x] Thống kê theo nhóm
- ✅ *Done khi:* 20 hóa đơn mẫu → số tổng trên biểu đồ bằng số tính tay

### Phase 9 — Chia sẻ, sao lưu, cài đặt · 1,5 ngày · ✅ XONG (2026-10-03)
- [x] `share_service.dart`: sinh text theo mẫu FR-8.1 + `share_plus`
- [x] Render widget → PNG (`RepaintBoundary` + `toImage`) rồi chia sẻ ảnh
- [x] `backup_service.dart`: export toàn bộ ra JSON có `schema_version`
- [x] Phục hồi: đọc file, kiểm tra version, hỏi *ghi đè / gộp*, chạy trong transaction
- [x] S12 Cài đặt: theme, làm tròn mặc định, quản lý danh mục, xóa toàn bộ dữ liệu
- [x] Ảnh hóa đơn: chụp/chọn, lưu vào documents dir, xem toàn màn hình
- ✅ *Done khi:* backup → xóa sạch dữ liệu → phục hồi → mọi hóa đơn và số tiền y nguyên

### Phase 10 — Hoàn thiện & phát hành · 1,5 ngày · ✅ XONG (2026-10-03)
- [x] Empty state cho mọi danh sách · loading skeleton · xử lý lỗi thống nhất
- [x] Kiểm tra màn 360dp · test chế độ tối · font scale 1.3× (`test/widget/layout_test.dart`)
- [x] Test hiệu năng: seed 1.000 hóa đơn (`test/data/performance_test.dart`)
- [x] Icon app + splash screen (sinh bằng `tool/generate_icon.dart`)
- [x] `flutter build apk --release --split-per-abi` + đo dung lượng (NFR-5)
- [x] Cài lên emulator, chạy bộ smoke test §8.3 (`integration_test/smoke_test.dart`)
- ✅ *Done khi:* APK cài được, chạy không crash, `flutter analyze` 0 cảnh báo

### Phase 11 — Tùy chọn (v1.1) · 2 ngày · ✅ XONG (2026-10-03)
- [x] VietQR: `banks.json` + sinh chuỗi EMVCo TLV + `qr_flutter` (offline hoàn toàn)
- [x] Khóa app bằng `local_auth` — dùng mã khóa máy làm đường dự phòng, **không** tự quản lý PIN riêng (xem 13.18)
- [x] Xuất CSV (FR-8.3)
- [~] Hóa đơn mẫu định kỳ — **không làm**: nhân bản hóa đơn (FR-3.15) đã có từ Phase 4 và giải quyết đúng nhu cầu đó

### Phase 12 — Theo yêu cầu sau khi dùng thử (v1.2) · 1 ngày · ✅ XONG (2026-10-03)
- [x] Danh sách món đặt sẵn tên và giá; khi nhập hóa đơn chỉ cần chọn (FR-3.18, FR-9.9)
- [x] Lưu nhanh món vừa gõ tay vào danh sách để dùng lần sau (FR-3.19)
- [x] Lọc thống kê theo tuần + biểu đồ gộp theo tuần (FR-7.11)
- [x] Mọi kỳ thống kê ghi rõ khoảng ngày, ở cả màn Thống kê lẫn chi tiết thành viên (FR-7.12)
- [x] Chọn danh mục là tên hóa đơn được điền theo (FR-3.1, xem 13.21)
- [x] Danh sách hóa đơn ghi đủ ngày/tháng/năm thay vì "Hôm nay"

### Phase 13 — Sửa logic chia theo món (v1.3) · 0,5 ngày · ✅ XONG (2026-10-03)
- [x] Giá trên món là **giá một người**; thành tiền = giá × số phần (FR-4.2, xem 13.25)
- [x] Bỏ ô "số lượng" chung của món; số lượng nằm ở từng người dưới dạng số phần
- [x] Giao diện viết hẳn phép nhân ra: `50.000 đ × 2 phần = 100.000 đ` (13.26)
- [x] Quản lý danh sách món thêm lối vào ở tab "Khác"
- [x] Viết lại ví dụ kiểm chứng của SPEC §FR-4.2 và §FR-5 theo quy tắc mới

### Phase 14 — Báo cáo thành viên × danh mục (v1.3) · 0,5 ngày · ✅ XONG (2026-10-04)
- [x] Truy vấn chéo `member × category` cộng trên `share_amount` (FR-7.13)
- [x] Ô thả xuống chọn danh mục, bên dưới là chi phí từng thành viên trong danh mục đó
- [x] Ẩn bớt thành viên khỏi mục này, kèm nút hiện lại (FR-7.14)
- [x] Test đối chiếu tổng các dòng của một người với bảng xếp hạng FR-7.1
- [x] Kiểm trên emulator bằng ảnh chụp cắt phóng to — bắt được lỗi ô màu cao 0 pixel (13.27)

### Phase 15 — Chia sẻ báo cáo lên Mattermost (v1.3) · 0,5 ngày · ✅ XONG (2026-10-04)
- [x] `ShareText.forCategoryReport` — bảng markdown cho Mattermost (FR-8.7)
- [x] Màn xem trước: gửi text, gửi ảnh PNG, chép nội dung
- [x] Nội dung ghi rõ kỳ, tổng, và số người đang bị ẩn
- [x] Đi qua bảng chia sẻ của hệ điều hành — bản release vẫn không có quyền INTERNET (NFR-1)

### Phase 16 — Ưu tiên chọn món có sẵn khi chia theo món (v1.3) · 0,25 ngày · ✅ XONG (2026-10-04)
- [x] Chia theo món đứng đầu dãy nút kiểu chia và là mặc định của hóa đơn mới (FR-3.20)
- [x] Mặc định chỉ đặt ở `BillFormState.create`; sửa hóa đơn đã lưu vẫn giữ kiểu chia của nó
- [x] Sheet thêm món không còn `autofocus` — bàn phím không tự bật (kiểm bằng `dumpsys input_method` trên emulator)
- [x] Có món sẵn thì "Chọn món có sẵn" là nút đặc (tonal); chưa có thì giữ nút viền để không lấn ô nhập tay
- [x] Test bỏ `autofocus` ra thì đỏ, đặt lại thì xanh

**Thứ tự enum cũng là thứ tự nút.** `SplitType` khai báo `itemized` trước `equal` nên
`SplitType.values` ra đúng thứ tự mới mà không cần danh sách riêng. DB lưu `dbValue`
chứ không lưu chỉ số, nên đổi thứ tự là an toàn — đã tìm trong `lib/` không chỗ nào
dùng `.index`.

**`inputMode` phải đi cùng `splitType`.** Đặt `splitType: itemized` mà để `inputMode:
total` thì validator báo `itemizedNeedsItems` sai chỗ ngay khi chưa ai làm gì;
`create` đặt cả hai. Mười chín test cũ giả định "chia đều là mở sẵn" nên được đổi sang
chọn chia đều **tường minh** (`WidgetTestHelper.chooseEqualSplit`), thay vì nới lỏng
khẳng định — đó đúng là thao tác người dùng giờ phải làm.

### Phase 17 — Mã QR nhận tiền trong ảnh chia sẻ (v1.3) · 0,25 ngày · ✅ XONG (2026-10-04)
- [x] `ShareCard.qrPayload`: dựng VietQR của người trả trước, dùng lại `buildVietQr` (FR-8.8)
- [x] Thẻ ảnh có khối QR cạnh số tài khoản; nền trắng, viền đệm cố định
- [x] Màn xem trước nhắc khi có tài khoản mà thiếu ngân hàng; lời nhắc nằm ngoài vùng chụp
- [x] Gỡ dòng placeholder "Chia sẻ kết quả sẽ có ở Phase 9" còn sót ở màn chi tiết hóa đơn

**QR tĩnh, không điền số tiền.** Ảnh hóa đơn có nhiều người nợ những số khác nhau mà
chỉ một mã; điền tổng hay phần của một người thì những người còn lại quét ra sai
tiền. Người quét tự nhập phần của mình, đọc ngay trong danh sách trên mã. Phương án
"mỗi người một QR có sẵn số tiền" đã cân nhắc và bỏ: ảnh dài gấp nhiều lần, và trên
nhóm đông thì người ta tìm mã của mình lâu hơn là gõ một con số.

**Dùng lại đúng bộ sinh mã của màn "Chuyển khoản".** Một test khẳng định chuỗi QR trên
ảnh bằng đúng chuỗi `buildVietQr` sinh cho cùng ngân hàng/tài khoản/nội dung — hai
nơi sinh hai chuỗi khác nhau là một nơi sai mà không ai biết nơi nào.

**Còn phải kiểm tay:** quét thử QR **trên ảnh đã gửi qua chat** bằng app ngân hàng thật.
Emulator chỉ cho xác nhận mã hiện đúng và không lỗi khi chụp; ảnh bị chat nén lại rồi
mới quét là chuyện chỉ máy thật mới trả lời được (đã nằm trong mục quét QR ở §14).

**Một dòng thừa tìm ra nhờ chụp màn hình.** Mở màn chi tiết hóa đơn để vào phần chia sẻ,
thấy dòng "Chia sẻ kết quả sẽ có ở Phase 9" — chú thích của giai đoạn dựng app, nói
dối về tính năng đang nằm ngay trên thanh tiêu đề. 500 test không ai kiểm chữ này vì
không ai nghĩ tới; có test chặn chữ "Phase" xuất hiện lại.

### Phase 18 — Mã QR trong ảnh báo cáo theo danh mục (v1.3) · 0,25 ngày · ✅ XONG (2026-10-04)
- [x] Tách `PaymentQrBlock` dùng chung cho ảnh hóa đơn và ảnh báo cáo (FR-8.8)
- [x] Ảnh báo cáo có QR của "Tôi"; màn xem trước nhắc khi thiếu thông tin nhận tiền
- [x] Ảnh hóa đơn đổi sang dùng `PaymentQrBlock`, test cũ giữ nguyên và vẫn xanh

**Người nhận là "Tôi".** Báo cáo không có "người trả trước" như hóa đơn nên phải chọn một
người. Chọn "Tôi" vì người bấm chia sẻ báo cáo để đi thu tiền gần như luôn là người dùng
app. Đây là **giả định**, không phải điều SPEC cũ nêu; nếu nhóm có người thu tiền khác thì
cần ô chọn người nhận trên màn xem trước — chưa làm vì chưa có ai cần.

**Tách khối chung thay vì chép.** Hai ảnh sinh QR theo hai đường khác nhau thì có ngày một
đường sửa mà đường kia không, và hai chuỗi QR cho cùng một tài khoản là một chuỗi sai mà
không ai biết chuỗi nào. `ShareCard.qrPayload` giữ nguyên chữ ký, chỉ còn ủy quyền cho
`PaymentQrBlock.payload` — nên 10 test của Phase 17 chạy lại không phải sửa dòng nào.

**Hạn chế kiểm thử:** `QrImageView` không lộ chuỗi dữ liệu ra ngoài, nên test "QR tĩnh"
của ảnh báo cáo kiểm hàm sinh mà khối QR gọi chứ không đọc ngược từ widget. Chấp nhận được
vì khối QR không có đường sinh nào khác; chuỗi thật vẫn chỉ xác nhận được bằng app ngân hàng.

### Tổng hợp

| Phase | Nội dung | Ngày | Lũy kế |
|-------|----------|------|--------|
| 0 | Khởi tạo | 0,5 | 0,5 |
| 1 | Tầng dữ liệu | 1,5 | 2,0 |
| 2 | ★ Split engine | 2,0 | 4,0 |
| 3 | Thành viên & nhóm | 1,5 | 5,5 |
| 4 | Hóa đơn + chia đều | 2,5 | 8,0 |
| 5 | Chia theo món | 2,0 | 10,0 |
| 6 | Phụ phí & kiểu chia khác | 1,5 | 11,5 |
| 7 | Thanh toán & quyết toán | 1,5 | 13,0 |
| 8 | Thống kê | 2,0 | 15,0 |
| 9 | Chia sẻ & sao lưu | 1,5 | 16,5 |
| 10 | Hoàn thiện & phát hành | 1,5 | **18,0** |
| 11 | Tùy chọn v1.1 | 2,0 | 20,0 |

**MVP dùng được thật** = Phase 0 → 5 ≈ **10 ngày**. Từ Phase 6 trở đi là nâng cấp dần, mỗi phase đều có thể phát hành.

---

## 8. Kế hoạch kiểm thử

### 8.1 Unit test split engine — bắt buộc đạt 100%

| TC | Input | Kết quả mong đợi |
|----|-------|------------------|
| TC-01 | EQUAL 1.000.000 / 3 người · unit 1.000 | 334.000 / 333.000 / 333.000 · Σ = 1.000.000 |
| TC-02 | EQUAL 100.000 / 3 người · unit 1 | 33.334 / 33.333 / 33.333 |
| TC-03 | EQUAL 7 / 3 người · unit 1 | 3 / 2 / 2 |
| TC-04 | EQUAL · 1 người | người đó nhận toàn bộ |
| TC-05 | 0 người tham gia | `ValidationError`, không crash |
| TC-06 | ITEMIZED ví dụ FR-4.2 | 266.667 / 266.667 / 216.667 (unit 1) |
| TC-07 | ITEMIZED, 1 món không ai chọn | món đó chia đều cho tất cả · Σ khớp |
| TC-08 | ITEMIZED có trọng số 2:1 | tỷ lệ đúng 2:1, Σ khớp |
| TC-09 | PERCENTAGE 50/30/20 của 1.000.000 | 500k / 300k / 200k |
| TC-10 | PERCENTAGE tổng = 99% | `ValidationError` |
| TC-11 | SHARES 2:1:1 của 6.000.000 | 3.000k / 1.500k / 1.500k |
| TC-12 | SHARES toàn bộ = 0 | `ValidationError` |
| TC-13 | EXACT khớp tổng / lệch tổng | pass / `ValidationError` |
| TC-14 | subtotal 750k · giảm 10% · VAT 8% · DV 5% | base 675k · VAT 54k · DV 33.750 · exact 762.750 |
| TC-15 | Giảm giá > subtotal | kẹp về 0, không âm |
| TC-16 | total = 0 | mọi phần = 0, không chia cho 0 |
| TC-17 | unit 5.000 · exact 847.500 · mode up | total 850.000 · mọi phần là bội 5.000 · Σ = 850.000 |
| TC-18 | Phụ phí `surcharge_alloc = equal` | phụ phí chia đều, Σ khớp |
| TC-19 | 1 người weight 0 | người đó nhận 0, Σ vẫn khớp |
| TC-20 | Payer không nằm trong participants | share = 0 · balance dương đúng số đã ứng |
| **TC-P1** | **Property test:** 10.000 lần random (2–20 người, 0–30 món, phụ phí & unit random) | **`Σ share == total` tuyệt đối trong mọi lần** |
| **TC-P2** | Property test: gọi `computeSplit` cùng input 2 lần | kết quả **giống hệt** (tính xác định) |

### 8.2 Unit test quyết toán

| TC | Input | Kết quả mong đợi |
|----|-------|------------------|
| TC-S1 | An +500k · Bình −300k · Chi −200k | 2 giao dịch: Bình→An 300k · Chi→An 200k |
| TC-S2 | 4 người, mọi balance = 0 | 0 giao dịch |
| TC-S3 | 5 người lệch nhau | ≤ 4 giao dịch · sau khi thực hiện mọi balance = 0 |
| TC-S4 | Property: 1.000 lần random balance (Σ = 0) | Σ số tiền chuyển = Σ balance dương · số giao dịch ≤ n−1 |

### 8.3 Smoke test tay (chạy trước mỗi lần build release)

1. Mở app lần đầu → có thành viên "Tôi" + 7 danh mục mặc định
2. Thêm 4 thành viên → tạo 1 nhóm chứa cả 4
3. Tạo hóa đơn chia đều 1.000.000 / 3 người → kiểm tra Σ = 1.000.000
4. Tạo hóa đơn theo món đúng ví dụ FR-4.2 + VAT 8% + DV 5% → kiểm tra 302/301/245
5. Đánh dấu 1 người đã trả, 1 người trả một phần → trạng thái hóa đơn = "Một phần"
6. Mở Quyết toán → Σ balance = 0, số giao dịch gợi ý tối thiểu
7. Mở chi tiết 1 thành viên → tổng chi + lịch sử từng hóa đơn đúng
8. Chia sẻ hóa đơn → text hiển thị đúng trong Zalo
9. Sao lưu → xóa toàn bộ dữ liệu → phục hồi → đối chiếu đủ
10. Bật chế độ tối → mọi màn hình đọc được
11. Bật chế độ máy bay → app hoạt động bình thường (NFR-1)
12. Kill app giữa lúc nhập hóa đơn → mở lại thấy draft

---

## 9. Rủi ro & đối phó

| # | Rủi ro | Khả năng | Tác động | Đối phó |
|---|--------|----------|----------|---------|
| R1 | Split engine sai → tổng không khớp | Trung bình | **Rất cao** (mất toàn bộ niềm tin) | Làm ở Phase 2 trước UI · property test 10.000 lần · bất biến `Σ == total` được assert ngay trong code production (`assert`) |
| R2 | UI form hóa đơn phình to, khó bảo trì | Cao | Trung bình | 1 `BillFormState` bất biến duy nhất · tách widget con theo bước · mọi tính toán đẩy vào `domain` |
| R3 | Mất dữ liệu (không có cloud backup) | Trung bình | **Rất cao** | Backup JSON là chức năng **Must** (Phase 9) · nhắc backup sau 30 ngày · phục hồi chạy trong transaction |
| R4 | Migration DB làm hỏng dữ liệu cũ | Thấp | Cao | Không bao giờ DROP cột · cột mới luôn có DEFAULT · test migration v1→v2 với DB mẫu |
| R5 | Sửa hóa đơn đã thanh toán gây lệch số | Trung bình | Trung bình | Cảnh báo trước khi sửa · giữ `paid_amount` · hiện rõ "trả thừa/thiếu X đ" |
| R6 | Plugin tự thêm quyền INTERNET | Trung bình | Trung bình | `tools:node="remove"` trong manifest · kiểm tra bằng `aapt dump permissions` ở Phase 10 |
| R7 | Hiệu năng kém khi nhiều hóa đơn | Thấp | Trung bình | Index trên `bill_date` · phân trang 50 · cache `share_amount` thay vì tính lại |
| R8 | Phạm vi phình to (OCR, QR, đa tiền tệ) | **Cao** | Cao | Danh sách §2 đã chốt rõ v1.0 / v1.1 / v2.0 / Không làm — **không thêm gì vào v1.0** |
| R9 | Đơn vị làm tròn 1.000đ gây tranh cãi "sao tôi trả nhiều hơn 1k" | Trung bình | Thấp | Hiện rõ dòng "Làm tròn +500đ" trên S04 · cho đổi về unit 1đ trong cài đặt |

---

## 10. Việc cần làm ngay (nếu bạn bật đèn xanh)

```bash
cd D:/ai_project/chiahoadon
flutter create --org com.dtd --project-name chiahoadon --platforms android,ios .
flutter pub add flutter_riverpod sqflite path path_provider shared_preferences \
                intl uuid collection fl_chart flutter_slidable share_plus \
                image_picker file_picker
flutter pub add --dev sqflite_common_ffi test
```

Rồi theo đúng thứ tự: **Phase 0 → 1 → 2 (dừng lại, chạy test cho xanh) → 3 → ...**

---

## 11. Phụ lục — Khung code split engine

```dart
// lib/domain/split/split_engine.dart   ★ pure Dart, không import Flutter

SplitResult computeSplit(SplitInput input) {
  final errors = SplitValidator.validate(input);
  if (errors.isNotEmpty) return SplitResult.invalid(errors);

  // 1-6. Tính tổng chính xác theo thứ tự cố định (SPEC FR-5)
  final subtotal = input.inputMode == InputMode.items
      ? input.items.fold(0, (s, it) => s + it.amount)
      : input.manualTotal;

  final discount = _resolve(input.discount, base: subtotal).clamp(0, subtotal);
  final base     = subtotal - discount;
  final tax      = _resolve(input.tax,     base: base);
  final service  = _resolve(input.service, base: base);
  final totalExact = base + tax + service + input.tip;

  // 7. Làm tròn TỔNG trước, để mọi phần đều là bội của unit
  final total = Rounding.roundTotal(
      totalExact, input.roundingUnit, input.roundingMode);

  if (total == 0) return SplitResult.allZero(input.participants);

  // 8. Phần gốc theo kiểu chia — chiến lược hoán đổi được
  final strategy = SplitStrategy.of(input.splitType);
  final baseShares = strategy.baseShares(input);   // Map<memberId, int>

  // 9. Phân bổ phụ phí + giảm giá lên phần gốc
  final exactShares = SurchargeAllocator(input.surchargeAlloc)
      .allocate(baseShares: baseShares, total: total);

  // 10. Largest Remainder — bảo đảm Σ == total TUYỆT ĐỐI
  final shares = Rounding.largestRemainder(
      exactShares, total: total, unit: input.roundingUnit);

  assert(shares.values.fold(0, (a, b) => a + b) == total,
      'BẤT BIẾN BỊ VI PHẠM: tổng các phần != tổng hóa đơn');

  return SplitResult(
    subtotal: subtotal, discountAmount: discount,
    taxAmount: tax, serviceAmount: service, tipAmount: input.tip,
    totalExact: totalExact, total: total,
    roundingDelta: total - totalExact,
    baseShares: baseShares, shares: shares,
  );
}

/// percent lưu dạng basis point: 8% → 800
int _resolve(Surcharge s, {required int base}) => switch (s.mode) {
      SurchargeMode.none    => 0,
      SurchargeMode.percent => (base * s.value) ~/ 10000,
      SurchargeMode.amount  => s.value,
    };
```

```dart
// lib/domain/split/rounding.dart

class Rounding {
  static int roundTotal(int exact, int unit, RoundingMode mode) =>
      switch (mode) {
        RoundingMode.none    => exact,
        RoundingMode.up      => ((exact + unit - 1) ~/ unit) * unit,
        RoundingMode.nearest => ((exact + unit ~/ 2) ~/ unit) * unit,
      };

  /// Phân bổ `total` theo tỷ lệ `exact`, mọi kết quả là bội của `unit`,
  /// và Σ kết quả == total một cách tuyệt đối (Largest Remainder / Hamilton).
  static Map<String, int> largestRemainder(
      Map<String, int> exact, {required int total, required int unit}) {
    final floors = {
      for (final e in exact.entries) e.key: (e.value ~/ unit) * unit
    };
    final distributed = floors.values.fold(0, (a, b) => a + b);
    var k = (total - distributed) ~/ unit;

    // Sắp xếp ổn định: phần dư giảm dần → exact giảm dần → thứ tự gốc
    final order = exact.keys.toList()
      ..sort((a, b) {
        final ra = exact[a]! - floors[a]!, rb = exact[b]! - floors[b]!;
        if (ra != rb) return rb.compareTo(ra);
        return exact[b]!.compareTo(exact[a]!);
      });

    final result = Map<String, int>.from(floors);
    for (var i = 0; i < k && i < order.length; i++) {
      result[order[i]] = result[order[i]]! + unit;
    }
    return result;
  }
}
```

---

## 12. Nhật ký triển khai

### Phase 0 — Khởi tạo · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `flutter create` (org `com.dtd`, android + ios) | ✅ |
| Cài 13 dependency + 3 dev dependency | ✅ |
| Cây thư mục theo §3.2 | ✅ |
| Font Be Vietnam Pro (4 weight, nguồn local) | ✅ |
| `app_theme.dart` sáng/tối Material 3 | ✅ |
| `money_formatter` · `date_formatter` · `vn_text` · `avatar_color` · `result` | ✅ |
| `analysis_options.yaml` siết lint | ✅ |
| Chặn quyền INTERNET ở bản release | ✅ **đã kiểm chứng bằng aapt** |
| `flutter analyze` sạch | ✅ 0 issue |

### Phase 1 — Tầng dữ liệu · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `schema.dart` — 12 bảng + 15 chỉ mục | ✅ |
| `app_database.dart` — mở DB, `PRAGMA foreign_keys = ON` | ✅ |
| `migrations.dart` — khung nâng cấp theo từng version | ✅ |
| `seed_data.dart` — 7 danh mục, thành viên "Tôi", 4 cài đặt | ✅ |
| 10 model bất biến trong `domain/models/` | ✅ |
| 7 DAO: member, group, bill, payment, category, settings, stats | ✅ |
| 5 repository trả `Result<T>` | ✅ |
| Riverpod provider cho DB / DAO / repository | ✅ |
| Test DB in-memory qua `sqflite_common_ffi` | ✅ **64 test xanh** |

### Phase 2 — ★ Split engine · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `split_input.dart` — `SplitInput`, `SplitParticipant`, `SplitItem`, `SplitLimits` | ✅ |
| `split_result.dart` — đủ mốc tiền cho bảng bóc tách ở màn chi tiết | ✅ |
| `rounding.dart` — `roundTotal`, `effectiveUnit`, `distribute`, `lcm` | ✅ |
| 5 chiến lược: equal · itemized · percentage · shares · exact | ✅ |
| `surcharge_allocator.dart` — `proportional` và `equal` | ✅ |
| `split_validator.dart` — 12 mã lỗi, thông điệp tiếng Việt | ✅ |
| `split_engine.dart` — `computeSplit`, hàm thuần | ✅ |
| `SplitInput.fromBill` — cầu nối tính lại hóa đơn đã lưu (FR-3.13) | ✅ |
| **Coverage split engine** | ✅ **98,0%** (350/357 dòng) |

```
flutter analyze  -> No issues found!
flutter test     -> 159 tests, All tests passed  (khoang 6 giay)
```

#### Coverage từng tệp của split engine

| Tệp | Dòng | % |
|-----|------|---|
| `strategies/equal_strategy.dart` | 7/7 | 100,0 |
| `strategies/exact_strategy.dart` | 5/5 | 100,0 |
| `strategies/itemized_strategy.dart` | 37/37 | 100,0 |
| `strategies/percentage_strategy.dart` | 7/7 | 100,0 |
| `strategies/shares_strategy.dart` | 15/15 | 100,0 |
| `strategies/split_strategy.dart` | 8/8 | 100,0 |
| `surcharge_allocator.dart` | 9/9 | 100,0 |
| `split_result.dart` | 26/26 | 100,0 |
| `split_validator.dart` | 89/90 | 98,9 |
| `split_input.dart` | 65/66 | 98,5 |
| `rounding.dart` | 56/59 | 94,9 |
| `split_engine.dart` | 26/28 | 92,9 |
| **Tổng** | **350/357** | **98,0** |

7 dòng chưa phủ là **toàn bộ** phần không thể chạy tới được: private constructor
của các lớp chỉ có thành viên static (`Rounding._`, `SplitValidator._`,
`SplitLimits._`) và các chuỗi thông điệp trong `assert` — chúng chỉ được tính
khi bất biến bị vỡ, tức khi app đã có lỗi. Mọi nhánh logic chạy được đều đã phủ.

#### Phân bố test của Phase 2 (95 test mới)

| Tệp | Số test | Nội dung |
|-----|---------|----------|
| `test/domain/split/rounding_test.dart` | 21 | `roundTotal`, `effectiveUnit`, `distribute`, `lcm`, số 1 nghìn tỷ |
| `test/domain/split/split_engine_test.dart` | 39 | TC-01 → TC-19, ví dụ kiểm chứng SPEC §FR-5, TC-P2 |
| `test/domain/split/split_input_test.dart` | 12 | `SplitInput.fromBill` cho cả 5 kiểu chia, `copyWith` |
| `test/domain/split/split_edge_cases_test.dart` | 17 | Nhánh biên của validator, món lạ, getter của `SplitResult` |
| `test/domain/split/split_property_test.dart` | 6 | TC-P1 — **29.000 hóa đơn ngẫu nhiên** |

#### Property test đã kiểm những gì

Hạt giống ngẫu nhiên cố định, nên test đỏ là tái hiện được đúng trường hợp đó.

| Bất biến | Số lần |
|----------|--------|
| `Σ shares == total` | 10.000 |
| Mọi phần là bội của đơn vị làm tròn, và không âm | 5.000 |
| `Σ baseShares == subtotal` | 5.000 |
| `total == roundTotal(totalExact, unit, mode)` | 5.000 |
| Mỗi món phân bổ khớp đúng giá món | 3.000 |
| Gọi hai lần cho kết quả giống hệt | 1.000 |

Đầu vào ngẫu nhiên phủ: cả 5 kiểu chia · 1–20 người · 0–30 món · người dùng
món là tập con ngẫu nhiên (**kể cả tập rỗng**, tức món chung) · trọng số phân
số · giảm giá / VAT / phí dịch vụ ngẫu nhiên theo cả hai dạng % và số tiền ·
tip · cả hai cách phân bổ phụ phí · 4 đơn vị làm tròn · cả 3 chế độ làm tròn ·
và có chủ ý sinh cả các tổng rất nhỏ (0, dưới 10 đồng) vì đó là nơi phép chia
dễ sai nhất.

---

### Thiết kế thực tế của Phase 2, so với §11

Khung code ở §11 là bản phác. Bản cài thật khác ở bốn điểm, đều là để giữ đúng
nguyên tắc "không `double` nào trong đường tính tiền" (NFR-6):

**1. `distribute` dùng `BigInt` cho phép nhân `total × weight`.**
Phác thảo ở §11 so sánh phần dư trên `int`. Với tổng 1 nghìn tỷ đồng và trọng
số cũng lớn, `total × weight` tràn `int64`. Dùng `BigInt` cho đúng ba phép
nhân/chia/lấy dư ở mỗi người là xong — với tối đa 100 người thì chi phí không
đáng kể, và không cần đặt giới hạn nhân tạo lên số tiền. Đã có test riêng với
tổng 1 nghìn tỷ.

**2. Thêm `effectiveUnit`.** Phác thảo không nói rõ chuyện gì xảy ra khi người
dùng chọn *không làm tròn* nhưng đơn vị vẫn là 1.000đ. Tổng khi đó là 847.500 —
không thể chia thành các phần đều là bội của 1.000. Chế độ `none` vì vậy hạ đơn
vị phân bổ về 1 đồng, đúng ý "chia chính xác đến từng đồng".

**3. Chia theo món phân bổ về số nguyên đồng *ngay tại từng món*,** thay vì
cộng dồn phân số rồi làm tròn một lần ở cuối. Hai lý do: tổng phần gốc khớp
`subtotal` tuyệt đối vì mỗi món đã khớp giá món; và màn hình "Chi tiết theo
món" hiển thị được con số thật của từng món. Đây cũng là chỗ con số minh họa
trong SPEC §FR-4.2 đã được sửa — xem 13.4.

**4. `SurchargeAlloc.equal` được quy về cùng một bộ trọng số** thay vì cộng hai
lần phân bổ. Đặt `w_i = baseShare_i × n + netAdjustment`, khi đó
`Σw / n = subtotal + netAdjustment = totalExact`, nên cả hai chế độ phân bổ
dùng chung một đường tính và chỉ có một bước làm tròn duy nhất. Nếu làm tròn
hai lần rồi cộng lại thì tổng sẽ lệch.

### Phase 3 — Thành viên & Nhóm · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| Khung điều hướng 4 tab (`AppShell`, `MoreScreen`) | ✅ |
| Widget dùng chung: `MemberAvatar`, `MemberAvatarStack`, `MemberChip` | ✅ |
| `EmptyState`, `ErrorView`, `ConfirmDialog`, `AppSnackBar` | ✅ |
| `membersProvider`, `groupsProvider`, lọc theo từ khóa bỏ dấu | ✅ |
| S05 danh sách thành viên: tìm kiếm, swipe sửa / ẩn / bật lại | ✅ |
| S06 form thành viên + cảnh báo trùng tên + chuyển "Tôi" | ✅ |
| Nhập nhanh nhiều tên (FR-1.8) | ✅ |
| `MemberPickerSheet` — chọn nhiều người, có nút "Tất cả" và chọn theo nhóm | ✅ |
| S08 / S09 nhóm | ✅ |
| Widget test | ✅ **21 test mới** |

```
flutter analyze  -> No issues found!
flutter test     -> 180 tests, All tests passed  (khoang 11 giay)
```

#### Kiểm chứng trên emulator thật

Tiêu chí hoàn thành của phase này là *"thêm 5 thành viên + 1 nhóm, kill app, mở
lại vẫn còn đủ"*. Đã chạy trên Pixel 3a API 34:

1. Cài APK debug, mở app → màn hình "Khác" hiện "1 người đang hoạt động"
2. Thành viên → nhập nhanh 5 tên (An, Binh, Chi, Dung, Em) → SnackBar
   *"Đã thêm 5 thành viên"*, mỗi người một màu avatar khác nhau
3. Nhóm → tạo "Team Dev" → chọn An, Binh, Chi qua `MemberPickerSheet` → lưu
4. `adb shell am force-stop com.dtd.chiahoadon` → mở lại
5. **Kết quả:** "6 người đang hoạt động", nhóm "Team Dev · 3 người ·
   An, Binh, Chi" còn nguyên kèm avatar chồng

Font Be Vietnam Pro hiển thị đúng toàn bộ dấu tiếng Việt trên máy thật.

#### Phân bố test của Phase 3 (21 test mới)

| Tệp | Số test | Nội dung |
|-----|---------|----------|
| `test/widget/members_flow_test.dart` | 13 | Danh sách, tìm kiếm bỏ dấu, thêm / sửa, trùng tên, đánh dấu "Tôi", ẩn thay vì xóa |
| `test/widget/groups_flow_test.dart` | 8 | Danh sách nhóm, tạo qua bộ chọn, nút "Tất cả", kiểm tra đầu vào, sửa, xóa |

Widget test chạy trên **DB SQLite thật trong bộ nhớ**, không mock repository, nên
đi qua đúng đường mà app chạy thật — kể cả ràng buộc khóa ngoại và chỉ mục
unique `is_self`.

---


### Phase 4 — Hóa đơn + chia đều · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `MoneyField` + `PercentField` — tự chèn dấu phân cách khi gõ | ✅ |
| `BillFormState` — lớp bất biến, thuần, test được không cần widget | ✅ |
| S03 wizard 3 bước + thanh bước bấm nhảy được | ✅ |
| **Khung XEM TRƯỚC realtime** | ✅ |
| `billListProvider` + `billFilterProvider` + `billDetailProvider` | ✅ |
| S02 danh sách: phân trang 50, tìm kiếm bỏ dấu, lọc theo thời gian và trạng thái | ✅ |
| S04 chi tiết: bóc tách tiền, sửa, nhân bản, xóa có hoàn tác | ✅ |
| Tự lưu nháp sau 3 giây ngừng gõ (NFR-10) | ✅ |
| Test | ✅ **36 test mới** |

```
flutter analyze  -> No issues found!
flutter test     -> 216 tests, All tests passed  (khoang 13 giay)
```

Tiêu chí hoàn thành đã đạt, kiểm bằng widget test đi hết ba bước: nhập
1.000.000đ cho 3 người → UI hiện **334.000 / 333.000 / 333.000**, và bản ghi
trong DB có `totalShares == totalAmount == 1.000.000`.

#### Phân bố test của Phase 4 (36 test mới)

| Tệp | Số test | Nội dung |
|-----|---------|----------|
| `test/features/bill_form_state_test.dart` | 23 | Điều kiện lưu, thứ tự người tham gia, đổi kiểu chia, dựng bản ghi, nạp lại để sửa |
| `test/widget/bills_flow_test.dart` | 13 | Danh sách, tìm kiếm bỏ dấu, lọc, wizard đầu-cuối, chi tiết, nhân bản, xóa + hoàn tác, nháp |

### Phase 5 — Chia theo món · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| Sheet thêm/sửa món: tên, đơn giá × SL, thành tiền tự tính | ✅ |
| Chọn người cho từng món, mặc định chọn sẵn cả nhóm | ✅ |
| Nút "Chỉ một người" và "Cả nhóm" | ✅ |
| Bảng nhập số phần trong món (sheet riêng, stepper +/−) | ✅ |
| Nhãn cảnh báo vàng cho món chưa chọn ai (FR-4.2) | ✅ |
| Mục "Chi tiết theo món" ở S04 | ✅ |
| Test | ✅ 8 test |

### Phase 6 — Phụ phí & các kiểu chia còn lại · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| Panel phụ phí: giảm giá / VAT / phí DV / tip, đổi được % ↔ số tiền | ✅ |
| Panel làm tròn: 4 đơn vị × 3 chế độ, hiện rõ chênh lệch | ✅ |
| Công tắc phân bổ phụ phí theo tỷ lệ / chia đều | ✅ |
| UI chia theo % (thanh tiến trình + số còn thiếu) | ✅ |
| UI chia theo số phần (stepper) | ✅ |
| UI chia theo số tiền chỉ định (+ nút "Dồn phần dư") | ✅ |
| Hỏi xác nhận khi đổi kiểu chia làm mất dữ liệu | ✅ |
| Test | ✅ 14 test |

Tiêu chí hoàn thành đạt: test `★ Ví dụ kiểm chứng đầy đủ` dựng hóa đơn lẩu/bia/
nước ép qua giao diện, bật VAT 8% và phí DV 5%, rồi lưu — bản ghi trong DB có
`302.000 / 301.000 / 245.000`, tổng 848.000, đúng bảng kiểm chứng ở SPEC §FR-5.

### Phase 7 — Thanh toán & Quyết toán · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `debt_simplifier.dart` — greedy, hàm thuần | ✅ 11 test |
| Chạm để đánh dấu đã trả, chạm giữ để nhập trả một phần | ✅ |
| Nút "Tất cả đã trả"; trạng thái hóa đơn tự suy ra | ✅ |
| S10 Quyết toán: số dư ròng + gợi ý chuyển tiền + nút "Đã chuyển" | ✅ |
| Ghi nhận chuyển tiền thủ công, xóa được (FR-6.6) | ✅ |
| Cảnh báo khi tổng số dư lệch khỏi 0 | ✅ |
| Test | ✅ 22 test |

Property test 1.000 bộ số dư ngẫu nhiên: luôn đưa mọi người về 0 và không bao
giờ vượt `n − 1` giao dịch.

### Phase 8 — Thống kê · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| S01 Dashboard: chi tháng này, ai nợ ai, hóa đơn gần đây | ✅ |
| S11 Thống kê: chọn kỳ, xếp hạng, biểu đồ tròn, biểu đồ 12 tháng, danh mục | ✅ |
| **S07 Chi tiết thành viên: tổng chi + lịch sử từng hóa đơn** (FR-7.1, FR-7.2) | ✅ |
| Test | ✅ 11 test |

Tiêu chí hoàn thành đạt: test dựng 20 hóa đơn × 300.000 chia đều ba người, rồi
đối chiếu **từng con số trên màn hình** với số tính tay — tổng nhóm 6.000.000,
mỗi người 2.000.000, trung bình 100.000 một hóa đơn, tỷ trọng 33%.

```
flutter analyze  -> No issues found!
flutter test     -> 277 tests, All tests passed  (khoang 42 giay)
```

---

### Phase 9 — Chia sẻ, sao lưu, cài đặt · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `share_text.dart` — hàm thuần dựng text theo mẫu FR-8.1 | ✅ 12 test |
| S14 Xem trước rồi chia sẻ: gửi text hoặc gửi ảnh | ✅ |
| Chụp widget thành PNG qua `RepaintBoundary` + `toImage` | ✅ |
| `backup_service.dart` — xuất JSON có `format_version`, phục hồi trong transaction | ✅ 17 test |
| S12 Cài đặt: theme, đơn vị làm tròn mặc định, quản lý danh mục, xóa sạch dữ liệu | ✅ |
| Ảnh hóa đơn: chụp/chọn, lưu vào thư mục documents, xem toàn màn hình | ✅ |

Thẻ chia sẻ (`ShareCard`) **tự khai báo màu**, không lấy từ theme: ảnh gửi đi
phải đọc được trên mọi nền khung chat, kể cả khi người gửi đang bật chế độ tối.

Tiêu chí hoàn thành đạt: test sao lưu → `resetAll()` → phục hồi → đối chiếu
từng hóa đơn, từng phần chia, từng khoản thanh toán.

### Phase 10 — Hoàn thiện & phát hành · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `test/data/performance_test.dart` — 1.000 hóa đơn (NFR-3, NFR-4) | ✅ 7 test |
| `test/widget/layout_test.dart` — 360dp · nền tối · cỡ chữ 1,3× | ✅ 15 test |
| `tool/generate_icon.dart` — sinh icon và ảnh splash từ màu seed | ✅ |
| `flutter_launcher_icons` + `flutter_native_splash` | ✅ |
| Đổi nhãn app thành "Chia Hóa Đơn" (Android + iOS) | ✅ |
| Bỏ `cupertino_icons` — app không dùng, font tốn 257 KB trong APK | ✅ |
| `integration_test/smoke_test.dart` — §8.3 chạy trên thiết bị | ✅ 4 test |

**Số đo hiệu năng (NFR-3, NFR-4) với 1.000 hóa đơn:**

| Phép đo | Ngưỡng | Ghi chú |
|---------|--------|---------|
| Tải một trang 50 hóa đơn | < 500 ms | người tham gia nạp sẵn, không truy vấn N+1 |
| Trang cuối (offset 950) | < 500 ms | nhanh ngang trang đầu |
| Tìm kiếm bỏ dấu trên 1.000 hóa đơn | < 500 ms | đi qua `idx_bills_title_norm` |
| Ba truy vấn thống kê gộp | < 1.500 ms | gộp bằng SQL, không bằng Dart |
| `computeSplit` 20 người × 30 món | < 16 ms | đủ để xem trước cập nhật theo từng ký tự gõ |

**Test bố cục tự kiểm chứng.** `layout_test.dart` có một test dựng cố ý một
hàng tràn khung và khẳng định `takeException()` **không** null. Không có nó thì
mười bốn test còn lại có thể xanh chỉ vì cơ chế bắt lỗi đã hỏng, chứ không phải
vì bố cục đúng.

**Dung lượng APK (NFR-5 ≤ 30 MB):**

```
flutter build apk --release --split-per-abi
    armeabi-v7a  16,9 MB
    arm64-v8a    19,3 MB      <- ban phat hanh thuc te
    x86_64       20,7 MB      <- chay tren emulator

aapt dump badging      -> application-label: 'Chia Hoa Don'
aapt dump permissions  -> chi co DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
                       -> KHONG co android.permission.INTERNET   [NFR-1 van dat
                          sau khi them 3 plugin moi]
```

**Smoke test §8.3 trên emulator Pixel 3a API 34:**

| Bước | Cách kiểm | Kết quả |
|------|-----------|---------|
| 1 mở lần đầu | `integration_test` | "Tôi" + 7 danh mục, 4 tab dựng được |
| 2–3 thành viên, nhóm, chia đều | `integration_test` | Σ phần chia = 1.000.000 |
| 4 ví dụ FR-4.2 + VAT 8% + DV 5% | `integration_test` | 302.000 / 301.000 / 245.000 trên SQLite của máy |
| 5 trả đủ / trả một phần | `integration_test` | trạng thái = "Một phần" |
| 6 quyết toán | `integration_test` | Σ số dư = 0 |
| 7 thống kê thành viên | `integration_test` | tổng chi = Σ các lần chi |
| 8 chia sẻ qua Zalo | **còn phải làm tay** | emulator không có Zalo; `ShareText` đã có 12 test |
| 9 sao lưu → xóa → phục hồi | `integration_test` | dữ liệu về nguyên vẹn |
| 10 chế độ tối | `integration_test` + `layout_test` | mọi tab dựng được |
| 11 chế độ máy bay | adb + bản release | chạy bình thường; app vốn không xin quyền mạng |
| 12 kill app giữa lúc nhập | adb trên bản release | nháp còn nguyên sau khi mở lại |

Bước 8 là việc duy nhất của §8.3 chưa tự động hóa được: nó phụ thuộc ứng dụng
bên thứ ba.

```
flutter analyze  -> No issues found!
flutter test     -> 330 tests, All tests passed  (khoang 55 giay)
flutter test integration_test/smoke_test.dart -d emulator-5554
                 -> 4 tests, All tests passed
```

---

### Phase 11 — VietQR, khóa app, xuất CSV · ✅ Xong 2026-10-03

| Việc | Trạng thái |
|------|-----------|
| `domain/vietqr/vietqr.dart` — sinh chuỗi EMVCo, hàm thuần | ✅ 17 test |
| `assets/data/banks.json` — 55 ngân hàng kèm mã BIN | ✅ 12 test |
| Bộ chọn ngân hàng tìm kiếm bỏ dấu, lưu cả mã BIN | ✅ |
| Sheet QR ở màn Quyết toán và hồ sơ thành viên | ✅ 6 test |
| `services/app_lock_service.dart` + `AppLockGate` | ✅ 11 test |
| `services/csv_export.dart` | ✅ 14 test |
| Smoke test trên thiết bị cho QR và CSV | ✅ 2 test |

**VietQR sinh ngay trên máy.** Chuỗi QR chỉ là ghép các trường theo định dạng
rồi tính một mã kiểm tra, không có bước nào gọi mạng — nên tính năng này không
phá cam kết offline (NFR-1).

Chỗ dễ sai nhất của định dạng EMVCo là mã kiểm tra: nó tính trên **cả** bốn ký
tự `6304` đứng ngay trước nó, và dùng biến thể CRC-16/CCITT-FALSE chứ không
phải biến thể mặc định của phần lớn thư viện CRC. Test neo vào giá trị kiểm
chuẩn đã công bố của thuật toán (`CRC("123456789") == 29B1`); không có mốc ngoài
đó thì mọi test CRC khác chỉ chứng minh mã nhất quán với chính nó.

**Khóa app không tự quản lý mã PIN.** Xem 13.18.

**Dung lượng APK sau Phase 11 (NFR-5 ≤ 30 MB):**

```
armeabi-v7a  17,5 MB     (Phase 10: 16,9 MB)
arm64-v8a    19,9 MB     (Phase 10: 19,3 MB)  <- ban phat hanh thuc te

aapt dump permissions
    uses-permission: android.permission.USE_BIOMETRIC     <- local_auth
    uses-permission: android.permission.USE_FINGERPRINT   <- local_auth
    -> VAN KHONG co android.permission.INTERNET           [NFR-1 giu nguyen]
```

```
flutter analyze  -> No issues found!
flutter test     -> 391 tests, All tests passed
flutter test integration_test/smoke_test.dart -d emulator-5554
                 -> 6 tests, All tests passed
```

---

### Phase 12 — Món có sẵn, báo cáo tuần, tên từ danh mục · ✅ Xong 2026-10-03

Ba việc người dùng yêu cầu sau khi dùng thử v1.1.

| Việc | Trạng thái |
|------|-----------|
| Bảng `item_presets` + migration v2→v3 | ✅ 24 test |
| Màn "Món có sẵn" (thêm/sửa/xóa) + bộ chọn khi nhập hóa đơn | ✅ 10 test |
| Lọc kỳ theo tuần + biểu đồ gộp theo tuần | ✅ 26 test |
| Mọi kỳ thống kê ghi rõ khoảng ngày | ✅ |
| Chọn danh mục là tên hóa đơn được điền theo | ✅ 6 test |
| Danh sách hóa đơn ghi đủ ngày/tháng/năm | ✅ |

**Món trong hóa đơn không trỏ về bản mẫu.** Khi chọn, tên và giá được **chép**
sang `BillItem`. Sửa giá trong danh sách món sau đó không làm đổi số tiền của
hóa đơn cũ — cùng nguyên tắc đã dùng cho tên thành viên (SPEC §5.2). Nhờ vậy
xóa một món khỏi danh sách cũng không để lại tham chiếu treo, nên bảng này xóa
hẳn chứ không xóa mềm như `members`.

**Tuần bắt đầu từ thứ Hai**, theo cách người Việt nói "tuần này" — không theo
chuẩn ISO hay tuần bắt đầu Chủ nhật của Mỹ. Mốc đầu tuần được tính ở **hai nơi**
(SQLite cho truy vấn gộp, Dart cho bộ lọc kỳ), nên có một test đối chiếu hai
cách tính với nhau: lệch nhau thì biểu đồ và bộ lọc sẽ nói hai điều khác nhau về
cùng một tuần mà không có gì báo lỗi.

```
flutter analyze  -> No issues found!
flutter test     -> 457 tests, All tests passed
flutter test integration_test/smoke_test.dart -d emulator-5554
                 -> 6 tests, All tests passed
```


### Phase 14 — Báo cáo thành viên × danh mục · ✅ Xong 2026-10-04

Yêu cầu: *"báo cáo tổng chi từng thành viên theo loại dịch vụ"*. "Loại dịch vụ"
được hiểu là **danh mục chi tiêu** — thứ đã có sẵn trên mỗi hóa đơn — thay vì
thêm một khái niệm phân loại mới. Giả định này ghi rõ ở đây vì nếu sai thì phần
còn lại của mục này cũng sai theo.

| Việc | Trạng thái |
|------|-----------|
| `StatsDao.memberCategoryTotals` — gộp `GROUP BY m.id, b.category_id` | ✅ 11 test |
| `MemberBreakdown` gom dòng theo người, sắp theo tiền giảm dần | ✅ |
| `membersInCategory` lật bảng: một danh mục → nhiều người | ✅ 5 test |
| Mục "CHI PHÍ TỪNG NGƯỜI THEO DANH MỤC" — ô chọn danh mục + danh sách người | ✅ 6 test |
| Ẩn bớt thành viên khỏi mục này, có nút hiện lại (FR-7.14) | ✅ |

**Cộng trên `share_amount`, không cộng đơn giá món.** `share_amount` là con số
cuối cùng sau phụ phí và làm tròn, nên tổng các dòng của một người **khớp đúng**
tổng chi của người đó ở bảng xếp hạng FR-7.1. Có hẳn một test đối chiếu hai con
số này trên sáu hóa đơn số lẻ: hai chỗ nói hai số khác nhau về cùng một người
thì cả hai đều mất giá trị.

**Bản đầu làm sai hình dạng.** Tôi dựng mỗi người một khối gấp được, mở ra mới
thấy các danh mục của người đó. Người dùng xem xong nói ngay: *"không đúng, tôi
muốn có pulldown chọn danh mục, sau khi chọn danh mục thì sẽ hiển thị chi phí
của từng thành viên trong danh mục đó"*. Hai cách cùng đọc một bảng chéo nhưng
trả lời hai câu khác nhau, và câu người ta thật sự hỏi là **"khoản này ai tốn
bao nhiêu"** chứ không phải "người này tiêu vào những việc gì". Ghi ở **13.28**.

Lỗi thanh tỷ trọng cao 0 pixel — và một chẩn đoán sai của tôi trước đó — ghi ở
**13.27**.

```
flutter analyze  -> No issues found!
flutter test     -> 480 tests, All tests passed
flutter build apk --release --split-per-abi -> x86_64 21,3 MB
```

---

### Phase 15 — Chia sẻ báo cáo lên Mattermost · ✅ Xong 2026-10-04

Yêu cầu: gửi báo cáo theo danh mục cho các thành viên có chi tiêu, đích đến là
Mattermost.

| Việc | Trạng thái |
|------|-----------|
| `ShareText.forCategoryReport` — bảng markdown, hàm thuần | ✅ 5 test |
| `ReportShareScreen` — xem trước, gửi text, gửi ảnh, chép | ✅ 3 test |
| Nút chia sẻ trong mục FR-7.13, tắt khi không còn ai | ✅ |

**Không thêm quyền mạng.** Có hai đường tới Mattermost: qua bảng chia sẻ của
Android (`ACTION_SEND`), hoặc app tự `POST` vào incoming webhook. Đường thứ hai
một chạm là xong, nhưng kéo theo `android.permission.INTERNET` trong bản phát
hành — tức là xóa NFR-1, thứ đã quảng cáo trong README và là lý do app này đáng
tin với dữ liệu chi tiêu của một nhóm bạn. Người dùng chọn đường thứ nhất sau
khi được nêu rõ hai cái giá. Đã kiểm lại bằng `aapt dump permissions` trên bản
release: vẫn chỉ có `USE_BIOMETRIC`, `USE_FINGERPRINT` và quyền receiver nội bộ.

**Markdown ở đây, không markdown ở FR-8.1.** `ShareText.forBill` cố tình đệm
khoảng trắng cho thẳng cột vì Zalo và Messenger không hiểu bảng; Mattermost thì
render bảng markdown nên `forCategoryReport` dùng `|---|---:|` để cột tiền canh
phải. Hai định dạng cho hai nơi, không gộp làm một.

**Nội dung gửi đi phải tự đứng được.** Người nhận không mở app, nên trong tin
nhắn luôn có: tên danh mục, **khoảng ngày của kỳ**, dòng tổng, và dòng "Đang ẩn
N người" nếu báo cáo đang lọc (FR-7.14). Gửi một bảng số mà không nói đang lọc
gì là cách chắc chắn để người đọc hiểu sai về tiền.

```
flutter analyze  -> No issues found!
flutter test     -> 507 tests, All tests passed
aapt dump permissions app-arm64-v8a-release.apk -> KHÔNG có INTERNET  [NFR-1]
```

**Còn phải kiểm tay:** emulator này chưa cài Mattermost, nên mới xác nhận tới
bước bảng chia sẻ của Android bật lên đúng nội dung. Bước cuối — chọn Mattermost
rồi chọn kênh, và xem bảng markdown render ra sao trong tin nhắn thật — phải thử
trên máy có cài Mattermost.

---

### Build và quyền truy cập mạng (kiểm chứng ở Phase 0–1)

```
flutter analyze                    -> No issues found!
flutter test                       -> 277 tests sau Phase 8, All tests passed
flutter build apk --debug          -> OK app-debug.apk
flutter build apk --release        -> OK app-release.apk (44.9 MB, fat)
flutter build apk --release --split-per-abi
    armeabi-v7a  13.5 MB
    arm64-v8a    16.1 MB      <- ban phat hanh thuc te, duoi nguong NFR-5 (30 MB)
    x86_64       17.5 MB

aapt dump permissions app-release.apk
    -> chi co DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
    -> KHONG co android.permission.INTERNET            [NFR-1 dat]
aapt dump permissions app-debug.apk
    -> CO android.permission.INTERNET                  [hot reload van chay]
```

### Phân bố test của Phase 0–1 (64 test)

| Tệp | Số test | Nội dung |
|-----|---------|----------|
| `test/core/formatters_test.dart` | 25 | Tiền, phần trăm basis point, phụ phí, bỏ dấu tiếng Việt, ngày tháng |
| `test/data/database_test.dart` | 24 | Tạo DB, seed, MemberDao, BillDao, bất biến trước khi ghi, reset |
| `test/data/stats_dao_test.dart` | 15 | FR-7.1, FR-7.2, số dư ròng, thống kê tháng, Dashboard |

Cộng 95 test của Phase 2 ở trên, tổng hiện tại là **159 test**.

---

## 13. Những điểm lệch so với kế hoạch ban đầu

Ghi lại để lần review sau không phải đoán vì sao code khác PLAN.

### 13.1 Lệch về thư viện

| Hạng mục | Kế hoạch | Thực tế | Ảnh hưởng |
|----------|----------|---------|-----------|
| **Riverpod** | `^2.5.1` | **`^3.4.3`** | Đã đọc mã nguồn trong pub cache để xác minh: `Notifier`/`AsyncNotifier` giữ nguyên chữ ký (`build()`, `state`, `ref`), `Provider` vẫn **keepAlive mặc định** (`isAutoDispose = false`), `Provider.autoDispose` và `.family` còn nguyên. `StateNotifierProvider`/`StateProvider` bị đẩy sang `legacy/` nhưng dự án không dùng. **§6 không cần sửa.** |
| **fl_chart** | `^0.68.0` | **`^1.2.0`** | Nhảy major. Chưa dùng tới (Phase 8). ⚠ Khi làm biểu đồ phải đọc lại API, đừng copy ví dụ 0.x. |
| **intl** | `^0.19.0` | `^0.20.3` | Không ảnh hưởng — xem 13.2. |
| **flutter_lints** | `^4.0.0` | `^6.0.0` | Siết hơn, đã sửa code cho sạch. |
| **share_plus / file_picker** | `^9` / `^7` | `^13.3.1` / `^13.1.0` | Chưa dùng tới (Phase 9). |

### 13.2 Lệch về thiết kế

| # | Quyết định | Vì sao đổi |
|---|-----------|-----------|
| 1 | **Không dùng `intl` để định dạng tiền và ngày.** `MoneyFormatter` nhóm chữ số thủ công, `DateFormatter` dùng mẫu số thuần và tên tháng/thứ viết sẵn trong code. | `NumberFormat`/`DateFormat` với locale `vi_VN` phụ thuộc dữ liệu locale được nạp lúc chạy. App offline cần kết quả giống nhau trên mọi máy, không phụ thuộc bước khởi tạo async nào. Đổi lại được 25 test thuần, chạy trong vài mili giây. `intl` vẫn giữ trong pubspec cho Phase 8–9. |
| 2 | **`databaseProvider` là `Provider` được ghi đè trong `main()`**, không phải `FutureProvider`. | Mở DB xong trước `runApp` khiến mọi provider phía sau là **đồng bộ**. Không màn hình nào phải xử lý trạng thái "đang mở DB", và `splitPreviewProvider` ở Phase 4 chắc chắn giữ được yêu cầu < 16 ms của NFR-4. |
| 3 | Thêm `lib/data/database/schema.dart` tách riêng khỏi `app_database.dart`. | DDL 12 bảng dài khoảng 200 dòng; tách ra thì đối chiếu với §4.2 dễ hơn khi review. |
| 4 | Thêm `category_dao.dart` và `settings_dao.dart` (ngoài danh sách §3.2). | Danh mục và cài đặt là bảng độc lập, nhét vào DAO khác sẽ rối. Cài đặt lưu trong **DB** thay vì `shared_preferences` để tệp sao lưu JSON mang theo được cả cấu hình (FR-8.5). |
| 5 | Thêm `domain/models/surcharge.dart` và `domain/models/bill_filter.dart`. | `Surcharge` là value object dùng chung cho VAT / phí DV / giảm giá; `BillFilter` cần bất biến để làm khóa cache của Riverpod. |
| 6 | Model danh mục đặt tên **`ExpenseCategory`**, không phải `Category`. | `Category` trùng tên với lớp trong thư viện chuẩn Dart, gây xung đột khi import cùng lúc. |
| 7 | Bảng nhóm đặt tên **`member_groups`**, không phải `groups`. | `GROUPS` là từ khóa SQLite từ 3.28 (hàm cửa sổ), sẽ gây lỗi cú pháp. Đã ghi chú ngay trong `schema.dart`. |
| 8 | Trọng số lưu dạng phân số **`weight_num` / `weight_den`** thay vì một số thực. | Giữ được "1,5 phần" mà vẫn không có `double` nào trong đường tính tiền (NFR-6). |
| 9 | Chặn quyền INTERNET ở **`android/app/src/release/AndroidManifest.xml`**, không phải manifest chính. | Nếu đặt `tools:node="remove"` ở manifest chính, nó sẽ xóa luôn quyền INTERNET mà `src/debug/` khai báo cho hot reload. Tách theo build type giữ được cả hai: debug dev được, release sạch quyền. |
| 10 | `lib/features/home/dev_check_screen.dart` — màn hình kiểm tra tạm. | Xác nhận bằng mắt rằng font tiếng Việt, theme sáng/tối, định dạng tiền và kết nối DB đều chạy. **Sẽ bị thay bằng Dashboard thật ở Phase 8.** |

### 13.3 Vấn đề toolchain đã xử lý

**Build Android thất bại ở mọi module Kotlin của plugin:**

```
Execution failed for task ':image_picker_android:compileDebugKotlin'
Execution failed for task ':share_plus:compileDebugKotlin'
Execution failed for task ':android_file_picker:compileDebugKotlin'
Execution failed for task ':shared_preferences_android:compileDebugKotlin'
  > java.lang.IllegalStateException:
      Storage for [...class-fq-name-to-source.tab] is already registered
  > java.lang.Exception:
      Could not close incremental caches in build\...\caches-jvm\jvm\kotlin
```

Nguyên nhân: Flutter đặt build dir của mọi plugin vào cùng thư mục `build/` của app. Khi các module Kotlin biên dịch song song, Kotlin Build Tools API đăng ký trùng cùng tệp cache incremental. `flutter clean` **không** khắc phục được.

Cách xử lý — thêm vào `android/gradle.properties`:

```properties
kotlin.incremental=false
kotlin.compiler.execution.strategy=daemon
```

Lưu ý: `out-of-process` **đã bị bỏ ở Kotlin 2.4.0** (báo lỗi rõ ràng khi thử), chỉ còn `daemon` và `in-process`. Dự án không có code Kotlin riêng nên tắt incremental không mất gì — các module plugin biên dịch một lần rồi được Gradle cache.

Đồng thời giảm `org.gradle.jvmargs` từ `-Xmx8G -XX:MaxMetaspaceSize=4G` xuống `-Xmx4G -XX:MaxMetaspaceSize=2G` cho vừa máy.

---

### 13.4 Sửa số minh họa trong SPEC §FR-4.2

Con số cũ trong SPEC là `An 266.667 · Bình 266.667 · Chi 216.667`, cộng lại ra
**750.001đ** — thừa một đồng không có thật. Đó là hệ quả của việc làm tròn hiển
thị từng phân số `166.666,67` một cách độc lập.

Engine phân bổ ngay tại từng món nên Chi chịu `216.666đ` và tổng đúng 750.000đ.
SPEC §FR-4.2 và bảng kiểm chứng §FR-5 đã được cập nhật theo số thật, kèm giải
thích vì sao. Kết quả cuối của ví dụ **không đổi**: vẫn là
`302.000 / 301.000 / 245.000`.

### 13.5 Mã lỗi của split engine

Validator trả [`SplitErrorCode`] thay vì chuỗi, nên test khẳng định trên mã và
sửa lại câu thông báo tiếng Việt không làm vỡ test. 12 mã:

`noParticipants` · `duplicateParticipant` · `tooManyParticipants` ·
`amountTooLarge` · `percentageNotHundred` · `exactMismatch` ·
`zeroWeightTotal` · `invalidWeight` · `itemizedNeedsItems` ·
`itemUserNotParticipant` · `duplicateItemUser` · `negativeItemAmount`

Mỗi lỗi mang kèm `memberId` và `itemId` khi có, để UI tô đỏ đúng dòng.

Một quyết định về trải nghiệm: **tổng tiền bằng 0 không phải lỗi.** Trong lúc
người dùng còn đang gõ, khung xem trước cần hiện 0 chứ không nên nhảy thông báo
đỏ. Việc chặn lưu hóa đơn có tổng 0 thuộc `BillRepository.validate`.

### 13.6 Hai test case của §8.1 nằm ở chỗ khác

- **TC-20** (người ứng tiền không nằm trong danh sách tham gia) không thuộc
  split engine: `SplitInput` không biết tới người ứng tiền, vì đó là chuyện của
  `Bill`. Đã được phủ ở `test/data/stats_dao_test.dart`, test *"người ứng tiền
  không tham gia ăn vẫn ra số dư đúng"*.
- **TC-P1** được tách thành 5 test property riêng, mỗi test một bất biến, để
  khi đỏ thì biết ngay bất biến nào vỡ thay vì phải đọc log.

---

### 13.7 Ba khác biệt API của Riverpod 3 đã gặp khi dựng UI

Phần 13.1 kết luận "§6 không cần sửa" dựa trên việc đọc `Notifier`/`AsyncNotifier`.
Khi viết UI thật thì lộ thêm ba chỗ khác, đều đã xử lý:

| # | Khác biệt | Xử lý |
|---|-----------|-------|
| 1 | **`update` là tên đã bị chiếm** trên `AsyncNotifier`. Riverpod 3 có sẵn `$AsyncClassModifier.update(cb)` để sửa state, nên khai báo `Future<Result<T>> update(T item)` là **lỗi biên dịch**, không phải cảnh báo. | Đổi tên phương thức repository-facing thành `save(...)` ở cả `MembersNotifier` và `GroupsNotifier`. |
| 2 | **`AsyncValue.valueOrNull` không còn**; getter đọc giá trị có thể null giờ là `.value`. | Dùng `.value` cho `AsyncValue`. Lưu ý `Result.valueOrNull` của dự án là lớp riêng, **không** đổi. |
| 3 | **`AsyncValue` là sealed với đúng 3 nhánh** `AsyncData` / `AsyncLoading` / `AsyncError`. Thêm `_ =>` vào `switch` là cảnh báo `unreachable_switch_case`. | Bỏ nhánh mặc định, để trình phân tích kiểm tra tính đầy đủ giúp. |

### 13.8 Hai cái bẫy của widget test (ghi lại để Phase 4 khỏi mất thời gian)

**1. `pumpAndSettle` treo vì `CircularProgressIndicator`.** Vòng quay là
animation **vô hạn**, nên `pumpAndSettle` chờ mãi rồi timeout — lần chạy đầu
tốn 6 phút 34 giây rồi mới chết. App có spinner cả lúc tải lẫn lúc lưu, nên
`WidgetTestHelper.settle()` bơm một số frame cố định thay vì chờ "settle".

**2. `databaseFactoryFfi` chạy truy vấn trên isolate riêng, cần thời gian
thực.** Trong widget test thời gian là **giả** — `tester.pump(duration)` chỉ
tiến đồng hồ ảo — nên Future của isolate không bao giờ hoàn tất và test treo.
Phải dùng **`databaseFactoryFfiNoIsolate`** trong widget test (test DAO thuần ở
`test/data/` vẫn dùng bản thường được).

Thêm hai điểm nhỏ:
- `ListView` dựng con một cách **lười**, nên nút lưu ở cuối form dài chưa tồn
  tại trong cây widget; `ensureVisible` ném `Bad state: No element`. Phải
  `scrollUntilVisible` trước — đã gói vào `WidgetTestHelper.tapButton`.
- Khung test mặc định 800×600 là tỷ lệ ngang, không giống điện thoại nào. Đã
  đặt về **400×800** để bố cục được kiểm tra ở đúng dạng màn hình thật.

### 13.9 Thư mục mới ngoài §3.2

`lib/features/shell/` — `AppShell` (4 tab) và `MoreScreen` (menu quản lý).
Dựng khung điều hướng ngay từ Phase 3 để màn hình thật của các phase sau chỉ
cần thay vào đúng chỗ, không phải sửa lại điều hướng. Ba tab đầu hiện chỗ dành
sẵn có ghi rõ phase nào sẽ làm.

---

---

### 13.10 Trạng thái form nằm trong widget, không trong Riverpod

PLAN §6 dự kiến `billFormProvider` kiểu `AutoDisposeNotifier<BillFormState>` và
một `splitPreviewProvider` riêng. Bản cài thật giữ trạng thái trong `State` của
`BillFormScreen` và gọi thẳng `computeSplit` trong `build`.

**Vì sao đổi.** Provider toàn cục đọc dữ liệu async (`selfMemberProvider`,
`defaultRoundingUnitProvider`) sẽ **dựng lại khi dữ liệu đó về**, và lần dựng
lại đó xóa sạch thứ người dùng đang gõ. Các cách vá — `family` theo id hóa đơn,
`ProviderScope` lồng với `overrides`, hay gọi `init()` trong `initState` qua
`Future.microtask` — đều thêm một lớp phức tạp chỉ để phục vụ **một màn hình
duy nhất**, không có màn hình nào khác đọc trạng thái này.

**Vẫn giữ được điều quan trọng.** Lý do chính để dùng provider là test được
logic mà không cần widget. `BillFormState` là lớp **bất biến với các phương
thức thuần** (`withParticipants`, `withSplitType`, `toSplitInput`, `toBill`),
nên 23 test ở `bill_form_state_test.dart` chạy thẳng vào logic, không dựng
widget nào. Phần UI chỉ còn là nơi gọi các phương thức đó.

Yêu cầu NFR-4 vẫn đạt, thậm chí chắc chắn hơn: `computeSplit` chạy ngay trong
`build`, không qua provider nào, nên không có đường nào để nó trở thành async.

### 13.11 Thêm cột `bills.title_norm`

Tìm kiếm thành viên đã bỏ dấu từ Phase 1 (`members.name_norm`). Tìm kiếm hóa
đơn ban đầu dùng `LOWER(title) LIKE`, nghĩa là gõ `an lau` **không** ra
`Ăn lẩu` — người dùng sẽ thấy hai ô tìm kiếm trong cùng một app hành xử khác
nhau.

Đã thêm cột `title_norm` vào `bills` trong schema v1 (app chưa phát hành nên
không cần migration) cùng chỉ mục `idx_bills_title_norm`. Cột này do `BillDao`
tự sinh mỗi lần ghi, **không** nằm trong model `Bill` — nó là chi tiết của tầng
lưu trữ, không phải dữ liệu nghiệp vụ.

### 13.12 Hai lỗi do test bắt được

**1. Chế độ sửa mở nhầm trang.** `initState` đặt `_step = 2` để mở thẳng bước
"Chia tiền", nhưng `PageController()` mặc định mở trang 0 — thanh bước sáng ở
bước 3 trong khi màn hình hiện bước 1. Sửa bằng `PageController(initialPage:
_step)`. Lỗi này chỉ lộ ra khi test gõ số tiền rồi thấy tổng không đổi.

**2. Tràn layout ở màn hình hẹp.** Dòng "ngày · N người · trạng thái" trong thẻ
hóa đơn tràn 55px ở bề ngang 400dp. Đã gộp ngày và số người vào một `Expanded`
có `ellipsis`, để nhãn trạng thái bên phải luôn đọc được (NFR-9).

Cả hai đều do widget test chạy ở khung 400×800 bắt được — đúng lý do đã đặt kích
thước đó ở 13.8.
### 13.13 ⚠ Lỗi migration — bài học đắt nhất tới giờ

**Chuyện gì xảy ra.** Ở Phase 4 tôi thêm cột `bills.title_norm` thẳng vào
`schema.dart` và ghi trong 13.11 rằng *"app chưa phát hành nên không cần
migration"*. Toàn bộ 272 test vẫn xanh, vì mỗi test mở một DB **mới tinh**, nơi
`onCreate` dựng lược đồ mới nhất.

Khi cài đè lên emulator đã chạy từ Phase 3, lưu hóa đơn đổ lỗi ngay:

```
E SQLiteLog: (1) table bills has no column named title_norm
   in "INSERT OR REPLACE INTO bills (...)"
```

`dbVersion` vẫn là 1 nên `onUpgrade` không bao giờ chạy, và DB cũ giữ nguyên
lược đồ cũ. Người dùng nâng cấp app sẽ gặp đúng lỗi này — mất hẳn khả năng tạo
hóa đơn.

**Đã sửa.** Tăng `AppConstants.dbVersion` lên 2 và thêm bước
`Migrations.steps[2]`: `ALTER TABLE ... ADD COLUMN`, tạo chỉ mục, rồi **điền lại**
`title_norm` cho mọi hóa đơn cũ. Phải điền bằng Dart chứ không bằng SQL, vì
SQLite không có hàm bỏ dấu tiếng Việt.

**Bài học, đã ghi thành quy tắc trong `migrations.dart`:**

> Đổi `schema.dart` thì **luôn** phải tăng `dbVersion` và thêm một bước
> migration — kể cả khi app chưa phát hành. "Chưa phát hành" không có nghĩa là
> chưa có ai cài; máy phát triển và máy test cũng là bản cài.

**Và quan trọng hơn: đã thêm `test/data/migration_test.dart` (5 test).** Nó dựng
lại **lược đồ v1 thật**, chèn một hóa đơn có dấu, chạy migration, rồi kiểm:
cột đã có, dữ liệu cũ đã được điền lại, câu `INSERT` từng đổ lỗi nay chạy được,
và tìm kiếm bỏ dấu hoạt động trên cả bản ghi cũ. Bộ test trước đó **không thể**
bắt được lỗi này vì nó chưa bao giờ chạy trên một DB cũ.

Đã kiểm chứng lại trên chính emulator có DB cũ: mở app không còn lỗi SQLite nào,
tạo hóa đơn 900.000 thành công, màn hình thống kê hiện đúng số.

### 13.14 Quyết định về biểu đồ

Bộ màu avatar **không** dùng cho biểu đồ. Nó được chọn theo hàm băm tên nên hai
người cạnh nhau có thể ra hai màu rất giống — chấp nhận được khi luôn có tên bên
cạnh, nhưng không đủ cho các lát bánh nằm sát nhau. Khi kiểm định tự động, bộ
màu avatar **trượt**: cặp tím↔xanh dương chỉ cách nhau ΔE 0,4 với người mù màu
lục, và cặp cam↔đỏ chỉ 8,7 với cả mắt thường.

Đã dựng hai bộ màu riêng cho biểu đồ phân loại, mỗi bộ 6 màu, **đạt cả sáu tiêu
chí** (dải độ sáng, sàn bão hòa, phân tách mù màu, sàn mắt thường, tương phản
≥ 3:1) — một bộ cho nền sáng, một bộ **chọn lại** cho nền tối chứ không phải đảo
ngược bộ sáng:

```
sáng: #0D9488 #A16207 #BE185D #1D4ED8 #65A30D #7E22CE
tối:  #0D9488 #D97706 #EC4899 #3B82F6 #65A30D #A855F7
```

Ba quyết định về *hình thức* biểu đồ:

1. **Xếp hạng thành viên dùng thanh ngang một màu, không phải cột nhiều màu.**
   Đây là biểu đồ **độ lớn**, không phải phân loại — tô mỗi người một màu là
   cầu vồng vô nghĩa. Tên nằm ngay cạnh thanh nên danh tính không dựa vào màu.
   Ở bề ngang điện thoại, tên dưới trục cột sẽ phải xoay nghiêng hoặc cắt bớt.
2. **Biểu đồ tròn giới hạn 6 lát, phần còn lại gom vào "Khác".** Không bao giờ
   sinh thêm màu ngoài bộ đã kiểm định.
3. **Mọi biểu đồ đều có nhãn trực tiếp hoặc chú giải kèm tên và số tiền**, nên
   không có thông tin nào chỉ truyền bằng màu.

### 13.15 Icon và splash được **sinh bằng mã**, không phải tệp ảnh thiết kế sẵn

§7 Phase 10 chỉ ghi "Icon app + splash screen". Cách làm: `tool/generate_icon.dart`
vẽ bộ ảnh bằng gói `image` (Dart thuần), rồi `flutter_launcher_icons` và
`flutter_native_splash` cắt ra từng mật độ màn hình.

Lý do chọn vẽ bằng mã:

- Màu lấy thẳng từ `AppColors.seed`, nên icon không bao giờ lệch khỏi theme.
  Đổi màu seed thì chạy lại một lệnh là xong.
- Tạo lại được. Một tệp PNG do người thiết kế gửi là một hộp đen: muốn đổi bán
  kính hay khoảng hở giữa các múi thì phải mở trình thiết kế và vẽ lại.
- Không phải lôi thêm công cụ bên ngoài vào một dự án vốn chạy offline.

Hình: một vòng tròn chia ba múi, một múi tách ra ngoài — ba múi bằng nhau nói
"chia đều", múi tách ra nói "phần của một người", đúng hai việc app làm.

Hai con số phải tính chứ không ước lượng:

- **Bản cho adaptive icon dùng bán kính 0,27 khung** (bản vuông truyền thống
  dùng 0,27 trên nền bo góc). Android chỉ bảo đảm hiển thị phần nằm trong vòng
  tròn 66% ở giữa; phần ngoài tùy launcher cắt.
- **`adaptive_icon_foreground_inset: 0`.** `flutter_launcher_icons` mặc định
  thêm 16% lề nữa; cộng với lề đã chừa sẵn thì dấu hiệu teo lại, nhìn lọt thỏm
  giữa nền.
- Android 12+ đặt ảnh chờ trong mặt nạ tròn chỉ chiếm hai phần ba khung, nên
  nó dùng **tệp riêng** 1152px có lề rộng, không dùng chung với màn chờ cũ.

Vẽ ở kích thước gấp 4 rồi thu nhỏ bằng nội suy trung bình: `fillPolygon` của
gói `image` không khử răng cưa, vẽ thẳng ở kích thước cuối thì cạnh múi bị răng.

### 13.16 ⚠ Chạy trên máy thật tìm ra hai lỗi mà 330 test không thấy

Bộ test trên máy tính xanh hết, `flutter analyze` sạch, nhưng ảnh chụp màn hình
đầu tiên từ emulator lộ ngay ba chuyện:

1. **Màn trống có hai nút "Tạo hóa đơn"** — một của `EmptyState`, một là FAB
   nổi ngay bên dưới, cùng nhãn, cùng hành động. Widget test tìm
   `findsAtLeast(1)` nên không bao giờ phàn nàn. → Bỏ nút trong `EmptyState`,
   giữ FAB.
2. **Nháp là ngõ cụt.** `getDrafts()` đã có từ Phase 1 nhưng **không màn hình
   nào gọi tới**. Nháp tự lưu xong thì hiện như một hóa đơn 0đ bình thường, và
   chạm vào mở màn **xem chi tiết** — không có đường nào quay lại nhập tiếp.
   → Chạm vào nháp mở lại form (`BillFormScreen.push(bill: ...)`), mở từ **bước
   đầu** chứ không nhảy sang bước cuối như khi sửa hóa đơn đã chốt, và tiêu đề
   ghi "Tiếp tục nháp".
3. **Nháp lẫn vào "Hóa đơn gần đây" ở trang chủ** mà không có nhãn trạng thái —
   thẻ ở đó không hiện trạng thái, khác với thẻ ở tab Hóa đơn. → Lọc nháp khỏi
   danh sách của trang chủ; chỗ tìm lại nháp là tab Hóa đơn, nơi mỗi thẻ có
   nhãn "Nháp".

Bài học: **widget test kiểm chứng được logic, không kiểm chứng được rằng màn
hình có hợp lý hay không.** Cả ba lỗi đều thuộc loại "nhìn một cái là thấy" và
không lỗi nào làm test đỏ. Ba test mới đã được thêm vào `bills_flow_test.dart`
để chúng không quay lại.

Lỗi thứ hai còn một bài học nữa: một hàm ở tầng dữ liệu không được gọi từ đâu
(`getDrafts()`) là dấu hiệu tính năng mới làm xong một nửa. Nếu Phase 4 có kiểm
"ai gọi hàm này" thì đã bắt được sớm hơn sáu phase.

---

### 13.17 Danh mục ngân hàng đi kèm app, và điều cần kiểm trước khi phát hành

VietQR cần **mã BIN** 6 chữ số do NAPAS cấp, không cần tên ngân hàng. Mà mã BIN
thì không gõ ra được từ tên, nên ô "Ngân hàng" ở form thành viên đổi từ ô gõ tự
do thành **bộ chọn** — chọn trong danh sách mới lưu được cả `bank_name` lẫn
`bank_bin`. Cột `bank_bin` đã có sẵn trong lược đồ từ Phase 1, nên không phải
migration.

`assets/data/banks.json` đi kèm app chứ không tải về: app phải dùng được ngay
lần mở đầu tiên khi máy đang ở chế độ máy bay.

> ⚠ **Trước khi phát hành phải đối chiếu lại danh sách mã BIN với bảng NAPAS
> công bố.** Danh sách này dựng theo hiểu biết tại thời điểm viết; ngân hàng có
> đổi tên và sáp nhập. Mã BIN sai thì QR vẫn quét được nhưng trỏ sang ngân hàng
> khác. Rủi ro có hạn vì mỗi người tự nhập tài khoản **của chính mình** và sẽ
> phát hiện ngay khi QR không dùng được — nhưng vẫn phải kiểm.

Test của danh mục nhắm vào **tính toàn vẹn dữ liệu** chứ không phải tính đúng
của từng mã: đúng 6 chữ số, không trùng, không thiếu tên. Đó là những thứ test
kiểm được; còn mã nào thuộc ngân hàng nào thì chỉ bảng của NAPAS trả lời được.

### 13.18 Khóa app **không** tự quản lý mã PIN

§7 Phase 11 ghi "vân tay/FaceID + PIN dự phòng". Đã làm khác: gọi `local_auth`
với `biometricOnly: false`, để hệ điều hành tự cho dùng mã PIN hoặc hình mở khóa
của máy khi vân tay hỏng hoặc tay ướt.

Nhờ vậy app **không lưu, không băm, không có gì để lộ**. Một mã PIN 4–6 chữ số
tự quản lý thì dù băm kiểu gì cũng dò ra được trong vài giây nếu ai đó đọc được
tệp DB — tức là nó tạo cảm giác an toàn mà không thêm an toàn thật.

Khóa này **chỉ che màn hình**, không mã hóa dữ liệu: tệp SQLite vẫn nằm trong
vùng riêng của app do hệ điều hành bảo vệ. Nó để người ngồi cạnh không mở xem
được ai nợ ai, chứ không chống được người có quyền root.

Ba quyết định về hành vi, mỗi cái đều có một cách hỏng cụ thể đứng sau:

1. **Thời gian ân hạn 30 giây.** Không khóa ngay lúc rời app: luồng dùng thật là
   mở QR rồi nhảy sang app ngân hàng rồi quay lại. Khóa ngay thì lần nào quay
   lại cũng phải quét vân tay, và người dùng sẽ tắt hẳn tính năng.
2. **Tự hỏi xác thực một lần mỗi lần khóa, không hỏi lại sau khi người dùng
   hủy.** Tự hỏi lại ngay sẽ thành vòng lặp hộp thoại không thoát ra được; màn
   khóa giữ nút "Mở khóa" làm đường quay lại.
3. **Máy không còn cách xác thực thì mở app ra và tự tắt khóa.** Người dùng bật
   khóa rồi vào cài đặt máy gỡ mã khóa màn hình: giờ không còn gì để xác thực,
   mà dữ liệu chỉ nằm trên máy này và không có đường vào nào khác. Thà mở ra còn
   hơn nhốt người dùng ngoài sổ nợ của chính họ. Đã kiểm trên emulator: bật
   khóa → `locksettings clear` → mở app → vào thẳng, và cài đặt tự tắt.

`MainActivity` phải đổi sang `FlutterFragmentActivity`: `local_auth` dựng hộp
thoại bằng androidx `BiometricPrompt`, mà cái đó đòi activity là
`FragmentActivity`. Để `FlutterActivity` thì app chạy bình thường cho tới **đúng
lúc** người dùng bật khóa, rồi mới ném lỗi — trên máy thật, không phải trong test.

Một chi tiết chỉ thấy khi chạy thật: hộp thoại xác thực của hệ điều hành là cửa
sổ bảo mật nên **không chụp màn hình được** (`screencap` trả tệp rỗng). Cách kiểm
nó có hiện hay không là `adb shell dumpsys window | grep mCurrentFocus`, thấy
`Window{… BiometricPrompt}` là được.

### 13.19 CSV dùng dấu chấm phẩy và có dấu UTF-8 ở đầu tệp

Hai chi tiết quyết định việc tệp mở ra có đọc được hay không trên máy người Việt:

- **Dấu phân cách là `;`, không phải `,`.** Excel trên máy đặt ngôn ngữ Việt lấy
  dấu phẩy làm dấu thập phân, nên tệp phân cách bằng dấu phẩy mở ra bị dồn hết
  vào một cột.
- **Tệp mở đầu bằng dấu UTF-8 (BOM).** Không có nó thì Excel đọc theo bảng mã hệ
  thống và mọi chữ có dấu thành ký tự lạ — đây là lý do phổ biến nhất khiến CSV
  tiếng Việt "hỏng".

Mỗi dòng là *một người trong một hóa đơn*, không phải một hóa đơn: số người thay
đổi theo từng hóa đơn nên dạng mỗi hóa đơn một dòng không có bộ cột cố định nào
đúng, còn dạng dài này thì xoay pivot table được.

Cột tiền ghi số nguyên thô (`300000`), không định dạng `300.000 đ`: Excel phải
nhận ra đó là số thì mới cộng được.

**Một cái bẫy khi test dấu BOM:** `File.readAsString()` dùng bộ giải mã UTF-8, mà
bộ này **tự cắt BOM đi**. Đọc bằng chuỗi thì không bao giờ thấy BOM, kể cả khi
tệp có — test phải đọc `readAsBytes()` và so ba byte đầu với `EF BB BF`. Lần đầu
chạy trên thiết bị, test báo đỏ đúng vì lý do này, và cái sai nằm ở test chứ
không ở mã.

### 13.20 Hai lỗi nữa do kiểm trên máy thật (nối tiếp 13.16)

Đi hết luồng "sửa thông tin ngân hàng → xem QR" bằng tay trên emulator lộ thêm:

1. **Màn chi tiết thành viên giữ bản chụp cũ.** `MemberDetailScreen` nhận một
   `Member` qua tham số, nên sau khi bấm sửa và lưu, màn hình vẫn hiện dữ liệu
   cũ cho tới khi thoát ra vào lại — người dùng không thấy thay đổi của chính
   mình. → Đọc lại từ `membersProvider` theo id, chỉ dùng bản truyền vào làm
   phương án tạm khi danh sách chưa nạp xong.
2. **Xóa trắng một trường tùy chọn rồi lưu thì nó không mất.** Form sửa thành
   viên dựng bản ghi mới bằng `copyWith`, mà ở đó mọi trường đều là
   `giá trị ?? giá trị cũ` — nên `null` (ô đã xóa trắng) bị hiểu là "không đổi".
   Số điện thoại cũ ở lại mãi, không có cách nào xóa. → Dựng `Member` tường minh
   ở nhánh sửa. Lỗi này có từ Phase 3 và không test nào bắt được vì không test
   nào thử **xóa** một giá trị.

Bài học lặp lại của 13.16, lần này rõ hơn: **test kiểm được điều ta nghĩ tới,
còn đi hết một luồng bằng tay thì bắt được điều ta không nghĩ tới.** Cả hai lỗi
đều đã có test riêng để không quay lại.

---

### 13.21 Tên hóa đơn lấy từ danh mục chi tiêu, không thêm khái niệm mới

Người dùng muốn "tạo sẵn danh mục tên hóa đơn, khi tạo chỉ cần chọn". App đã có
sẵn **danh mục chi tiêu** (Ăn uống, Du lịch…) dùng cho thống kê, nên có ba cách
hiểu. Đã hỏi và người dùng chọn: **dùng luôn danh mục chi tiêu làm tên**.

Cách này đánh đổi điều gì, người dùng đã được nói trước và vẫn chọn: mọi bữa ăn
đều mang tên "Ăn uống" nên danh sách hóa đơn khó phân biệt. Hai việc làm để giảm
nhẹ, mà không đi ngược lựa chọn đó:

1. **Ô tên vẫn sửa được**, chỉ là được điền sẵn. Luồng chính vẫn đúng yêu cầu —
   chọn danh mục là xong, không gõ gì.
2. **Danh sách hóa đơn ghi đủ ngày/tháng/năm** thay vì "Hôm nay". Khi tên trùng
   nhau thì ngày là thứ duy nhất phân biệt được.

Quy tắc điền tên: chỉ ghi đè khi ô tên đang trống **hoặc** đang chính là tên của
danh mục trước đó — tức là tên do máy điền. Người dùng đã gõ tên riêng
("Ăn trưa họp team") thì đổi danh mục không được xóa công của họ. Bỏ chọn danh
mục thì xóa luôn cái tên nó điền, để hóa đơn không mang tên của một danh mục
không còn được chọn.

Danh mục cũng được đưa **lên trên ô tên** trong bước 1, vì giờ nó mới là thao
tác chính.

### 13.22 Chip phải có viền mới trông như thứ bấm được

Khi đưa danh mục lên làm thao tác chính, ảnh chụp từ máy thật cho thấy các chip
trông **y hệt chữ thường**: `chipTheme` đang đặt `side: BorderSide.none`, mà nền
mặc định của chip chưa chọn gần như trùng với nền trang.

Sửa ở theme, áp dụng cho cả app: chip **chưa chọn** có viền `outlineVariant`,
chip **đã chọn** thì không (nền đậm rồi, thêm viền chỉ làm rối). Dùng
`WidgetStateBorderSide.resolveWith` để phân biệt hai trạng thái.

Đây là thứ chỉ thấy khi nhìn ảnh thật — bộ test không có khái niệm "trông có
bấm được không".

### 13.23 Tuần bắt đầu từ thứ Hai, và mốc đó tồn tại ở hai nơi

Tuần tính từ thứ Hai theo cách người Việt nói "tuần này", không theo chuẩn ISO
hay tuần bắt đầu Chủ nhật của Mỹ.

Mốc đầu tuần được tính ở **hai chỗ độc lập**:

- **Dart** (`DateFormatter.startOfWeek`) cho bộ lọc kỳ: lùi `weekday - 1` ngày.
- **SQLite** cho truy vấn gộp theo tuần: `strftime('%w')` trả 0 cho Chủ nhật tới
  6 cho thứ Bảy, nên `(w + 6) % 7` ra số ngày đã trôi qua kể từ thứ Hai.

Hai công thức khác nhau vì hai ngôn ngữ đánh số ngày khác nhau — và đó chính là
chỗ dễ lệch. Có một test nạp hóa đơn vào các ngày hiểm (thứ Hai, Chủ nhật, vắt
qua năm) rồi khẳng định mốc do SQL trả về **đúng bằng** mốc Dart tính. Lệch nhau
thì biểu đồ và bộ lọc kỳ sẽ nói hai điều khác nhau về cùng một tuần, mà không có
gì báo lỗi.

Không dùng `strftime('%W')` (số thứ tự tuần trong năm) vì từ con số đó không
dựng lại được khoảng ngày để hiển thị — mà "hiện tuần từ ngày nào tới ngày nào"
mới là thứ người dùng yêu cầu.

**Mọi kỳ đều ghi rõ khoảng ngày.** `DateRange.detail` mặc định in khoảng ngày
(`28/09 – 04/10/2026`, bỏ năm ở đầu khi cùng năm); các kỳ có cách gọi gọn hơn tự
đặt chuỗi riêng ("Tháng 10/2026", "Năm 2026", "Toàn bộ thời gian" — in hai mốc
kỹ thuật `01/01/2000 – 01/01/2100` ra màn hình chỉ làm người đọc bối rối).

### 13.24 Một `ref.read` ở chỗ dữ liệu nạp bất đồng bộ

Nút "Lưu vào món có sẵn" chỉ hiện khi món đang gõ **chưa có** trong danh sách.
Bản đầu dùng `ref.read(itemPresetsProvider)` để kiểm tra — và nút hiện cả với
món đã có.

Lý do: danh sách nạp bất đồng bộ. `ref.read` tại thời điểm chưa nạp xong trả
`AsyncLoading` với `value == null`, nên phép kiểm luôn ra "chưa có", và không có
gì làm widget dựng lại khi danh sách về. Sửa thành `ref.watch` trong `build` rồi
truyền danh sách vào hàm kiểm.

Quy tắc rút ra: **`ref.read` chỉ dùng cho dữ liệu đồng bộ hoặc trong callback**;
cái gì quyết định hình dạng giao diện thì phải `watch`.

---

### 13.25 ⚠ Đổi hẳn ý nghĩa của "chia theo món": giá **nhân** lên, không chia ra

Người dùng báo lỗi: thêm món 50.000đ, chọn 2 người, app tính mỗi người 25.000đ.
Đúng là app đang **chia** tiền món cho số người dùng món.

Cách hiểu đúng theo yêu cầu gốc ở §1 — *"chia theo giá dịch vụ của từng người"*
— là giá ghi trên món là giá **một người**, nên hai người ăn là hai lần giá đó.
Ô nhập cũng vốn tên là "Đơn giá". Đã đổi hẳn:

| | Trước | Sau |
|---|-------|-----|
| Thành tiền món | `đơn giá × số lượng` | `giá một người × tổng số phần` |
| Phần của một người trong món | `thành tiền ÷ số người` (theo trọng số) | `giá × số phần của người đó` |
| Ô "SL" (số lượng chung) | có | **bỏ** — số lượng nằm ở từng người |
| Trọng số trong món | tỷ lệ chia | **số phần**, nhân thẳng vào giá |

**Cái mất:** món cả nhóm chia một suất (nồi lẩu 500.000đ cho ba người) không
còn diễn đạt được bằng kiểu chia này. Đã nói rõ với người dùng; trường hợp đó
dùng **chia đều** (FR-4.1), vốn là đúng công cụ cho nó. Người dùng chọn phương
án này sau khi được nêu đánh đổi.

**Cái được, ngoài dự tính:** bước chia theo món giờ **không còn phép chia nào**,
nên cũng không còn phần dư. Mỗi người luôn trả một bội số nguyên của giá món, và
tổng các phần khớp tuyệt đối với tổng tiền món mà không cần thuật toán phân bổ.
Largest Remainder chỉ còn dùng cho phụ phí và làm tròn. `ItemizedStrategy` từ 70
dòng còn 30, và `Rounding.lcm` không còn chỗ gọi trong nhánh này.

**Thay đổi lan tới đâu:**

- `SplitItem` mang `unitPrice` thay vì `amount` — thành tiền phụ thuộc số người,
  mà chỉ engine mới biết đủ danh sách người tham gia hóa đơn để tính.
- `BillItem.amount` = `unitPrice × portions`; thêm `amountFor(soNguoiThamGia)`
  cho trường hợp món chưa chọn ai.
- Cột `quantity` **giữ nguyên trong lược đồ** dù không còn dùng — không bao giờ
  xóa cột (PLAN §4.5). Giao diện luôn ghi 1.
- Ví dụ kiểm chứng của SPEC §FR-4.2 và §FR-5 phải viết lại toàn bộ: từ
  lẩu/bia/nước ép → **302.000 / 301.000 / 245.000** thành phở/bún chả/trà đá/cà
  phê → **102.000 / 73.000 / 68.000**. Con số này nằm ở SPEC, PLAN, 6 tệp test
  và cả smoke test chạy trên thiết bị.

**Một lỗi tự gây ra trong lúc sửa:** `portions` tính `weightNum ~/ weightDen`,
và dữ liệu hỏng có `weightDen == 0` làm app ném `IntegerDivisionByZeroException`
**trước khi** validator kịp báo lỗi. Test nhánh biên bắt được ngay. Giờ mẫu số 0
trả 0 phần, để validator làm đúng việc của nó là báo `invalidWeight`.

### 13.26 Giao diện phải viết hẳn phép nhân ra

Sau khi đổi, sheet nhập món hiện nguyên vẹn phép tính thay vì chỉ hiện kết quả:

```
Giá một người:  50.000 đ
                50.000 đ × 2 phần = 100.000 đ
```

Lý do: chính chỗ này là chỗ người dùng hiểu nhầm và báo lỗi. Hiện mỗi con số
cuối "100.000 đ" thì vẫn phải tự đoán app đang nhân hay đang chia; viết cả phép
tính ra thì nhìn một cái là biết. Thẻ món trong danh sách cũng luôn ghi
`50.000 × 2 phần`, kể cả khi chỉ một phần.

Ô giá đổi nhãn từ "Đơn giá" thành **"Giá một người"** ở cả sheet nhập món lẫn
màn quản lý món — "đơn giá" là từ đúng nhưng không nói rõ *đơn vị là gì*.

---

### 13.27 ⚠ Một ô màu cao 0 pixel — test xanh, màn hình trống

Báo cáo "từng thành viên theo danh mục" (FR-7.13) có một thanh ngang chia đoạn
theo tỷ trọng. Test đếm widget xanh, mà trên máy thật **không một pixel nào hiện
ra** — chỗ thanh đáng lẽ nằm chỉ là khoảng trắng.

Chẩn đoán đầu tiên của tôi sai: tôi nói `SizedBox` trong `Column` nhận ràng buộc
lỏng nên `Row` toàn `Expanded` co về 0 bề ngang. Thêm `width: double.infinity`
rồi viết test đo bề ngang — **test xanh cả khi bỏ dòng vừa thêm**, nghĩa là
chẩn đoán đó không đúng (`Row` mặc định `MainAxisSize.max` nên vốn đã rộng hết).

Nguyên nhân thật nằm ở chiều còn lại:

```dart
Row(                                   // mặc định CrossAxisAlignment.center
  children: [for (...) Expanded(child: ColoredBox(color: ...))],
)
```

`ColoredBox` **không có con**, nên nó co về `constraints.smallest`. `center` cho
ràng buộc dọc **lỏng** → `smallest.height == 0` → cao 0 → `_RenderColoredBox`
không vẽ gì. Bề ngang thì vẫn đúng (`Expanded` ép chặt), nên nhìn cây widget
hoàn toàn bình thường. Sửa bằng `crossAxisAlignment: CrossAxisAlignment.stretch`.

Hai bài học:

1. **Test đo kích thước phải đo cả hai chiều.** Bản test đầu chỉ `expect` bề
   ngang > 100 và tỷ lệ các đoạn — cả hai đều đúng trong khi chiều cao bằng 0.
   Bản sau `expect(segment.height, 8)`, và bỏ `stretch` ra thì nó đỏ ngay với
   `Actual: <0.0>`.
2. **Mỗi lần sửa một lỗi giao diện, hãy bỏ bản sửa ra xem test có đỏ không.**
   Chính bước đó bắt được chẩn đoán sai của tôi — nếu không, tôi đã ghi vào mã
   một lời giải thích sai cho một lỗi vẫn còn nguyên.

Thêm `tool/crop.dart`: cắt một vùng ảnh `adb screencap` rồi phóng to theo kiểu
nearest. Ảnh chụp 1080px bị thu nhỏ lại thì một thanh 8px rất dễ bị bỏ qua —
cắt ra phóng to mới chắc là "không thấy" chứ không phải "nhìn không ra".

---

### 13.28 Cùng một bảng chéo, hai hình dạng, chỉ một cái trả lời đúng câu hỏi

Yêu cầu "báo cáo tổng chi từng thành viên theo loại dịch vụ" có hai cách dựng,
cùng đọc một bảng `thành viên × danh mục`:

| Hình dạng | Trả lời câu | |
|---|---|---|
| Mỗi người một khối, mở ra thấy các danh mục | "An tiêu vào những việc gì" | bản đầu — **sai ý** |
| Chọn danh mục, bên dưới là các thành viên | "khoản ăn uống ai tốn bao nhiêu" | bản dùng |

Tôi làm bản đầu, người dùng xem xong nói ngay *"không đúng"*. Nhìn lại thì dấu
hiệu đã có sẵn trong chính câu hỏi hay gặp của nhóm bạn: *"tháng này ai ăn uống
nhiều nhất"* — bắt đầu bằng **khoản chi**, không bắt đầu bằng người. Bản đầu bắt
người đọc mở từng khối rồi tự so trong đầu.

Phần tính toán giữ nguyên hoàn toàn — `memberCategoryTotals` và
`MemberBreakdown` không phải sửa một dòng nào, chỉ thêm `membersInCategory` lật
bảng lại ở tầng domain. Đây là lợi ích cụ thể của việc để logic ở domain chứ
không nhét trong widget: đổi hẳn hình dạng màn hình mà không đụng tới SQL, và
bộ test của tầng dữ liệu vẫn xanh nguyên.

**Ẩn bớt thành viên (FR-7.14)** đi kèm trong lần sửa này. Phạm vi ảnh hưởng cố ý
hẹp: chỉ mục này, không đụng bảng xếp hạng hay ô tổng chi của nhóm. Ẩn một người
khỏi *mọi* con số thì tổng trên màn hình không còn khớp tổng thật, mà người dùng
thì không nhớ mình đang bật bộ lọc nào. Người bị ẩn ra khỏi cả tổng của mục này,
nếu không thì các phần trăm cộng lại không thành 100%. Luôn có dòng "Đang ẩn N
người" kèm nút "Hiện lại": bộ lọc nào không nhìn thấy được thì sớm muộn cũng có
người đọc sai số.

---

## 14. Bước tiếp theo

**v1.3 đã xong.** Phase 0 → 18 hoàn tất, 507 test trên máy tính và 6 test trên
thiết bị đều xanh, `flutter analyze` không còn cảnh báo nào, APK release
19,9 MB (arm64) và vẫn không xin quyền mạng.

### Còn phải làm tay trước khi phát hành

| Việc | Vì sao không tự động được |
|------|---------------------------|
| **Đối chiếu danh sách mã BIN với bảng NAPAS** | Mã sai thì QR trỏ sang ngân hàng khác (13.17) |
| Cài lên **điện thoại thật** (arm64) | Mới chỉ chạy trên emulator x86_64; cần kiểm bàn phím tiếng Việt thật, vân tay thật, chia sẻ thật |
| **Gửi thử báo cáo lên Mattermost** | Emulator chưa cài Mattermost; mới kiểm tới bước bảng chia sẻ bật lên đúng nội dung (Phase 15) |
| §8.3 bước 8 — chia sẻ text sang Zalo | Phụ thuộc ứng dụng bên thứ ba, emulator không cài được |
| Quét thử QR bằng app ngân hàng thật | Chuỗi đã đúng định dạng và CRC đã neo vào giá trị kiểm chuẩn, nhưng chỉ app ngân hàng mới nói được là nó nhận hay không |
| Mở thử tệp CSV bằng Excel trên máy Windows tiếng Việt | Dấu phân cách và bảng mã chỉ lộ đúng/sai khi mở thật (13.19) |
| Ký APK bằng khóa phát hành | Hiện đang ký bằng khóa debug mặc định của Flutter |

### Việc đã quyết định **không** làm

| Việc | Lý do |
|------|-------|
| Hóa đơn mẫu định kỳ | Nhân bản hóa đơn (FR-3.15) đã giải quyết đúng nhu cầu đó |
| OCR hóa đơn giấy | +30 MB APK, độ chính xác với hóa đơn VN thấp — gõ tay còn nhanh hơn (§2 #18) |
| Đa tiền tệ · đồng bộ nhiều thiết bị | Trái mục tiêu chạy local hoàn toàn (§2 #20, #21) |

### Những chỗ cần đọc lại tài liệu trước khi sửa tiếp

| Chủ đề | Cần lưu ý |
|--------|-----------|
| Migration DB | Thêm cột là phải **bump `dbVersion` + viết bước migration + backfill**, kể cả khi app chưa phát hành. Lý do ở 13.13 |
| Riverpod 3 | Tên `update` đã bị chiếm trên notifier; dùng `save`. `AsyncValue` là sealed, không viết nhánh `_ =>` (13.7) |
| Widget test | `settle()` thay `pumpAndSettle`; `tapButton()` cho nút cuối form dài; DB dùng `databaseFactoryFfiNoIsolate` (13.8) |
| Tiền | Không `double` ở bất kỳ đâu trên đường đi của tiền; phần trăm lưu bằng basis point (NFR-6) |
| Biểu đồ | Thêm màu mới phải chạy lại bộ kiểm mù màu, đừng ước lượng bằng mắt (13.14) |
| Icon | Sửa hình thì chạy lại `dart run tool/generate_icon.dart`, rồi `flutter_launcher_icons` và `flutter_native_splash` (13.15) |
| VietQR | Mã kiểm tra tính trên cả `6304`, và là biến thể CRC-16/CCITT-FALSE; test neo vào `CRC("123456789") == 29B1` (13.17) |
| Khóa app | `MainActivity` phải là `FlutterFragmentActivity`; hộp thoại xác thực không chụp màn hình được, kiểm bằng `dumpsys window` (13.18) |
| CSV | `readAsString` tự cắt dấu BOM; muốn kiểm phải đọc `readAsBytes` (13.19) |
| Form sửa | Đừng dựng bản ghi bằng `copyWith` ở nhánh sửa — `?? giá trị cũ` làm người dùng không xóa trắng được trường nào (13.20) |
| Tuần | Tuần bắt đầu thứ Hai; mốc đầu tuần tính ở cả SQLite lẫn Dart, có test đối chiếu hai cách (13.23) |
| Chia theo món | Giá trên món là giá **một người**; thành tiền = giá × số phần, không có phép chia nào (13.25) |
| Riverpod | `ref.read` ở chỗ dữ liệu nạp async luôn trả null — cái gì quyết định hình dạng giao diện thì phải `watch` (13.24) |
| Đo giao diện | Test kích thước phải đo **cả hai chiều**, và sửa xong thì bỏ bản sửa ra xem test có đỏ không — đó là cách bắt được chẩn đoán sai (13.27) |
| Báo cáo | Hỏi "ai tốn bao nhiêu cho khoản này" chứ không phải "người này tiêu vào đâu" — cùng một bảng chéo, hai hình dạng, chỉ một cái đúng ý (13.28) |
| Phát hành | Chạy lại `aapt dump permissions` trên APK release sau **mỗi lần thêm plugin** (NFR-1, R6) |

### Tiến độ so với ước lượng

| Phase | Ước lượng | Trạng thái |
|-------|-----------|-----------|
| 0 · Khởi tạo | 0,5 ngày | ✅ Xong |
| 1 · Tầng dữ liệu | 1,5 ngày | ✅ Xong |
| 2 · ★ Split engine | 2,0 ngày | ✅ Xong |
| 3 · Thành viên & nhóm | 1,5 ngày | ✅ Xong |
| 4 · Hóa đơn + chia đều | 2,5 ngày | ✅ Xong |
| 5 · Chia theo món | 2,0 ngày | ✅ Xong |
| 6 · Phụ phí & kiểu chia còn lại | 1,5 ngày | ✅ Xong |
| 7 · Thanh toán & Quyết toán | 1,5 ngày | ✅ Xong |
| 8 · Thống kê | 2,0 ngày | ✅ Xong |
| 9 · Chia sẻ, sao lưu, cài đặt | 1,5 ngày | ✅ Xong |
| 10 · Hoàn thiện & phát hành | 1,5 ngày | ✅ Xong |
| **v1.0** | **18 ngày** | **✅ 100%** |
| 11 · VietQR · khóa app · xuất CSV | 2,0 ngày | ✅ Xong |
| **v1.1** | **20 ngày** | **✅ 100%** |
| 12 · Món có sẵn · báo cáo tuần · tên từ danh mục | 1,0 ngày | ✅ Xong |
| **v1.2** | **21 ngày** | **✅ 100%** |
| 13 · Sửa logic chia theo món | 0,5 ngày | ✅ Xong |
| **v1.3** | **21,5 ngày** | **✅ 100%** |
