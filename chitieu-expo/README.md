# 💸 Chi Tiêu App — Expo React Native

## Cài đặt & chạy

### Yêu cầu
- Node.js 18+
- Expo Go app trên điện thoại ([iOS](https://apps.apple.com/app/expo-go/id982107779) / [Android](https://play.google.com/store/apps/details?id=host.exp.exponent))

### Bước 1 — Cài dependencies
```bash
cd chitieu-expo
npm install
```

### Bước 2 — Chạy app
```bash
npx expo start
```

### Bước 3 — Mở trên điện thoại
- Mở app **Expo Go** trên điện thoại
- **Android**: Quét QR code hiện trong terminal
- **iOS**: Quét QR bằng camera mặc định

> Điện thoại và máy tính phải cùng mạng WiFi!

---

## Build APK (Android, không cần internet)

```bash
npm install -g eas-cli
eas login         # đăng ký tại expo.dev
eas build -p android --profile preview
```

Sau khi build xong, tải file `.apk` về cài thẳng lên điện thoại.

## Build IPA (iOS)
Cần tài khoản Apple Developer ($99/năm).

---

## Cấu trúc project

```
App.js                    ← Navigator gốc
src/
  constants/index.js      ← Màu sắc, danh mục, ngân hàng
  storage/
    index.js              ← AsyncStorage helpers
    AppContext.js         ← Global state (Context API)
  components/index.js     ← Shared UI components
  screens/
    HomeScreen.js         ← Tổng quan
    AddExpenseScreen.js   ← Thêm chi tiêu
    AddIncomeScreen.js    ← Nhập tiền
    BankScreen.js         ← Tiền gửi ngân hàng
    LoansScreen.js        ← Cho vay
    StatsScreen.js        ← Thống kê / Báo cáo tháng
    BudgetScreen.js       ← Đặt ngân sách
```

## Lưu trữ dữ liệu
Dùng **AsyncStorage** — lưu local trên thiết bị, không cần internet, không đồng bộ đám mây.
