# ChiaHoaDon — App chia hóa đơn nhóm

App Android chia tiền hóa đơn cho nhóm bạn, **hoạt động hoàn toàn offline**:
không server, không tài khoản, không quyền truy cập mạng trong bản phát hành.

- [SPEC.md](./SPEC.md) — đặc tả chức năng (FR-1 → FR-9), thuật toán chia tiền, NFR
- [PLAN.md](./PLAN.md) — kiến trúc, lược đồ DB, màn hình, lộ trình 18 phase, nhật ký triển khai

## Trạng thái — v1.3 đã xong

| Phase | Nội dung | Trạng thái |
|-------|----------|-----------|
| 0 | Khởi tạo, theme, tiện ích định dạng | ✅ Xong |
| 1 | Tầng dữ liệu: SQLite, model, DAO, repository | ✅ Xong |
| 2 | ★ Split engine + test (coverage 98,0%) | ✅ Xong |
| 3 | Màn hình thành viên & nhóm | ✅ Xong |
| 4 | Hóa đơn + chia đều | ✅ Xong |
| 5 | Chia theo món | ✅ Xong |
| 6 | Phụ phí, chia theo %, theo số phần, theo số tiền chỉ định | ✅ Xong |
| 7 | Thanh toán & quyết toán nợ | ✅ Xong |
| 8 | Thống kê theo thành viên, tháng, danh mục | ✅ Xong |
| 9 | Chia sẻ, sao lưu JSON, cài đặt | ✅ Xong |
| 10 | Hoàn thiện & phát hành | ✅ Xong |
| 11 | VietQR · khóa ứng dụng · xuất CSV | ✅ Xong |
| 12 | Món có sẵn · báo cáo tuần · tên hóa đơn từ danh mục | ✅ Xong |
| 13 | Sửa logic chia theo món: giá × số người | ✅ Xong |
| 14 | Báo cáo chi phí từng người theo danh mục · ẩn bớt thành viên | ✅ Xong |
| 15 | Chia sẻ báo cáo lên Mattermost (qua bảng chia sẻ) | ✅ Xong |
| 16 | Chia theo món mặc định + chọn món có sẵn không bật bàn phím | ✅ Xong |
| 17 | Mã QR nhận tiền trong ảnh chia sẻ hóa đơn | ✅ Xong |
| 18 | Mã QR nhận tiền trong ảnh báo cáo theo danh mục | ✅ Xong |

**507 test trên máy tính + 6 test trên thiết bị, tất cả xanh.**
`flutter analyze` không còn cảnh báo nào.

| Chỉ số | Giá trị | Ngưỡng |
|--------|---------|--------|
| APK release arm64 | 20,1 MB | ≤ 30 MB (NFR-5) |
| Quyền truy cập mạng | không có | NFR-1 |
| Tải một trang 50 hóa đơn trong 1.000 hóa đơn | < 500 ms | NFR-3 |
| `computeSplit` 20 người × 30 món | < 16 ms | NFR-4 |

### Còn phải làm tay trước khi phát hành

- **Đối chiếu danh sách mã BIN ngân hàng với bảng NAPAS công bố** — mã sai thì
  QR trỏ sang ngân hàng khác (PLAN 13.17)
- Cài lên **điện thoại thật** (mới chỉ chạy trên emulator x86_64)
- Quét thử QR bằng app ngân hàng thật, mở thử tệp CSV bằng Excel tiếng Việt
- Thử chia sẻ text sang Zalo (§8.3 bước 8 — không tự động hóa được)
- **Gửi thử báo cáo lên Mattermost thật** — emulator chưa cài Mattermost nên mới
  kiểm tới bước bảng chia sẻ bật lên; còn phải xem bảng markdown render thế nào
- Ký APK bằng khóa phát hành, hiện đang dùng khóa debug mặc định

## Yêu cầu môi trường

- Flutter 3.47+ / Dart 3.13+
- Android SDK (API 23+), Java 17
- Không cần mạng để chạy app; chỉ cần mạng khi `flutter pub get`

## Lệnh thường dùng

```bash
flutter pub get
flutter analyze                  # phải sạch 0 issue
flutter test                     # 507 test, chạy trên máy tính, không cần emulator
flutter test test/domain/split/  # chỉ split engine — chạy trong khoảng 1 giây
flutter test --coverage          # sinh coverage/lcov.info
flutter run                      # cần thiết bị hoặc emulator
flutter build apk --release --split-per-abi

# Smoke test §8.3 trên thiết bị hoặc emulator
flutter test integration_test/smoke_test.dart -d <thiết bị>

# Sinh lại icon và màn hình chờ sau khi sửa tool/generate_icon.dart
dart run tool/generate_icon.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# Soi một vùng ảnh chụp màn hình: cắt rồi phóng to (x, y, rộng, cao)
adb exec-out screencap -p > shot.png
dart run tool/crop.dart shot.png 40 1380 1000 440 crop.png
```

## Hai nguyên tắc không được phá

**1. Tiền luôn là `int`, đơn vị đồng.** Không có `double` nào trong đường tính
tiền. Phần trăm lưu dạng basis point (`8%` → `800`). Lý do: `double` sai một
đồng là tổng các phần không còn khớp tổng hóa đơn, và người dùng mất niềm tin
vào app.

**2. `tổng các phần == tổng hóa đơn`, tuyệt đối.** `BillRepository.validate()`
chặn mọi hóa đơn vi phạm trước khi ghi xuống DB. Thuật toán bảo đảm điều này là
Largest Remainder (Hamilton), đặc tả ở [SPEC.md §FR-5](./SPEC.md).

## Cấu trúc

```
lib/
  core/        theme, tiện ích định dạng, widget dùng chung
  domain/      model bất biến + split engine  ← Dart thuần, 0 import Flutter
  data/        schema SQLite, DAO, repository, Riverpod provider
  features/    màn hình theo tính năng
  services/    chia sẻ, sao lưu, ảnh, khóa app, xuất CSV
test/
  core/        bộ định dạng, bỏ dấu tiếng Việt
  data/        DB in-memory qua sqflite_common_ffi, migration, hiệu năng
  domain/      split engine, quyết toán nợ
  widget/      luồng màn hình, bố cục 360dp · nền tối · cỡ chữ lớn
integration_test/
  smoke_test   §8.3 chạy trên thiết bị thật
tool/
  generate_icon.dart   sinh icon và ảnh splash từ màu seed của theme
  crop.dart            cắt và phóng to một vùng ảnh chụp màn hình
```

Quy tắc phụ thuộc: `features → domain ← data`. Thư mục `domain/` không được
import gì từ hai thư mục kia — đó là điều kiện để test split engine mà không
cần emulator.
