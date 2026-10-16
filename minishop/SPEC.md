# Mini Shop — App Quản Lý Quán Nước (Local-only, Android)

## 1. Tổng quan

App di động giúp chủ quán nước nhỏ quản lý mặt hàng, tạo hóa đơn, tạo QR
chuyển tiền, tự động xác nhận thanh toán qua thông báo ngân hàng, và xem
báo cáo doanh thu. **Toàn bộ dữ liệu lưu local trên máy, không có backend,
không bắt buộc kết nối Internet** để hoạt động (trừ việc nhận thông báo từ
app ngân hàng — bản thân việc đó cũng không cần app của chúng ta gọi mạng).

## 2. Ràng buộc & phạm vi đã xác nhận

| Hạng mục | Quyết định |
|---|---|
| Framework | **Flutter** (1 codebase, Dart) |
| Nền tảng | **Android only**. iOS không hỗ trợ đọc thông báo app khác (giới hạn của Apple), nên không build bản iOS trong scope này. |
| Lưu trữ | 100% local — SQLite (`sqflite`), không backend, không cloud sync |
| Ngân hàng/ví cần parse thông báo | MBBank, Vietcombank (VCB), Techcombank, Momo |
| Chuẩn QR chuyển tiền | **VietQR / Napas 247** (sinh hoàn toàn offline theo spec EMVCo, không gọi API ngoài) |

### Lưu ý quan trọng — Momo
VietQR là chuẩn QR **tài khoản ngân hàng**, không áp dụng cho ví Momo (Momo
dùng QR tĩnh riêng của từng người dùng, không sinh được bằng công thức).
Do đó:
- Với MBBank / VCB / Techcombank: app **tự sinh QR VietQR** kèm số tiền + nội dung.
- Với Momo: app **không tự sinh QR**, chỉ hỗ trợ đọc & nhận diện thông báo
  "đã nhận tiền" từ app Momo để tự xác nhận hóa đơn. Chủ quán có thể upload
  ảnh QR Momo tĩnh của mình để hiển thị thủ công nếu muốn (tùy chọn, không
  bắt buộc trong v1).

## 3. Tech stack đề xuất

- **Flutter** (stable channel) + Dart
- **State management**: Provider (đơn giản, đủ cho scope app này; có thể
  nâng cấp Riverpod sau nếu cần)
- **Local DB**: `sqflite` + `path_provider`
- **QR render**: `qr_flutter` (vẽ QR từ string EMVQR tự build, không cần API)
- **Charts báo cáo**: `fl_chart`
- **Format tiền/ngày**: `intl`
- **Quyền hệ thống**: `permission_handler`
- **Đọc thông báo Android**: ưu tiên thử package Flutter có sẵn (ví dụ
  `flutter_notification_listener`). Nếu không ổn định/không maintain tốt,
  **fallback viết native Android (Kotlin) bằng `NotificationListenerService`**
  và bridge qua `MethodChannel`/`EventChannel` — vì đây là tính năng lõi,
  cần độ tin cậy cao hơn là tiện lợi của plugin có sẵn.

## 4. Kiến trúc tổng thể

```
lib/
  main.dart
  core/
    db/                # sqflite helper, migrations
    qr/                # VietQR string builder (EMVCo TLV)
    notification/       # platform channel wrapper, parser theo từng bank
    utils/               # format tiền, ngày, currency
  data/
    models/             # Item, Category, Invoice, InvoiceItem, BankAccount, Settings
    repositories/        # ItemRepository, InvoiceRepository, ReportRepository
  features/
    items/               # CRUD mặt hàng
    invoices/            # tạo/sửa hóa đơn, danh sách, chi tiết
    payment_qr/          # màn hình hiển thị QR + trạng thái chờ thanh toán
    notification_listener/  # service đọc & match thông báo
    reports/             # báo cáo doanh thu, top sản phẩm
    settings/            # thông tin quán, tài khoản ngân hàng, chọn app ngân hàng cần lắng nghe
  android/
    .../NotificationListener.kt   # (nếu cần native fallback)
```

## 5. Data model (SQLite)

### `categories`
| field | type | note |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | VD: Trà sữa, Cà phê, Nước ép |

### `items` (mặt hàng)
| field | type | note |
|---|---|---|
| id | INTEGER PK | |
| category_id | INTEGER FK | |
| name | TEXT | |
| price | INTEGER | VNĐ |
| unit | TEXT | ly/chai... |
| is_active | INTEGER | ẩn/hiện món |
| image_path | TEXT NULL | ảnh local optional |

### `invoices` (hóa đơn)
| field | type | note |
|---|---|---|
| id | INTEGER PK | |
| code | TEXT UNIQUE | mã hóa đơn, VD `HD000123` — **dùng làm nội dung chuyển khoản để match thông báo** |
| created_at | DATETIME | |
| total_amount | INTEGER | |
| status | TEXT | `unpaid` \| `paid` \| `cancelled` |
| paid_at | DATETIME NULL | |
| paid_method | TEXT NULL | `bank_transfer` \| `cash` \| `momo` |
| matched_notification_id | INTEGER NULL FK | log nào đã confirm hóa đơn này |

### `invoice_items`
| field | type | note |
|---|---|---|
| id | INTEGER PK | |
| invoice_id | INTEGER FK | |
| item_id | INTEGER FK | |
| item_name_snapshot | TEXT | lưu lại tên/giá tại thời điểm bán, tránh đổi giá sau ảnh hưởng hóa đơn cũ |
| price_snapshot | INTEGER | |
| quantity | INTEGER | |

### `bank_accounts` (settings)
| field | type | note |
|---|---|---|
| id | INTEGER PK | |
| bank_bin | TEXT | mã BIN ngân hàng theo Napas (VD MB=970422, VCB=970436, TCB=970407) |
| bank_name | TEXT | |
| account_number | TEXT | |
| account_name | TEXT | tên chủ TK không dấu, in hoa |
| is_default | INTEGER | TK dùng để sinh QR mặc định |

### `notification_logs` (audit trail)
| field | type | note |
|---|---|---|
| id | INTEGER PK | |
| source_app | TEXT | package name app ngân hàng |
| raw_text | TEXT | nội dung gốc thông báo |
| parsed_amount | INTEGER NULL | |
| parsed_code | TEXT NULL | mã hóa đơn nhận diện được trong nội dung |
| received_at | DATETIME | |
| matched_invoice_id | INTEGER NULL FK | |
| match_status | TEXT | `auto_matched` \| `ambiguous` \| `no_match` |

## 6. Chức năng chi tiết

### 6.1 Quản lý mặt hàng
- CRUD mặt hàng theo danh mục, bật/tắt hiển thị, giá, đơn vị tính.
- Danh sách lọc theo category, tìm kiếm theo tên.
- (v1 không cần quản lý tồn kho/nguyên liệu — quán nước thường bán theo công thức, không track inventory; có thể bổ sung sau nếu cần.)

### 6.2 Quản lý hóa đơn
- Tạo hóa đơn mới: chọn mặt hàng + số lượng → tính tổng tiền.
- Mỗi hóa đơn có mã `code` duy nhất, tự sinh tăng dần (HD000001, HD000002...).
- Trạng thái: `unpaid` (mới tạo) → `paid` (xác nhận, tự động hoặc thủ công)
  hoặc `cancelled`.
- Màn hình danh sách hóa đơn: filter theo trạng thái/ngày.
- Cho phép xác nhận thanh toán **thủ công** (nút "Đã nhận tiền") làm
  fallback khi không dùng notification hoặc match thất bại.

### 6.3 Tạo QR chuyển tiền từ hóa đơn
- Từ màn hình chi tiết hóa đơn `unpaid`, sinh QR VietQR với:
  - Số tiền = `total_amount`
  - Nội dung chuyển khoản (`addInfo`) = mã hóa đơn (`code`) — **đây là
    chìa khóa để bước 6.4 match chính xác**, vì amount có thể trùng giữa
    nhiều hóa đơn nhưng nội dung gần như luôn unique.
  - Build chuỗi theo chuẩn EMVCo/VietQR (TLV) hoàn toàn local, không gọi API.
- Hiển thị QR full-screen để khách quét bằng app banking bất kỳ hỗ trợ VietQR.
- Màn hình QR có trạng thái "đang chờ thanh toán" — tự cập nhật thành
  "đã thanh toán ✅" ngay khi notification listener match được hóa đơn này.

### 6.4 Đọc thông báo chuyển tiền → tự xác nhận hóa đơn
- Dùng `NotificationListenerService` (Android) lắng nghe thông báo từ các
  package đã chọn trong Settings (MBBank, VCB, Techcombank, Momo).
- Với mỗi thông báo nhận được:
  1. Lọc theo package name có trong whitelist.
  2. Regex parse số tiền (mỗi bank có format khác nhau, cần viết parser
     riêng theo từng bank — sẽ khảo sát mẫu thông báo thực tế của từng app
     trong giai đoạn implement).
  3. Regex tìm mã hóa đơn (`HD\d+`) trong nội dung thông báo.
  4. Lưu vào `notification_logs` (raw text + parsed data) để audit/debug.
  5. Logic match:
     - Nếu tìm được mã hóa đơn khớp với 1 hóa đơn `unpaid` → **auto confirm**,
       set `status = paid`, `paid_at = now`, `matched_notification_id`.
     - Nếu không tìm được mã nhưng số tiền khớp **đúng 1** hóa đơn `unpaid`
       gần đây (trong khoảng thời gian, ví dụ 24h) → auto confirm theo amount.
     - Nếu số tiền khớp **nhiều hơn 1** hóa đơn → đánh dấu `ambiguous`,
       hiển thị banner cho chủ quán chọn tay hóa đơn nào khớp.
     - Không khớp gì → lưu log `no_match`, không tự động làm gì cả.
- Quyền cần xin: `Notification access` (đặc biệt, phải vào Settings hệ
  thống bật tay, Android không cho xin qua dialog runtime thông thường).
  App cần có màn hình hướng dẫn + nút mở thẳng trang Settings tương ứng.
- App phải chạy nền (foreground service hoặc listener bền) để không bị hệ
  thống Android kill mất khả năng nhận thông báo.

### 6.5 Báo cáo
- Doanh thu theo ngày / tuần / tháng (chỉ tính hóa đơn `status = paid`).
- Top mặt hàng bán nhiều nhất / mang lại doanh thu nhiều nhất.
- Biểu đồ cột/đường theo khung thời gian chọn (dùng `fl_chart`).
- Số hóa đơn đã thanh toán / chưa thanh toán / hủy trong khung thời gian.
- Export đơn giản (optional v1.x): xuất CSV ra storage local.

## 7. Quyền Android cần khai báo

- `BIND_NOTIFICATION_LISTENER_SERVICE` — đọc thông báo.
- `FOREGROUND_SERVICE` (nếu cần service nền ổn định hơn).
- `RECEIVE_BOOT_COMPLETED` (tùy chọn — tự khởi động listener sau khi reboot máy).
- Không cần quyền Internet/network cho các chức năng core (DB local + QR
  sinh offline). Có thể không khai báo `INTERNET` permission luôn nếu muốn
  khẳng định với người dùng app hoàn toàn offline.

## 8. Roadmap triển khai đề xuất

1. **Milestone 1 — Core CRUD**: setup project Flutter, SQLite schema,
   quản lý mặt hàng + danh mục.
2. **Milestone 2 — Hóa đơn**: tạo/sửa/hủy hóa đơn, tính tổng, danh sách,
   xác nhận thanh toán thủ công.
3. **Milestone 3 — VietQR**: build EMVQR string, màn hình hiển thị QR theo
   hóa đơn, settings tài khoản ngân hàng.
4. **Milestone 4 — Notification listener**: xin quyền, lắng nghe, parser
   theo từng bank (khảo sát mẫu thực tế), matching logic, audit log,
   xử lý ambiguous case.
5. **Milestone 5 — Báo cáo**: thống kê doanh thu, top sản phẩm, biểu đồ.
6. **Milestone 6 — Polish**: UI/UX, xử lý edge case (mất quyền notification,
   app bị kill, đổi thiết bị mất data...).

## 9. Rủi ro & lưu ý cần theo dõi khi code

- Format nội dung thông báo của mỗi bank **có thể thay đổi** khi bank
  update app → parser cần dễ chỉnh sửa (tách riêng từng file parser theo
  bank, không hardcode chung 1 regex).
- Android có thể giới hạn/kill background service theo OEM (Xiaomi, Oppo,
  Samsung...) → cần hướng dẫn người dùng tắt battery optimization cho app.
- Vì không có backend, **mất máy/cài lại app = mất hết dữ liệu** trừ khi
  có backup. Nên có chức năng export/backup file DB ra storage ngay từ
  sớm (không nhất thiết v1 nhưng nên note để làm sớm).
- Mã hóa đơn dùng làm nội dung chuyển khoản: cần ngắn gọn, không dấu, dễ
  nhận diện qua regex (tránh trùng với cú pháp mà bank tự thêm vào).

---

*File này dùng làm spec đầu vào để generate source code. Nếu cần điều
chỉnh phạm vi (VD thêm quản lý tồn kho, multi-user, backup cloud...) hãy
cập nhật trước khi bắt đầu code.*
