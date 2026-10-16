# Quản Lý Nhà Trọ (Flutter)

App mobile quản lý nhà trọ chạy hoàn toàn local (SQLite) - không cần internet, không cần server.

Được sinh từ prompt `app_quanlynhatro_prompt.md` dựa trên dữ liệu thực tế của tòa nhà 37 Đại Linh.

## Tính năng

- **Trang chủ:** Dashboard tổng quan, lưới phòng theo trạng thái, cảnh báo HĐ sắp/đã hết hạn
- **Phòng:** CRUD phòng + cấu hình phí dịch vụ (mạng, thang máy, máy giặt)
- **Khách thuê:** Quản lý khách hiện tại, gọi điện/SMS, đánh dấu trả phòng
- **Hóa đơn:** Tạo theo tháng, nhập chỉ số điện/nước → tự tính, gợi ý số cũ từ HĐ tháng trước
- **Xuất PDF:** Hóa đơn xuất PDF đẹp, share qua Zalo/Messenger/...
- **Báo cáo:** Tổng thu tháng, cơ cấu doanh thu, bảng chi tiết theo phòng
- **Cài đặt:** Đơn giá điện/nước, thông tin tòa nhà & ngân hàng, backup DB, reset

## Cấu trúc dự án

```
lib/
├── main.dart                    # Entry, init DB & seed
├── config/                      # Theme & constants
├── models/                      # Room, Tenant, Invoice
├── database/                    # DatabaseHelper + SeedData
├── repositories/                # Data access layer
├── providers/                   # AppState (ChangeNotifier)
├── screens/
│   ├── home/                    # Dashboard
│   ├── rooms/                   # CRUD phòng
│   ├── tenants/                 # Form khách
│   ├── invoices/                # List + Create + Detail
│   ├── reports/                 # Báo cáo tháng
│   └── settings/                # Cài đặt + backup
├── services/
│   └── pdf_service.dart         # Xuất PDF hóa đơn
├── widgets/                     # RoomCard...
└── utils/                       # Format VND/date
```

## Lưu trữ dữ liệu

- **SQLite** (`sqflite`) lưu tại `ApplicationDocuments/quanlynhatro.db`
- **Backup:** Settings → "Xuất file backup" → share file `.db` ra Drive/Email
- **PDF hóa đơn:** lưu tại `ApplicationDocuments/invoices/`

## Chạy app

### Yêu cầu
- Flutter SDK >= 3.19
- Android Studio (cho Android) hoặc thiết bị Android (USB debug)

### Lệnh chạy
```bash
flutter pub get
flutter run                # chạy trên device/emulator
flutter build apk --release # build APK release
```

### Kết quả build
- Debug APK: `build\app\outputs\flutter-apk\app-debug.apk`
- Release APK: `build\app\outputs\flutter-apk\app-release.apk`

## Dữ liệu mẫu

Lần đầu chạy app sẽ tự seed 10 phòng tòa nhà 37 Đại Linh (P101→P601) cùng khách thuê (lấy từ file Excel `thue_nha_2026_04.xlsx`).

Đơn giá mặc định: Điện 3,500đ/kWh - Nước 32,000đ/m³ (chỉnh trong Settings).

## Ghi chú

- App khởi tạo PDF với font Roboto (Google Fonts) - lần đầu chạy cần internet 1 lần để cache font; sau đó offline được.
- Trên Windows desktop, sqflite tự dùng FFI nhờ `sqflite_common_ffi`.
- Để chạy trên iOS cần thêm: `flutter create --platforms ios .`
