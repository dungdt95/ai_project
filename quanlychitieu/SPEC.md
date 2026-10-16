# Đặc tả ứng dụng: Quản lý Thu Chi Cá Nhân

> Tài liệu mô tả yêu cầu, kiến trúc và mô hình dữ liệu để dùng làm input sinh source code mobile app **Quản lý Thu Chi Cá Nhân** chạy hoàn toàn offline (local).

---

## 1. Tổng quan

- **Tên ứng dụng:** Quản lý Thu Chi Cá Nhân (`quanlychitieu`)
- **Nền tảng mục tiêu:** **Android 14 (API level 34)** — ưu tiên build và test trên Android 14 trước; codebase Flutter giữ khả năng build iOS sau này.
- **Ngôn ngữ giao diện:** Tiếng Việt
- **Loại ứng dụng:** Offline-first, chạy local hoàn toàn (không backend, không đăng nhập, không đồng bộ cloud)
- **Đối tượng người dùng:** Cá nhân muốn theo dõi thu chi, tiền gửi ngân hàng, các khoản cho vay
- **Tiền tệ mặc định:** VND (đ)

### Cấu hình Android (bắt buộc cho Android 14)

| Thuộc tính           | Giá trị                                      |
|----------------------|----------------------------------------------|
| `compileSdkVersion`  | **34**                                       |
| `targetSdkVersion`   | **34** (Android 14)                          |
| `minSdkVersion`      | **24** (Android 7.0) — đề xuất, đủ rộng       |
| Java/Kotlin          | JDK 17, Kotlin 1.9+                          |
| Gradle               | 8.x, Android Gradle Plugin 8.1+              |
| NDK (nếu cần)        | r26 trở lên                                  |
| Package name         | `com.quanlychitieu.app` (gợi ý)              |

#### Yêu cầu mới của Android 14 cần tuân thủ
1. **Foreground service types**: nếu dùng foreground service (ví dụ cho backup chạy nền) phải khai báo `foregroundServiceType` trong `AndroidManifest.xml` — app này hiện không cần FGS, dùng `WorkManager` cho job nền.
2. **Exact alarms (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`)**: dùng cho local notification nhắc đáo hạn sổ tiết kiệm và đến hạn trả nợ.
   - Trên Android 14, `SCHEDULE_EXACT_ALARM` mặc định **không được cấp**, người dùng phải bật trong Settings → Alarms & reminders.
   - Hoặc dùng `USE_EXACT_ALARM` cho app có chức năng nhắc nhở chính đáng (đã được Google Play cho phép) — không cần xin runtime.
   - Plugin `flutter_local_notifications` ≥ 17.x đã hỗ trợ flag `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`.
3. **Quyền thông báo (`POST_NOTIFICATIONS`)**: từ Android 13+ là runtime permission — phải xin khi mở app lần đầu hoặc trước khi tạo notification đầu tiên.
4. **Photo Picker / Storage Access**: nếu cho phép chọn file backup để import → dùng **Photo Picker** hoặc `Storage Access Framework` (`ACTION_OPEN_DOCUMENT`), KHÔNG cần `READ_EXTERNAL_STORAGE` trên Android 13+.
5. **Backup file lưu trong app-specific storage** (`getExternalFilesDir`) — không cần quyền lưu trữ. Khi muốn chia sẻ, dùng `share_plus` (FileProvider đã được Flutter handle).
6. **Predictive Back Gesture**: Android 14 đẩy mạnh tính năng vuốt quay lại — bật `android:enableOnBackInvokedCallback="true"` trong `<application>` để đảm bảo hành vi mượt.
7. **Implicit intent restrictions**: hạn chế intent ngầm sang component không export — không ảnh hưởng app này (không expose intent).
8. **Ngôn ngữ riêng cho app (Per-app language)**: Android 13+ hỗ trợ; có thể bỏ qua vì app chỉ tiếng Việt.
9. **Themed app icon**: nên cung cấp `monochrome` icon trong `ic_launcher` để tương thích themed icon của Android 13/14.

#### `AndroidManifest.xml` — quyền cần khai báo

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<!-- fallback cho thiết bị < Android 14 -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<!-- nếu bật khóa sinh trắc học -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

> Không khai báo `READ/WRITE_EXTERNAL_STORAGE` — backup ghi vào app-specific storage và export qua share sheet.

#### Thiết bị test
- Tối thiểu test trên 1 thiết bị Android 14 thật (Pixel / Samsung One UI 6) + 1 emulator API 34.
- Verify:
  - Notification hiện đúng sau khi cấp `POST_NOTIFICATIONS`.
  - Alarm chính xác kích hoạt sau khi reboot (cần `RECEIVE_BOOT_COMPLETED` + reschedule).
  - Predictive back gesture không gây crash.
  - Themed icon hiển thị đúng.

### Mục tiêu
1. Ghi nhận nhanh các giao dịch thu/chi hằng ngày.
2. Theo dõi các khoản tiền gửi ngân hàng và ngày đến hạn (sổ tiết kiệm).
3. Theo dõi các khoản cho người khác vay, nhóm theo người vay.
4. Cung cấp báo cáo trực quan để người dùng nắm tình hình tài chính.

---

## 2. Công nghệ đề xuất

| Hạng mục          | Lựa chọn đề xuất                          | Ghi chú |
|-------------------|-------------------------------------------|---------|
| Framework         | **Flutter (Dart)**                        | Cross-platform, hiệu năng tốt, UI mượt |
| Quản lý state     | **Riverpod** (hoặc Provider/Bloc)         | Riverpod đơn giản, dễ test |
| CSDL local        | **SQLite qua `sqflite` + `drift`**        | Drift cho ORM type-safe, query tiện |
| Cấu hình lưu nhanh| `shared_preferences`                      | Lưu setting (theme, currency, ...) |
| Biểu đồ           | `fl_chart`                                | Vẽ pie/bar/line chart |
| Định dạng số/ngày | `intl`                                    | Format VND, dd/MM/yyyy |
| Thông báo         | `flutter_local_notifications` ≥ 17.x      | Hỗ trợ Android 14 exact alarm, runtime permission |
| Permission helper | `permission_handler` ≥ 11.x               | Xin `POST_NOTIFICATIONS`, kiểm tra exact alarm |
| Job nền (nếu cần) | `workmanager`                             | Reschedule alarm sau reboot |
| Sao lưu/khôi phục | `path_provider` + `share_plus` + JSON     | Export/Import file backup |
| Icon              | `flutter_svg` + bộ icon Material          | |

> **Lưu ý:** Có thể thay bằng React Native + WatermelonDB/SQLite nếu team quen JS. Yêu cầu cốt lõi: **dữ liệu nằm hoàn toàn trên thiết bị**.

---

## 3. Chức năng chi tiết

### 3.1. Quản lý khoản chi (Expense)
- Thêm/sửa/xóa khoản chi.
- Trường dữ liệu:
  - Số tiền (bắt buộc, > 0)
  - Danh mục (Ăn uống, Đi lại, Mua sắm, Hóa đơn, Giải trí, Sức khỏe, Học tập, Khác — có thể tự thêm)
  - Ngày giao dịch (mặc định hôm nay)
  - Ghi chú (tùy chọn)
  - Phương thức thanh toán: Tiền mặt / Thẻ / Chuyển khoản (tùy chọn)
- Lọc theo: ngày, khoảng ngày, danh mục.
- Tổng chi theo ngày/tuần/tháng.

### 3.2. Quản lý khoản thu (Income)
- Thêm/sửa/xóa khoản thu.
- Trường dữ liệu:
  - Số tiền (bắt buộc, > 0)
  - Danh mục (Lương, Thưởng, Đầu tư, Quà tặng, Khác — có thể tự thêm)
  - Ngày giao dịch
  - Ghi chú (tùy chọn)
- Lọc & tổng hợp tương tự khoản chi.

### 3.3. Quản lý tiền gửi ngân hàng (BankDeposit)
- Thêm/sửa/xóa/đóng sổ tiết kiệm.
- Trường dữ liệu:
  - Ngân hàng (chọn từ danh sách: **MB, TPBank, Techcombank**, có thể mở rộng)
  - Số tiền gốc
  - Lãi suất (%/năm) — tùy chọn
  - Ngày gửi
  - Ngày đến hạn (bắt buộc)
  - Kỳ hạn (tự tính từ ngày gửi → ngày đến hạn, hoặc nhập tay)
  - Ghi chú
  - Trạng thái: **Đang hiệu lực / Đã tất toán**
- Hiển thị:
  - Tổng tiền gửi đang hoạt động.
  - Danh sách sổ sắp đáo hạn (≤ 7 ngày).
  - Cảnh báo/nhắc nhở qua local notification trước ngày đến hạn N ngày (cấu hình được, mặc định 3 ngày).

### 3.4. Quản lý tiền cho vay (Loan)
- Thêm/sửa/xóa khoản cho vay.
- Trường dữ liệu:
  - Người vay (Borrower) — tham chiếu đến bảng `borrowers`
  - Số tiền cho vay
  - Ngày cho vay
  - Ngày dự kiến trả
  - Lãi suất (tùy chọn, mặc định 0)
  - Ghi chú
  - Trạng thái: **Chưa trả / Đã trả một phần / Đã trả đủ / Quá hạn (auto)**
- Có thể ghi nhận **các lần trả nợ** (LoanPayment): số tiền, ngày trả, ghi chú.
- **Nhóm theo người vay**: ở màn hình danh sách, cho phép view dạng nhóm (group by borrower) — mỗi nhóm hiển thị:
  - Tên người vay
  - Tổng đã cho vay
  - Tổng đã thu hồi
  - Tổng còn nợ
  - Số khoản vay đang mở
- Nhắc nhở local notification khi đến gần ngày dự kiến trả.

### 3.5. Báo cáo (Reports)
Các báo cáo tối thiểu:
1. **Tổng quan tháng hiện tại**: tổng thu, tổng chi, chênh lệch (số dư), so với tháng trước (%).
2. **Biểu đồ tròn (Pie chart)**: tỷ lệ chi theo danh mục trong khoảng thời gian.
3. **Biểu đồ cột (Bar chart)**: thu vs chi theo từng tháng (12 tháng gần nhất).
4. **Biểu đồ đường (Line chart)**: xu hướng số dư tích lũy theo ngày/tháng.
5. **Tổng tài sản hiện có** (ước tính):
   - Tiền mặt/tài khoản (= Tổng thu − Tổng chi)
   - Tiền gửi ngân hàng đang hoạt động
   - Tiền đang cho vay chưa thu hồi
   - **Tổng tài sản** = tổng 3 mục trên.
6. **Báo cáo người vay**: bảng xếp hạng người đang nợ nhiều nhất.
7. **Bộ lọc thời gian**: Tuần / Tháng / Quý / Năm / Tùy chỉnh.

### 3.6. Chức năng phụ trợ
- **Cài đặt**: theme sáng/tối, ngôn ngữ (chỉ tiếng Việt phiên bản đầu), đơn vị tiền tệ, số ngày nhắc nhở đáo hạn.
- **Quản lý danh mục** (CRUD): thêm danh mục mới cho thu/chi, sửa icon/màu sắc.
- **Quản lý ngân hàng** (CRUD): thêm ngân hàng mới ngoài MB/TP/Tech.
- **Quản lý người vay** (CRUD): thêm/sửa/xóa người vay (kèm SĐT, ghi chú).
- **Sao lưu & Khôi phục**:
  - Export toàn bộ dữ liệu ra file JSON (chia sẻ qua Zalo/Drive thủ công).
  - Import từ file JSON đã export.
- **Bảo mật (tùy chọn)**: PIN code / sinh trắc học để mở app (`local_auth`).

---

## 4. Mô hình dữ liệu (SQLite)

### 4.1. Bảng `categories`
| Cột          | Kiểu        | Ràng buộc                          |
|--------------|-------------|------------------------------------|
| id           | INTEGER PK  | autoincrement                      |
| name         | TEXT        | NOT NULL                           |
| type         | TEXT        | `'expense'` hoặc `'income'`        |
| icon         | TEXT        | tên icon                           |
| color        | TEXT        | hex color                          |
| is_default   | INTEGER     | 0/1 — danh mục mặc định không xóa  |

### 4.2. Bảng `transactions`
| Cột          | Kiểu        | Ràng buộc                                     |
|--------------|-------------|-----------------------------------------------|
| id           | INTEGER PK  | autoincrement                                 |
| type         | TEXT        | `'expense'` / `'income'`                      |
| amount       | REAL        | NOT NULL, > 0                                 |
| category_id  | INTEGER     | FK → categories(id)                           |
| date         | TEXT        | ISO8601 `YYYY-MM-DD`                          |
| note         | TEXT        | nullable                                      |
| payment_method | TEXT      | `'cash'`/`'card'`/`'transfer'` — nullable     |
| created_at   | TEXT        | ISO8601                                       |
| updated_at   | TEXT        | ISO8601                                       |

### 4.3. Bảng `banks`
| Cột       | Kiểu       | Ràng buộc      |
|-----------|------------|----------------|
| id        | INTEGER PK | autoincrement  |
| code      | TEXT       | UNIQUE (`MB`, `TPB`, `TCB`, ...) |
| name      | TEXT       | NOT NULL       |
| logo      | TEXT       | path/asset key |

> Seed mặc định: `MB - Ngân hàng Quân Đội`, `TPB - TPBank`, `TCB - Techcombank`.

### 4.4. Bảng `bank_deposits`
| Cột            | Kiểu        | Ràng buộc                              |
|----------------|-------------|----------------------------------------|
| id             | INTEGER PK  | autoincrement                          |
| bank_id        | INTEGER     | FK → banks(id)                         |
| amount         | REAL        | NOT NULL, > 0                          |
| interest_rate  | REAL        | nullable (% / năm)                     |
| start_date     | TEXT        | ISO8601                                |
| due_date       | TEXT        | ISO8601, NOT NULL                      |
| term_months    | INTEGER     | nullable                               |
| status         | TEXT        | `'active'` / `'closed'`                |
| note           | TEXT        | nullable                               |
| created_at     | TEXT        |                                        |
| updated_at     | TEXT        |                                        |

### 4.5. Bảng `borrowers`
| Cột     | Kiểu       | Ràng buộc      |
|---------|------------|----------------|
| id      | INTEGER PK | autoincrement  |
| name    | TEXT       | NOT NULL       |
| phone   | TEXT       | nullable       |
| note    | TEXT       | nullable       |

### 4.6. Bảng `loans`
| Cột               | Kiểu        | Ràng buộc                                         |
|-------------------|-------------|---------------------------------------------------|
| id                | INTEGER PK  | autoincrement                                     |
| borrower_id       | INTEGER     | FK → borrowers(id)                                |
| amount            | REAL        | NOT NULL, > 0                                     |
| loan_date         | TEXT        | ISO8601                                           |
| expected_return_date | TEXT     | ISO8601                                           |
| interest_rate     | REAL        | mặc định 0                                        |
| status            | TEXT        | `'unpaid'`/`'partial'`/`'paid'`/`'overdue'`       |
| note              | TEXT        | nullable                                          |
| created_at        | TEXT        |                                                   |
| updated_at        | TEXT        |                                                   |

### 4.7. Bảng `loan_payments`
| Cột          | Kiểu        | Ràng buộc                  |
|--------------|-------------|----------------------------|
| id           | INTEGER PK  | autoincrement              |
| loan_id      | INTEGER     | FK → loans(id) ON DELETE CASCADE |
| amount       | REAL        | NOT NULL, > 0              |
| paid_date    | TEXT        | ISO8601                    |
| note         | TEXT        | nullable                   |

### 4.8. Bảng `settings`
| Cột   | Kiểu | Ràng buộc          |
|-------|------|--------------------|
| key   | TEXT | PK                 |
| value | TEXT |                    |

> Lưu các setting: `theme`, `currency`, `due_reminder_days`, `pin_enabled`, ...

### 4.9. Quan hệ tóm tắt
```
categories (1) ─── (N) transactions
banks      (1) ─── (N) bank_deposits
borrowers  (1) ─── (N) loans
loans      (1) ─── (N) loan_payments
```

---

## 5. Cấu trúc màn hình (Navigation)

Sử dụng Bottom Navigation Bar 5 tab:

1. **Trang chủ (Home)**
   - Tóm tắt tháng: tổng thu, tổng chi, số dư
   - Tổng tài sản hiện có
   - 5 giao dịch gần nhất
   - Sổ tiết kiệm sắp đáo hạn
   - Khoản vay sắp đến hạn trả

2. **Giao dịch (Transactions)**
   - Tab con: Chi / Thu
   - Danh sách giao dịch theo ngày (group by date)
   - Filter: tháng, danh mục
   - FAB: thêm giao dịch

3. **Tiền gửi (Deposits)**
   - Danh sách sổ tiết kiệm (active / closed)
   - Tổng tiền gửi
   - FAB: thêm sổ mới
   - Tap vào sổ → màn hình chi tiết (đóng sổ, sửa, xóa)

4. **Cho vay (Loans)**
   - Toggle view: "Theo khoản vay" / **"Theo người vay" (default)**
   - Khi group theo người: mỗi card hiển thị tên + tổng còn nợ + số khoản
   - Tap vào người → list các khoản vay của người đó
   - Tap vào khoản vay → chi tiết + ghi nhận trả nợ
   - FAB: thêm khoản vay mới

5. **Báo cáo (Reports)**
   - Bộ chọn khoảng thời gian
   - Các biểu đồ như mục 3.5
   - Có thể export PDF/ảnh (nâng cao, optional)

**Màn hình ngoài tab:**
- Cài đặt (vào từ Home)
- Quản lý danh mục
- Quản lý ngân hàng
- Quản lý người vay
- Sao lưu / Khôi phục
- Form thêm/sửa cho từng entity

---

## 6. Luồng dữ liệu & nghiệp vụ chính

### 6.1. Cập nhật trạng thái khoản vay
- Khi thêm `loan_payment`:
  - Tính `total_paid = SUM(loan_payments.amount WHERE loan_id = X)`
  - Nếu `total_paid >= loan.amount` → `status = 'paid'`
  - Nếu `0 < total_paid < loan.amount` → `status = 'partial'`
  - Nếu `total_paid = 0` và `today > expected_return_date` → `status = 'overdue'`
  - Còn lại → `status = 'unpaid'`
- Job kiểm tra `overdue` chạy mỗi lần mở app.

### 6.2. Tính tổng tài sản
```
cash_balance     = SUM(income.amount) − SUM(expense.amount)
deposit_balance  = SUM(bank_deposits.amount WHERE status='active')
loan_outstanding = SUM(loans.amount) − SUM(loan_payments.amount)  -- với loans chưa paid
total_asset      = cash_balance + deposit_balance + loan_outstanding
```

### 6.3. Nhắc nhở local
- Khi tạo/sửa `bank_deposit`: lên lịch notification vào `due_date − reminder_days`.
- Khi tạo/sửa `loan`: lên lịch notification vào `expected_return_date`.
- Khi xóa/đóng/đã trả: hủy notification tương ứng.

---

## 7. Cấu trúc thư mục source (Flutter đề xuất)

```
lib/
├── main.dart
├── app.dart                      # MaterialApp, theme, routes
├── core/
│   ├── constants/                # màu, key, enum
│   ├── utils/                    # format tiền, ngày
│   └── widgets/                  # widget dùng chung (AmountText, EmptyState…)
├── data/
│   ├── database/
│   │   ├── app_database.dart     # Drift DB
│   │   └── tables/               # định nghĩa các bảng
│   ├── models/                   # data class
│   └── repositories/             # CategoryRepo, TransactionRepo, ...
├── features/
│   ├── home/
│   ├── transactions/
│   ├── deposits/
│   ├── loans/
│   ├── reports/
│   └── settings/
│       ├── categories/
│       ├── banks/
│       ├── borrowers/
│       └── backup/
├── services/
│   ├── notification_service.dart
│   ├── backup_service.dart
│   └── auth_service.dart         # PIN / biometrics
└── l10n/                         # dịch (vi mặc định)
```

Mỗi `feature/xxx` chứa: `presentation/` (screen + widget), `application/` (controllers/notifiers), tái sử dụng repo từ `data/`.

---

## 8. UI/UX notes
- Số tiền hiển thị có dấu phân cách `.` và đơn vị `đ`. Ví dụ: `1.250.000 đ`.
- Màu quy ước: chi = đỏ, thu = xanh lá, tiền gửi = xanh dương, cho vay = cam.
- Form nhập số tiền: bàn phím số, tự format khi gõ.
- Ngày nhập qua `showDatePicker`, hiển thị `dd/MM/yyyy`.
- Trạng thái rỗng (Empty state) cho tất cả màn list.
- Confirm khi xóa.

---

## 9. Roadmap đề xuất

| Giai đoạn | Phạm vi |
|-----------|---------|
| **MVP**   | Thu/Chi + danh mục, Tiền gửi, Cho vay (group by người) + LoanPayment, Home, Báo cáo cơ bản (tổng thu/chi tháng + pie theo danh mục), Backup JSON |
| **v1.1**  | Notification đáo hạn / đến hạn trả, Quản lý danh mục/ngân hàng/người vay, Theme tối |
| **v1.2**  | Báo cáo nâng cao (line chart, bar chart), Tổng tài sản, Filter nâng cao |
| **v1.3**  | PIN/biometric, Export PDF báo cáo, Đa ngôn ngữ |

---

## 10. Tiêu chí hoàn thành (Acceptance)

- App build & cài đặt chạy ổn định trên **Android 14 (API 34)** dạng APK release, không cần internet.
- `targetSdkVersion = 34`, đáp ứng các yêu cầu mới (POST_NOTIFICATIONS, exact alarm, predictive back, themed icon).
- Toàn bộ dữ liệu lưu trong SQLite trên thiết bị; gỡ app → mất dữ liệu (trừ khi đã backup).
- Tất cả 5 nhóm chức năng (chi, thu, tiền gửi, cho vay, báo cáo) hoạt động CRUD đầy đủ.
- Cho vay có chế độ xem nhóm theo người vay với tổng còn nợ chính xác.
- Báo cáo hiển thị đúng số liệu đối chiếu được với tổng các bảng.
- Có chức năng export/import JSON backup hoạt động được (qua share sheet, không cần quyền storage).
- Local notification nhắc đáo hạn / đến hạn trả nợ kích hoạt đúng giờ trên thiết bị Android 14, kể cả sau reboot.
