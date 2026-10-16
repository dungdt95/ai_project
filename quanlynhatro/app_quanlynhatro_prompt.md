# Prompt tạo Mobile App Quản Lý Nhà Trọ

## 1. Bối cảnh & Phân tích dữ liệu thực tế

### Nguồn dữ liệu phân tích
File Excel `thue_nha_2026_04.xlsx` đang quản lý **tòa nhà 37 Đại Linh**, gồm **10 phòng** trải từ tầng 1–6.

### Thông tin chủ nhà
- **Chủ:** Cô Huyền (Đào Thúy Linh)
- **Zalo/Phone:** 0975485428
- **Tài khoản ngân hàng:** STK 658746 – Ngân hàng ACB
- **Nội dung CK mẫu:** "Phòng [XXX] nhà 37 Đại Linh"

### Danh sách phòng hiện tại (tháng 05/2026)

| STT | Phòng | Tên thuê | SĐT | Ngày ký HĐ | Ngày hết HĐ | Tiền phòng | Mạng | Thang máy/VS | Máy giặt | Tổng thu |
|-----|-------|----------|-----|------------|-------------|------------|------|--------------|----------|----------|
| 1 | 101 | Thủy | 0327337638 | 28/12/2025 | 28/02/2026 | 2,800,000 | 100,000 | 60,000 | 50,000 | 3,548,000 |
| 2 | 201 | Niên | 0966506007 | 28/12/2025 | 28/06/2026 | 3,300,000 | 100,000 | 200,000 | 100,000 | 4,413,500 |
| 3 | 202 | Huyền | 0358556572 | 26/12/2025 | 26/12/2026 | 3,200,000 | 100,000 | 300,000 | 150,000 | 4,784,000 |
| 4 | 301 | Vũ | 0982196305 | 28/12/2025 | 28/12/2026 | 3,300,000 | 100,000 | 300,000 | – | 4,193,500 |
| 5 | 302 | Hằng | 0348530871 | 26/12/2025 | 26/12/2026 | 2,800,000 | 100,000 | 200,000 | – | 4,074,500 |
| 6 | 401 | Chi | 0966381640 | 26/12/2025 | 01/08/2026 | 3,300,000 | 100,000 | 100,000 | 50,000 | 4,301,500 |
| 7 | 402 | Công | 0981352489 | 06/01/2026 | 06/01/2027 | 3,000,000 | – | 200,000 | – | 4,225,500 |
| 8 | 501 | Mai | 0968046691 | 26/12/2025 | 26/06/2026 | 3,200,000 | 100,000 | 200,000 | – | 4,587,500 |
| 9 | 502 | Ngọc Anh | 0915954773 | 01/03/2026 | 01/09/2026 | 3,200,000 | – | 200,000 | 100,000 | 4,558,500 |
| 10 | 601 | Chúc | 0398610020 | 01/04/2026 | 01/10/2026 | 3,200,000 | 100,000 | 200,000 | 100,000 | 4,691,500 |

**Tổng thu tháng:** ~43,378,000 VND

### Cấu trúc hóa đơn 1 phòng (từ dữ liệu Excel)
```
NỘI DUNG           | SỐ CŨ | SỐ MỚI | SỐ DÙNG | ĐƠN GIÁ  | THÀNH TIỀN
Tiền phòng         |       |        |         |          | (cố định)
Mạng internet      |       |        |         |          | (cố định, tùy phòng)
Thang máy, vệ sinh |       |        |         |          | (cố định, tùy phòng)
Máy giặt           |       |        |         |          | (cố định, tùy phòng)
Điện sinh hoạt     | xxxx  | xxxx   | =mới-cũ | 3,500đ   | = số dùng × 3,500
Nước sinh hoạt     | xxx   | xxx    | =mới-cũ | 32,000đ  | = số dùng × 32,000
TỔNG CỘNG          |       |        |         |          | tổng các khoản
```

---

## 2. Đề xuất công nghệ & lưu trữ dữ liệu

### Tech Stack đề xuất
- **Framework:** Flutter (chạy được trên Android & iOS từ 1 codebase)
- **Ngôn ngữ:** Dart

### Lưu trữ dữ liệu (local hoàn toàn)
**Đề xuất: SQLite (`sqflite`) + Export file**

| Phương án | Ưu điểm | Nhược điểm | Phù hợp |
|-----------|---------|------------|---------|
| **SQLite (sqflite)** | Nhanh, query linh hoạt, backup dễ | Cần viết schema | Tốt nhất cho app này |
| JSON file | Đơn giản, portable | Chậm khi data lớn | Phù hợp nếu ít phòng |
| Hive / Isar | NoSQL, rất nhanh | Ít linh hoạt với report | Phù hợp nếu ưu tiên tốc độ |

**Lý do chọn SQLite:**
- Dữ liệu có quan hệ rõ ràng (phòng → khách → hóa đơn hàng tháng)
- Dễ query tổng hợp, báo cáo
- Backup bằng cách copy file `.db`
- Export ra Excel/PDF khi cần

### Export dữ liệu
- Export hóa đơn → **PDF** (gửi qua Zalo, lưu máy)
- Export tổng hợp tháng → **Excel (.xlsx)**
- Backup toàn bộ DB → file `.db` lưu vào bộ nhớ máy

---

## 3. Các chức năng chính của App

---

### MODULE 1: Quản lý Phòng

**Mục tiêu:** Xem tổng quan tất cả phòng, trạng thái, thông tin cơ bản.

**Màn hình danh sách phòng:**
- Hiển thị dạng grid/list các phòng (101, 201, 202, 301, 302, 401, 402, 501, 502, 601)
- Màu sắc theo trạng thái: Xanh = đang thuê, Đỏ = trống, Vàng = sắp hết HĐ
- Mỗi card phòng hiển thị: số phòng, tên khách, giá thuê, ngày hết HĐ

**Màn hình chi tiết phòng:**
- Thông tin phòng: số phòng, tầng, diện tích (nếu có)
- Thông tin khách hiện tại
- Các dịch vụ đã đăng ký (mạng, thang máy, máy giặt)
- Lịch sử hóa đơn các tháng trước
- Nút tạo hóa đơn tháng mới

**CRUD phòng:**
- Thêm phòng mới (khi xây thêm)
- Sửa thông tin phòng
- Đánh dấu phòng trống (khi khách trả phòng)

---

### MODULE 2: Quản lý Khách thuê

**Mục tiêu:** Lưu thông tin người thuê, hợp đồng, lịch sử.

**Thông tin khách thuê:**
- Họ tên
- Số điện thoại (nhấn để gọi / nhắn tin Zalo)
- CCCD/CMND (tùy chọn)
- Ảnh CCCD/CMND (tùy chọn)
- Ngày ký hợp đồng
- Ngày hết hợp đồng
- Tiền cọc (nếu có)
- Ghi chú

**Cảnh báo hợp đồng:**
- Thông báo khi HĐ còn <= 30 ngày
- Thông báo khi HĐ đã hết hạn (như P101 - Thủy: HĐ hết 28/02/2026)
- Badge đỏ trên icon phòng tương ứng

**Lịch sử:**
- Xem danh sách các khách đã từng ở phòng đó
- Ngày vào – ngày ra

---

### MODULE 3: Quản lý Hóa đơn hàng tháng

**Mục tiêu:** Nhập số điện/nước → tự động tính toán → tạo hóa đơn.

**Tạo hóa đơn tháng mới:**

Bước 1 – Chọn tháng/năm (mặc định tháng hiện tại)

Bước 2 – Nhập chỉ số theo từng phòng:
```
Phòng [XXX] - [Tên khách]
├── Điện: Số cũ [____] | Số mới [____] → Số dùng: [tự tính] | Thành tiền: [tự tính × 3,500]
├── Nước: Số cũ [____] | Số mới [____] → Số dùng: [tự tính] | Thành tiền: [tự tính × 32,000]
├── Tiền phòng: [____] (lấy từ cấu hình phòng)
├── Mạng internet: [ON/OFF] [____] đ
├── Thang máy, vệ sinh: [____] đ
└── Máy giặt: [ON/OFF] [____] đ
```

Bước 3 – Xem tổng hóa đơn → Lưu

**Tự động tính:**
- Tiền điện = (Số mới - Số cũ) × đơn giá điện
- Tiền nước = (Số mới - Số cũ) × đơn giá nước
- Tổng cộng = Tiền phòng + Mạng + Thang máy + Máy giặt + Tiền điện + Tiền nước

**Validation:**
- Không cho nhập số mới < số cũ
- Cảnh báo nếu số điện tăng bất thường (> X kWh, cấu hình được ngưỡng)

---

### MODULE 4: Xuất & Chia sẻ Hóa đơn

**Mục tiêu:** Tạo hóa đơn đẹp, gửi cho khách qua Zalo.

**Xem trước hóa đơn:**
Hiển thị đúng format như Excel hiện tại:
```
═══════════════════════════════════
       HÓA ĐƠN TIỀN NHÀ
         THÁNG 05 NĂM 2026
═══════════════════════════════════
Bên A (Cho thuê): Cô Huyền
Bên B (Người thuê): Phòng 101 - Thủy

NỘI DUNG          | SỐ CŨ | SỐ MỚI | SỐ DÙNG | ĐƠN GIÁ | THÀNH TIỀN
Tiền phòng        |       |        |         |         | 2,800,000
Mạng internet     |       |        |         |         |   100,000
Thang máy, VS     |       |        |         |         |    60,000
Máy giặt          |       |        |         |         |    50,000
Điện sinh hoạt    | 5799  |  5907  |   108   |  3,500  |   378,000
Nước sinh hoạt    |  401  |   406  |     5   | 32,000  |   160,000
──────────────────────────────────────────────────────────────────
TỔNG CỘNG                                              | 3,548,000

Thanh toán: STK 658746 – ACB
Nội dung: "Phòng 101 nhà 37 Đại Linh"
Gửi bill: Zalo 0975485428
═══════════════════════════════════
```

**Xuất hóa đơn:**
- Xuất PDF → lưu vào Downloads
- Chụp ảnh màn hình hóa đơn → lưu vào Gallery
- Chia sẻ qua Zalo / WhatsApp / Messenger

**Gửi hàng loạt (batch):**
- Tạo hóa đơn tất cả phòng cùng lúc
- Xuất tất cả thành file ZIP hoặc từng PDF riêng

---

### MODULE 5: Tổng hợp & Báo cáo

**Mục tiêu:** Xem tổng quan doanh thu, theo dõi thu chi.

**Màn hình Tổng hợp tháng:**
- Tổng thu tháng hiện tại (dạng số lớn nổi bật)
- Doanh thu từng phòng (bar chart hoặc list)
- So sánh với tháng trước
- Tổng tiền điện / nước / dịch vụ

**Bảng tổng hợp (như sheet "Tổng" trong Excel):**
```
Tháng 05/2026 | Điện 3,500/kWh | Nước 32,000/khối
──────────────────────────────────────────────────────────
STT | Phòng | Tên   | Tiền phòng | Điện   | Nước   | Tổng
 1  |  101  | Thủy  | 2,800,000  | 378,000| 160,000|3,548,000
...
──────────────────────────────────────────────────────────
    |       | TỔNG  |31,300,000  |6,496,000|2,272,000|43,378,000
```

**Export báo cáo:**
- Xuất bảng tổng hợp ra Excel (.xlsx)
- In hoặc lưu PDF

---

### MODULE 6: Cài đặt (Settings)

**Thông tin tòa nhà:**
- Tên tòa nhà / địa chỉ: "37 Đại Linh"
- Tên chủ nhà: "Cô Huyền" / "Đào Thúy Linh"
- SĐT/Zalo chủ: 0975485428

**Thông tin thanh toán:**
- Số tài khoản: 658746
- Ngân hàng: ACB
- Tên tài khoản
- Template nội dung CK: "Phòng [PHONG] nhà [DIA_CHI]"

**Đơn giá dịch vụ:**
- Giá điện: 3,500 đ/kWh (chỉnh được)
- Giá nước: 32,000 đ/khối (chỉnh được)

**Thông báo:**
- Nhắc nhở nhập hóa đơn hàng tháng (đặt ngày, ví dụ: ngày 27 hàng tháng)
- Nhắc HĐ sắp hết hạn (trước bao nhiêu ngày)

**Backup & Restore:**
- Export file `.db` backup
- Import file `.db` restore
- Export toàn bộ dữ liệu ra Excel

---

## 4. Cấu trúc Database (SQLite)

```sql
-- Thông tin tòa nhà / cài đặt
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

-- Danh sách phòng
CREATE TABLE rooms (
  id INTEGER PRIMARY KEY,
  room_number TEXT NOT NULL,       -- "101", "201", ...
  floor INTEGER,                    -- tầng
  base_rent INTEGER NOT NULL,       -- giá thuê cơ bản
  has_internet INTEGER DEFAULT 1,   -- có mạng không
  internet_fee INTEGER DEFAULT 100000,
  elevator_fee INTEGER DEFAULT 0,   -- phí thang máy/vệ sinh
  washing_fee INTEGER DEFAULT 0,    -- phí máy giặt
  status TEXT DEFAULT 'occupied',   -- 'occupied' | 'vacant'
  notes TEXT
);

-- Khách thuê
CREATE TABLE tenants (
  id INTEGER PRIMARY KEY,
  room_id INTEGER REFERENCES rooms(id),
  full_name TEXT NOT NULL,
  phone TEXT,
  id_card TEXT,                     -- CCCD
  contract_start DATE,
  contract_end DATE,
  deposit INTEGER DEFAULT 0,
  is_current INTEGER DEFAULT 1,     -- 1 = đang ở, 0 = đã trả phòng
  notes TEXT
);

-- Hóa đơn hàng tháng
CREATE TABLE invoices (
  id INTEGER PRIMARY KEY,
  room_id INTEGER REFERENCES rooms(id),
  tenant_id INTEGER REFERENCES tenants(id),
  month INTEGER NOT NULL,           -- tháng
  year INTEGER NOT NULL,            -- năm
  rent_fee INTEGER,                 -- tiền phòng
  internet_fee INTEGER DEFAULT 0,
  elevator_fee INTEGER DEFAULT 0,
  washing_fee INTEGER DEFAULT 0,
  elec_old INTEGER,                 -- số điện cũ
  elec_new INTEGER,                 -- số điện mới
  elec_used INTEGER,                -- số điện dùng
  elec_unit_price INTEGER DEFAULT 3500,
  elec_fee INTEGER,                 -- tiền điện
  water_old INTEGER,                -- số nước cũ
  water_new INTEGER,                -- số nước mới
  water_used INTEGER,               -- số nước dùng
  water_unit_price INTEGER DEFAULT 32000,
  water_fee INTEGER,                -- tiền nước
  total INTEGER,                    -- tổng cộng
  is_paid INTEGER DEFAULT 0,        -- đã thanh toán chưa
  paid_date DATE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 5. Màn hình và luồng sử dụng (User Flow)

```
App Start
  └── Dashboard (Tổng quan)
        ├── [Tháng hiện tại] Tổng thu: 43,378,000đ
        ├── Grid phòng (10 phòng, màu theo trạng thái)
        ├── Cảnh báo: HĐ sắp hết hạn
        └── Nút "Tạo hóa đơn tháng mới"

Bottom Navigation:
  ├── 🏠 Phòng        → Danh sách phòng → Chi tiết phòng
  ├── 👤 Khách        → Danh sách khách → Chi tiết khách
  ├── 📋 Hóa đơn     → Tạo / Xem / Xuất hóa đơn
  ├── 📊 Báo cáo     → Tổng hợp tháng / Biểu đồ
  └── ⚙️ Cài đặt    → Thông tin, đơn giá, backup
```

---

## 6. Prompt đầy đủ để tạo App

```
Tạo một mobile app Flutter để quản lý nhà trọ với các yêu cầu sau:

### Thông tin tòa nhà
- Tên: Nhà trọ 37 Đại Linh
- Chủ nhà: Cô Huyền (Đào Thúy Linh), SĐT: 0975485428
- Ngân hàng: STK 658746 – ACB
- Gồm 10 phòng: 101, 201, 202, 301, 302, 401, 402, 501, 502, 601

### Yêu cầu kỹ thuật
- Chạy hoàn toàn offline (local), không cần internet
- Lưu trữ: SQLite (package sqflite + path_provider)
- Hỗ trợ export PDF (package pdf + printing) và Excel (package excel)
- Share file qua Zalo/ứng dụng khác (package share_plus)
- Ngôn ngữ giao diện: Tiếng Việt
- Hỗ trợ Android (tối thiểu Android 8+)

### Các màn hình cần có

**1. Dashboard (Trang chủ)**
- Tổng thu tháng hiện tại (nổi bật)
- Grid 10 phòng (màu xanh = đang thuê, đỏ = trống, vàng = HĐ sắp hết)
- Cảnh báo HĐ còn <= 30 ngày
- Nút nhanh "Tạo hóa đơn tháng [X]"

**2. Quản lý Phòng**
- Danh sách tất cả phòng
- Chi tiết phòng: thông tin khách, dịch vụ, lịch sử hóa đơn
- CRUD phòng: thêm/sửa/xóa phòng
- Mỗi phòng có: số phòng, tầng, giá thuê cơ bản, các phí dịch vụ (mạng, thang máy, máy giặt)

**3. Quản lý Khách thuê**
- Thông tin: Tên, SĐT, CCCD, ngày ký HĐ, ngày hết HĐ, tiền cọc
- Lịch sử khách theo từng phòng
- Nhấn SĐT để gọi điện hoặc mở Zalo

**4. Tạo & Quản lý Hóa đơn hàng tháng**
- Chọn tháng/năm
- Nhập chỉ số điện (cũ/mới) → tự tính tiền điện (mặc định 3,500đ/kWh)
- Nhập chỉ số nước (cũ/mới) → tự tính tiền nước (mặc định 32,000đ/khối)
- Tự động điền: tiền phòng, mạng, thang máy, máy giặt từ cấu hình phòng
- Tổng cộng tự động cập nhật

**5. Xuất Hóa đơn**
- Xem trước hóa đơn đúng format:
  - Header: "HÓA ĐƠN TIỀN NHÀ - THÁNG MM NĂM YYYY"
  - Bên A, Bên B
  - Bảng chi tiết: Nội dung | Số cũ | Số mới | Số dùng | Đơn giá | Thành tiền
  - Tổng cộng
  - Thông tin thanh toán (STK, ngân hàng, nội dung CK, Zalo)
  - Phần ghi chú (tùy chỉnh trong Settings)
- Xuất PDF → lưu máy
- Share qua Zalo / ứng dụng khác

**6. Tổng hợp tháng (Báo cáo)**
- Bảng tổng hợp tất cả phòng: giống sheet "Tổng" trong Excel
  - Cột: STT, Phòng, Tên, Tiền phòng, Mạng, Thang máy, Máy giặt, Điện(cũ/mới/số/tiền), Nước(cũ/mới/số/tiền), Tổng thu
  - Dòng tổng cuối bảng
- Tổng doanh thu tháng (số lớn)
- So sánh tháng trước (tăng/giảm %)
- Export bảng tổng hợp ra Excel

**7. Cài đặt**
- Thông tin tòa nhà (tên, địa chỉ, chủ nhà)
- Thông tin thanh toán (STK, ngân hàng, template nội dung CK)
- Đơn giá điện/nước (chỉnh được)
- Lời nhắc: đặt ngày nhắc nhập hóa đơn hàng tháng
- Backup/Restore: export/import file .db, export Excel toàn bộ

### Cấu trúc database SQLite

```
rooms: id, room_number, floor, base_rent, has_internet, internet_fee, elevator_fee, washing_fee, status, notes
tenants: id, room_id, full_name, phone, id_card, contract_start, contract_end, deposit, is_current, notes
invoices: id, room_id, tenant_id, month, year, rent_fee, internet_fee, elevator_fee, washing_fee, elec_old, elec_new, elec_used, elec_unit_price, elec_fee, water_old, water_new, water_used, water_unit_price, water_fee, total, is_paid, paid_date, created_at
settings: key, value
```

### Dữ liệu mẫu cần seed (tháng 05/2026)
- P101 – Thủy – 0327337638 – HĐ 28/12/2025→28/02/2026 – Phòng 2.8tr – Mạng 100k – Thang máy 60k – Giặt 50k
- P201 – Niên – 0966506007 – HĐ 28/12/2025→28/06/2026 – 3.3tr – Mạng 100k – Thang máy 200k – Giặt 100k
- P202 – Huyền – 0358556572 – HĐ 26/12/2025→26/12/2026 – 3.2tr – Mạng 100k – Thang máy 300k – Giặt 150k
- P301 – Vũ – 0982196305 – HĐ 28/12/2025→28/12/2026 – 3.3tr – Mạng 100k – Thang máy 300k
- P302 – Hằng – 0348530871 – HĐ 26/12/2025→26/12/2026 – 2.8tr – Mạng 100k – Thang máy 200k
- P401 – Chi – 0966381640 – HĐ 26/12/2025→01/08/2026 – 3.3tr – Mạng 100k – Thang máy 100k – Giặt 50k
- P402 – Công – 0981352489 – HĐ 06/01/2026→06/01/2027 – 3.0tr – Thang máy 200k (không mạng)
- P501 – Mai – 0968046691 – HĐ 26/12/2025→26/06/2026 – 3.2tr – Mạng 100k – Thang máy 200k
- P502 – Ngọc Anh – 0915954773 – HĐ 01/03/2026→01/09/2026 – 3.2tr – Thang máy 200k – Giặt 100k (không mạng)
- P601 – Chúc – 0398610020 – HĐ 01/04/2026→01/10/2026 – 3.2tr – Mạng 100k – Thang máy 200k – Giặt 100k

### UI/UX yêu cầu
- Material Design 3
- Màu chủ đạo: xanh dương đậm (#1565C0) hoặc xanh lá (#2E7D32)
- Font: Roboto, hỗ trợ tiếng Việt đầy đủ
- Định dạng tiền tệ: dấu chấm phân cách nghìn (VD: 3.548.000đ)
- Định dạng ngày: dd/MM/yyyy

### Thư viện Flutter cần dùng
- sqflite: ^2.3.0
- path_provider: ^2.1.0
- pdf: ^3.10.0
- printing: ^5.12.0
- excel: ^4.0.0
- share_plus: ^7.0.0
- intl: ^0.19.0
- fl_chart: ^0.66.0 (biểu đồ báo cáo)
- provider hoặc riverpod (state management)
```

---

## 7. Thứ tự ưu tiên phát triển

1. **MVP (Phase 1):** Quản lý phòng + Khách thuê + Tạo hóa đơn tháng
2. **Phase 2:** Xuất PDF hóa đơn + Báo cáo tổng hợp tháng
3. **Phase 3:** Cài đặt + Backup/Restore + Cảnh báo HĐ hết hạn
4. **Phase 4:** Biểu đồ doanh thu + Export Excel
