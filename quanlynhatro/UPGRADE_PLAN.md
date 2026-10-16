# UPGRADE PLAN: Multi-Location Support

## Yêu cầu đã xác nhận
- **UX chuyển địa điểm**: Dropdown/Chip ở đầu mỗi màn hình (không cần thoát)
- **Settings**: Mỗi địa điểm có cài đặt độc lập (tên, chủ nhà, ngân hàng, giá điện/nước, QR)
- **Báo cáo**: 2 tab — "Tổng hợp" (cộng tất cả) + "Từng địa điểm" (có dropdown chọn)

---

## Phân tích hiện trạng

### Vấn đề cốt lõi
- `rooms` table không có `location_id` — toàn bộ phòng thuộc một "nhà" duy nhất
- `settings` table lưu thông tin tòa nhà dưới dạng key-value toàn cục (không thể nhân bản)
- `AppState.settings` là `Map<String, String>` đọc từ settings table — tất cả màn hình phụ thuộc vào map này

### Files cần thay đổi
| File | Loại thay đổi |
|------|---------------|
| `database/database_helper.dart` | Migration v1→v2, thêm bảng `locations`, thêm cột `location_id` vào `rooms` |
| `models/room.dart` | Thêm field `locationId` |
| `models/invoice.dart` | Không đổi schema, chỉ lọc qua room |
| `providers/app_state.dart` | Thêm `locations`, `currentLocation`, `switchLocation()` |
| `repositories/room_repository.dart` | Thêm filter theo `locationId` |
| `repositories/invoice_repository.dart` | Thêm filter theo danh sách room ID |
| `screens/home/home_screen.dart` | Thêm LocationSelector, lọc phòng/hóa đơn theo location |
| `screens/rooms/rooms_screen.dart` | Thêm LocationSelector |
| `screens/invoices/invoices_screen.dart` | Thêm LocationSelector |
| `screens/invoices/invoice_create_screen.dart` | Dùng settings từ `currentLocation` |
| `screens/invoices/invoice_detail_screen.dart` | Dùng settings từ location của phòng đó |
| `screens/meter/meter_reading_screen.dart` | Lọc phòng theo currentLocation |
| `screens/reports/reports_screen.dart` | Thêm 2 tab: Tổng hợp + Từng địa điểm |
| `screens/settings/settings_screen.dart` | Chuyển sang quản lý settings theo từng location |
| `config/constants.dart` | Thêm constants cho locations |

### Files cần tạo mới
| File | Mục đích |
|------|----------|
| `models/location.dart` | Model Location |
| `repositories/location_repository.dart` | CRUD cho locations |
| `widgets/location_selector.dart` | Dropdown widget dùng chung ở nhiều màn hình |
| `screens/locations/location_form_screen.dart` | Form thêm/sửa địa điểm |

---

## Database Schema Changes

### Bảng mới: `locations`
```sql
CREATE TABLE locations (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  address         TEXT,
  owner_name      TEXT,
  owner_phone     TEXT,
  bank_name       TEXT,
  bank_account    TEXT,
  bank_holder     TEXT,
  transfer_template TEXT,
  elec_price      INTEGER DEFAULT 3500,
  water_price     INTEGER DEFAULT 32000,
  invoice_footer  TEXT,
  qr_image_path   TEXT,   -- đường dẫn tới file ảnh QR (null = dùng QR mặc định)
  sort_order      INTEGER DEFAULT 0,
  created_at      TEXT
)
```

### Thay đổi bảng `rooms`
```sql
ALTER TABLE rooms ADD COLUMN location_id INTEGER NOT NULL DEFAULT 1 REFERENCES locations(id)
```

### Migration Strategy (v1 → v2)
1. Tạo bảng `locations`
2. Insert 1 location đầu tiên: đọc từ `settings` table hiện tại (building_name, owner_name, bank_account, elec_price, v.v.)
3. `ALTER TABLE rooms ADD COLUMN location_id INTEGER NOT NULL DEFAULT 1` — toàn bộ phòng cũ tự động gán location 1
4. `dbVersion` nâng từ 1 → 2

> **Dữ liệu hiện tại an toàn**: Không xóa, chỉ thêm. Toàn bộ phòng/khách/hóa đơn được giữ nguyên và gán cho location mặc định.

---

## Kiến trúc mới

### `Location` model
```dart
class Location {
  final int? id;
  final String name;
  final String? address;
  final String? ownerName;
  final String? ownerPhone;
  final String? bankName;
  final String? bankAccount;
  final String? bankHolder;
  final String? transferTemplate;
  final int elecPrice;
  final int waterPrice;
  final String? invoiceFooter;
  final String? qrImagePath;    // null → dùng assets/images/qr.png
  final int sortOrder;
}
```

### `AppState` mới
```dart
class AppState extends ChangeNotifier {
  List<Location> locations = [];
  int _currentLocationId = -1;    // -1 = chưa load
  
  Location? get currentLocation =>
    locations.where((l) => l.id == _currentLocationId).firstOrNull;

  Future<void> switchLocation(int id) async {
    _currentLocationId = id;
    await reloadRooms();           // load phòng theo location mới
    notifyListeners();
  }

  // rooms đã được lọc theo currentLocation
  // invoicesOfMonth cũng chỉ lấy hóa đơn của phòng trong currentLocation
}
```

### `LocationSelector` widget (dùng lại ở nhiều màn hình)
```
┌─────────────────────────────────────────┐
│  Trang chủ          [37 Đại Linh ▼]     │
│                                         │
│  (dropdown mở ra):                      │
│   ✓ 37 Đại Linh                         │
│     15 Cầu Giấy                         │
│     ─────────────                       │
│   + Thêm địa điểm                       │
└─────────────────────────────────────────┘
```

---

## Chi tiết từng bước thực hiện

### Bước 1 — Database & Migration
**File**: `database/database_helper.dart`
- Nâng `dbVersion = 2`
- Thêm `onUpgrade` callback: migrate từ v1 → v2
- Thêm SQL tạo bảng `locations` vào `_createSchema`
- Thêm `location_id` vào bảng `rooms` trong `_createSchema`

**File**: `database/seed_data.dart`
- Thêm seed location mặc định ("37 Đại Linh") nếu bảng `locations` trống

---

### Bước 2 — Model & Repository
**File mới**: `models/location.dart`
- Model đầy đủ với `toMap()`, `fromMap()`, `copyWith()`

**File**: `models/room.dart`
- Thêm `final int locationId;`
- Cập nhật `toMap()`, `fromMap()`, `copyWith()`

**File mới**: `repositories/location_repository.dart`
- `getAll()` → `List<Location>`
- `getById(int id)` → `Location?`
- `insert(Location)` → `int`
- `update(Location)` → `int`
- `delete(int id)` → xóa location (chỉ cho phép nếu không còn phòng nào)

**File**: `repositories/room_repository.dart`
- Đổi `getAll()` → `getAll({int? locationId})` — lọc theo location nếu có
- Thêm `getByLocation(int locationId)` → dùng trong bước filter invoices

**File**: `repositories/invoice_repository.dart`
- Thêm `getByMonthAndRooms(int month, int year, List<int> roomIds)` — dùng khi cần lọc theo location
- Giữ nguyên `getByMonth` cho báo cáo tổng hợp

---

### Bước 3 — AppState
**File**: `providers/app_state.dart`
- Thêm `LocationRepository _locationRepo`
- Thêm `List<Location> locations`, `int _currentLocationId`
- `loadAll()`: load locations trước, set `_currentLocationId = locations.first.id`, rồi load rooms theo location đó
- Thêm `Future<void> switchLocation(int id)`
- Thêm `Future<void> reloadLocations()`
- Đổi `invoicesOfMonth(month, year)`: lọc chỉ theo rooms của currentLocation

---

### Bước 4 — LocationSelector Widget
**File mới**: `widgets/location_selector.dart`
- `StatelessWidget` nhận `locations`, `currentId`, `onChanged`, `onAddNew`
- UI: PopupMenuButton hiển thị tên location hiện tại + icon arrow_drop_down
- Menu item cho mỗi location + Divider + "Thêm địa điểm"

---

### Bước 5 — Location Form Screen
**File mới**: `screens/locations/location_form_screen.dart`
- Form: Tên địa điểm (*), Địa chỉ, Tên chủ nhà, SĐT, Ngân hàng, STK, Chủ TK, Mẫu CK, Giá điện, Giá nước, Ghi chú HĐ
- Nút "Chọn ảnh QR" (dùng `file_picker`) → preview ảnh đã chọn
- Mode thêm mới + mode chỉnh sửa
- Nút "Xóa địa điểm" (chỉ hiện khi sửa, disabled nếu còn phòng)

---

### Bước 6 — Cập nhật màn hình hiện có

#### `home_screen.dart`
- AppBar actions: thêm `LocationSelector` (thay thế tên tòa nhà cứng)
- `_loadMonth()`: dùng `app.invoicesOfMonth(month, year)` — đã lọc theo location tự động qua AppState
- Room grid: `app.rooms` đã lọc theo location
- Header gradient: hiển thị `app.currentLocation?.name`

#### `rooms_screen.dart`
- AppBar: thêm `LocationSelector`
- Danh sách phòng từ `app.rooms` (đã lọc)
- Nút thêm phòng: truyền `locationId = app.currentLocationId` vào `RoomFormScreen`

#### `invoices_screen.dart`
- AppBar: thêm `LocationSelector`
- Query hóa đơn: dùng `app.invoicesOfMonth` (đã lọc)

#### `meter_reading_screen.dart`
- Nhận `locationId` từ caller hoặc đọc từ AppState
- Filter rooms hiển thị theo location

#### `invoice_create_screen.dart`
- Đọc giá điện/nước từ `currentLocation.elecPrice` thay vì `settings[keyElecPrice]`

#### `invoice_detail_screen.dart`
- Đọc thông tin thanh toán từ location của phòng đó:
  ```dart
  final location = await app.locationRepo.getById(room.locationId);
  ```
- QR: nếu `location.qrImagePath != null` → load từ file, else → `Image.asset('assets/images/qr.png')`

#### `settings_screen.dart`
- **Đổi hoàn toàn**: Thay vì settings global, hiển thị danh sách locations
- Mỗi location row → tap → mở `LocationFormScreen`
- Giữ lại section "Sao lưu & Khôi phục"
- Giữ lại settings toàn cục không phụ thuộc location (nếu có)

---

### Bước 7 — Báo cáo 2 tab
**File**: `screens/reports/reports_screen.dart`
- Thêm `TabBar` với 2 tab: "Tổng hợp" và "Theo địa điểm"
- **Tab Tổng hợp**: query tất cả invoices (không lọc location) → aggregate toàn bộ
- **Tab Theo địa điểm**: có `LocationSelector` ở đầu, hiển thị report chỉ cho location đang chọn, bảng chi tiết theo phòng

---

## Thứ tự thực hiện (giảm rủi ro)

```
B1: DB schema + migration          (nền tảng, không ảnh hưởng UI)
B2: Model Location + Room update   (model-only, chưa có UI)
B3: Location + Room repositories   (data layer)
B4: AppState refactor              (state layer)
B5: LocationSelector widget        (UI component tái sử dụng)
B6: LocationFormScreen             (CRUD địa điểm)
B7: Cập nhật SettingsScreen        (thay settings global → per-location)
B8: Cập nhật HomeScreen            (màn hình chính)
B9: Cập nhật RoomsScreen, InvoicesScreen, MeterReadingScreen
B10: Cập nhật InvoiceCreateScreen, InvoiceDetailScreen
B11: Reports 2-tab
B12: Test end-to-end + build APK
```

---

## Điểm cần chú ý khi thực hiện

1. **DB migration an toàn**: `ALTER TABLE rooms ADD COLUMN location_id DEFAULT 1` — phòng cũ tự nhận location 1, không mất dữ liệu.
2. **QR per location**: Nếu `qrImagePath` null → fallback sang asset mặc định. Ảnh QR lưu vào `getApplicationDocumentsDirectory()`.
3. **Xóa location**: Phải check không còn phòng nào → báo lỗi rõ ràng, không cho xóa.
4. **Thứ tự trong dropdown**: Sắp xếp theo `sort_order`, fallback theo `name`.
5. **InvoiceCreateScreen**: Room picker hiển thị phòng thuộc location hiện tại (không hiện phòng từ location khác).
6. **Hiệu năng**: Không thay đổi architecture cốt lõi, chỉ thêm filter — hiệu năng không bị ảnh hưởng với quy mô vài chục phòng.

---

## Ước lượng

| Phase | Số files thay đổi | Độ phức tạp |
|-------|-------------------|-------------|
| DB + Models | 4 | Thấp |
| Repositories + AppState | 4 | Trung bình |
| Widgets mới | 2 | Trung bình |
| Cập nhật screens | 8 | Cao |
| Reports 2-tab | 1 | Trung bình |
| **Tổng** | **~19 files** | |
