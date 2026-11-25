# Hướng dẫn: Build & cài Kids English trên iPhone/iPad (không cần máy Mac)

Dành cho chủ app. Phương án đã chọn: **dùng trong gia đình**, **hỗ trợ iPad**, **không có Mac** → build trên Mac cloud (**Codemagic**) và cài qua **TestFlight**.

Phần code/cấu hình iOS đã làm sẵn trong repo. Tài liệu này chỉ gồm các bước **bắt buộc phải làm bằng tay**.

| Thông tin cố định | Giá trị |
|---|---|
| Bundle ID iOS | `com.bevui.kidsenglish` |
| Tên hiển thị | Kids English |
| iOS tối thiểu | 15.0 (iPhone + iPad, chỉ màn hình ngang) |
| File cấu hình CI | `codemagic.yaml` (gốc repo), workflow `kids-english-ios-testflight` |
| File cấu hình Google iOS | `kids_english_app/app/ios/Flutter/GoogleSignIn.xcconfig` |

---

## Bước 1. Đăng ký Apple Developer Program (bắt buộc, 99 USD/năm)

1. Vào https://developer.apple.com/programs/enroll/ (hoặc app **Apple Developer** trên iPhone/iPad – đăng ký trong app thường nhanh hơn).
2. Đăng nhập Apple ID (bật xác thực 2 lớp), chọn loại **Cá nhân (Individual)**.
3. Thanh toán 99 USD. Chờ Apple duyệt (vài giờ đến vài ngày).

> Không có tài khoản này thì không dùng được TestFlight. (Apple ID miễn phí chỉ cài được qua Xcode trên Mac và app hết hạn sau 7 ngày.)

## Bước 2. Tạo app trên Apple

### 2.1. Đăng ký Bundle ID
1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles** → **Identifiers** → **+**.
2. Chọn **App IDs** → **App** → Description: `Kids English`, Bundle ID **Explicit**: `com.bevui.kidsenglish`.
3. Không cần bật thêm Capability nào → **Register**.

### 2.2. Tạo app trong App Store Connect
1. https://appstoreconnect.apple.com → **Apps** → **+** → **New App**.
2. Platform **iOS**, Name: `Kids English` (tên trên App Store là duy nhất toàn cầu; nếu bị trùng, đặt ví dụ `Kids English – Bé Vui`, tên dưới icon trên máy vẫn là "Kids English"), Primary language: Vietnamese, Bundle ID: chọn `com.bevui.kidsenglish`, SKU: `kidsenglish`.

### 2.3. Tạo khoá API App Store Connect (để Codemagic tự ký và đẩy TestFlight)
1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** → **+**.
2. Name: `Codemagic`, Access: **App Manager** → **Generate**.
3. Ghi lại **Issuer ID**, **Key ID**, và **tải file `.p8`** (chỉ tải được **một lần**, cất kỹ, **không** đưa vào Git).

## Bước 3. Google Cloud: OAuth client cho iOS (để đăng nhập Gmail / đồng bộ Drive)

1. https://console.cloud.google.com → đúng project đang dùng cho Android → **APIs & Services → Credentials → Create credentials → OAuth client ID**.
2. Application type: **iOS**, Bundle ID: `com.bevui.kidsenglish` → **Create**.
3. Màn hình kết quả có **Client ID** (dạng `1234-abcd.apps.googleusercontent.com`) và **iOS URL scheme** (dạng `com.googleusercontent.apps.1234-abcd`).
4. Gửi 2 giá trị này cho Claude để điền vào `ios/Flutter/GoogleSignIn.xcconfig`, hoặc tự sửa 2 dòng:
   ```
   GOOGLE_IOS_CLIENT_ID = 1234-abcd.apps.googleusercontent.com
   GOOGLE_IOS_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234-abcd
   ```
   rồi commit + push.
5. Gmail dùng trên iPhone/iPad vẫn phải nằm trong **Test users** của màn hình đồng ý OAuth (giống Android).

> Chưa làm bước 3 thì app iOS vẫn chạy bình thường, chỉ có nút "Đăng nhập Gmail" báo lỗi cấu hình. Vẫn nạp gói bằng file được.

## Bước 4. Thiết lập Codemagic

1. https://codemagic.io → **Sign up with GitHub** → cho phép truy cập repo `dungdt95/ai_project`.
2. **Team settings → Integrations → Developer Portal → Connect**:
   - Name: **`kids_english_asc`** (phải đúng tên này, vì `codemagic.yaml` dùng nó).
   - Nhập Issuer ID, Key ID, tải file `.p8` ở bước 2.3.
3. **Applications → Add application** → chọn repo `dungdt95/ai_project` → loại **Flutter App** → chọn cấu hình bằng **codemagic.yaml**.
4. **Code signing**: với `ios_signing` trong `codemagic.yaml`, Codemagic tự tạo chứng chỉ phân phối và provisioning profile qua khoá API. Nếu được hỏi, chọn **Generate certificate** / cho phép Codemagic tạo.
5. Bấm **Start new build** → chọn nhánh (vd. `feature/kids-english-app` hoặc `main`) → workflow **Kids English iOS → TestFlight**.
6. Build mất khoảng 15–30 phút. Thành công thì bản build tự lên TestFlight; Apple xử lý thêm 5–30 phút.

> Codemagic có gói miễn phí giới hạn số phút build mỗi tháng — đủ cho vài lần build/tháng.

## Bước 5. Mời người trong gia đình dùng TestFlight

**Cách khuyến nghị – Internal Testing (không cần Apple duyệt):**
1. App Store Connect → **Users and Access** → **+** → thêm Apple ID của từng người (vai trò thấp nhất, vd. *Customer Support*). Họ nhận email mời, bấm chấp nhận.
2. **Apps → Kids English → TestFlight → Internal Testing → +** tạo nhóm "Gia đình" → thêm những người trên → bật tự động phân phối bản mới.

**Hoặc External Testing (link công khai, cần Apple duyệt beta ~1 ngày cho bản đầu):** tạo nhóm External, điền thông tin kiểm thử, bật **Public Link** rồi gửi link cho người nhà.

**Trên iPhone/iPad:** cài app **TestFlight** từ App Store → mở lời mời/link → **Install**. Bản TestFlight **hết hạn sau 90 ngày** → build bản mới (bước 4.5) trước hạn.

## Bước 6. Kiểm thử trên máy thật

1. Mở app: chạy màn hình **ngang**, không có thanh trạng thái, icon Momo, tên "Kids English".
2. **Gạt công tắc im lặng** (iPhone) → vào bài học: vẫn nghe giọng đọc và nhạc.
3. Bài nói: bấm micro → iOS hỏi quyền micro → **Cho phép** → nói → nghe lại giọng bé (âm lượng to, phát ra loa ngoài) → Momo khen.
4. Bài hát karaoke, ôn tập (bóng bay, cho Momo ăn) chạy mượt trên iPhone và iPad.
5. Khu phụ huynh → Gói chủ đề:
   - **Chọn file gói từ thiết bị**: chọn được file `.bvpack` trong app **Tệp** (lưu sẵn file vào iCloud Drive/Tệp).
   - **Đăng nhập Gmail** (sau bước 3) → kết nối kho → nạp 20 chủ đề.
6. iPad: bố cục bản đồ đảo, bóng bay, Momo không bị lệch/chồng.
7. Cài đặt iPhone → [Tên] → iCloud → Quản lý dung lượng → Sao lưu: app không chiếm vài chục MB do gói chủ đề.

## Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| Codemagic báo không tìm thấy integration `kids_english_asc` | Đặt tên khác ở bước 4.2 | Đổi tên integration hoặc sửa dòng `app_store_connect:` trong `codemagic.yaml` |
| Lỗi ký ứng dụng / không có profile | Chưa đăng ký Bundle ID (2.1) hoặc khoá API thiếu quyền | Kiểm tra Bundle ID `com.bevui.kidsenglish`, khoá API quyền App Manager |
| Lỗi `pod install` / iOS deployment target | Thư viện yêu cầu iOS cao hơn | Báo Claude; dự án đặt iOS 15.0 |
| Không thấy file `.ipa` trong artifacts | Đường dẫn artifact | Xem log bước "Build IPA", báo Claude chỉnh `codemagic.yaml` |
| TestFlight báo "Missing Compliance" | — | Đã khai báo `ITSAppUsesNonExemptEncryption = NO`; nếu vẫn hỏi, chọn "None of the algorithms mentioned above" |
| Bấm Đăng nhập Gmail báo lỗi cấu hình | Chưa làm bước 3 hoặc sai Client ID/URL scheme | Kiểm tra `GoogleSignIn.xcconfig`, build lại |
| Đăng nhập Google mở trình duyệt nhưng không quay về app | Sai `GOOGLE_IOS_REVERSED_CLIENT_ID` | Dùng đúng "iOS URL scheme" trên Google Cloud |
| Không chọn được file `.bvpack` | iOS chưa nhận kiểu file | Đổi đuôi thành `.zip` để thử, báo Claude |
| Không có tiếng khi gạt im lặng | Audio session | Báo Claude kèm thao tác tái hiện |
