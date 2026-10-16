# Quản lý Thu Chi Cá Nhân

Ứng dụng mobile quản lý thu chi cá nhân, chạy hoàn toàn offline trên Android 14.

## Tính năng
- **Thu/Chi**: Ghi nhận giao dịch theo danh mục, lọc theo tháng
- **Tiền gửi ngân hàng**: Theo dõi sổ tiết kiệm MB/TPBank/Techcombank, nhắc đáo hạn
- **Cho vay**: Quản lý khoản vay nhóm theo người vay, ghi nhận từng lần trả
- **Báo cáo**: Biểu đồ tròn, cột, tổng tài sản
- **Backup/Restore**: Export/import JSON

## Yêu cầu hệ thống
- Android 14 (API 34) / Android 7.0+ (minSdk 24)
- Flutter 3.x, Dart 3.x

## Build
```bash
flutter pub get
flutter run
# hoặc build APK
flutter build apk --release
```

## Cấu trúc
```
lib/
├── main.dart              # Entrypoint
├── app.dart               # MaterialApp + routes + bottom nav
├── core/                  # Constants, utils, widgets dùng chung
├── data/                  # Database, models, repositories
├── services/              # Notification, backup
└── features/              # Home, transactions, deposits, loans, reports, settings
```

## Lưu ý Android 14
- Cần cấp quyền `POST_NOTIFICATIONS` khi mở app lần đầu
- Notification nhắc đáo hạn dùng `USE_EXACT_ALARM` (không cần bật tay)
- Backup lưu trong app-specific storage, chia sẻ qua share sheet
