# Báo cáo khảo sát: Làm bản iOS cho app "Kids English"

> Ngày khảo sát: 25/11/2026 · Nhánh: `feature/kids-english-app` (commit `8485037`)
> Phạm vi: những gì cần có và cần làm để app Flutter hiện tại (`kids_english_app/app`) chạy được trên iPhone/iPad và phát hành được.

---

## 0. Quyết định đã chốt & tiến độ (cập nhật 25/11/2026)

| Câu hỏi | Quyết định |
|---|---|
| Máy Mac | **Không có** → build trên Mac cloud bằng **Codemagic** (`codemagic.yaml` ở gốc repo) |
| Mục tiêu | **Dùng trong gia đình** → phân phối qua **TestFlight** (vẫn cần Apple Developer Program 99 USD/năm) |
| iPad | **Có hỗ trợ** (chạy ngang, toàn màn hình) |
| Bundle ID | `com.bevui.kidsenglish` (đề xuất, đổi được) |

**Đã làm trong repo (chưa kiểm chứng được vì chưa build trên Mac):**
- Gỡ `permission_handler`, `audioplayers`, `intl` (không dùng).
- Tạo `ios/`: Bundle ID, tên "Kids English", iOS 15.0, iPhone + iPad, chỉ màn hình ngang, `UIRequiresFullScreen`, ẩn thanh trạng thái.
- `Info.plist`: quyền micro, khai báo kiểu file `.bvpack`, khoá Google Sign-In đọc từ `ios/Flutter/GoogleSignIn.xcconfig`, `ITSAppUsesNonExemptEncryption = NO`.
- Âm thanh: `just_audio` trên iOS mặc định đã dùng chế độ `playback` (vẫn có tiếng khi gạt im lặng); TTS được đặt `playback` riêng cho iOS.
- Đánh dấu thư mục gói chủ đề **không sao lưu iCloud** (kênh native trong `AppDelegate.swift`).
- Icon iOS (không có nền trong suốt).

**Việc anh/chị cần làm:** xem [HUONG_DAN_BUILD_IOS.md](HUONG_DAN_BUILD_IOS.md).

---

## 1. Kết luận nhanh

- **Làm được**, phần lớn code dùng lại nguyên vẹn (Flutter). Không có code Dart nào phụ thuộc riêng Android (không dùng `Platform.isAndroid`).
- **Rào cản lớn nhất không nằm ở code** mà ở môi trường:
  1. **Bắt buộc có máy Mac + Xcode** để build iOS. Máy Windows hiện tại không build được iOS.
  2. **Tài khoản Apple Developer Program** (99 USD/năm) để cài lâu dài lên iPhone, phát qua TestFlight hoặc lên App Store.
- Phần việc code/cấu hình ước tính **2–4 ngày công** (khi đã có Mac), cộng thời gian thiết lập tài khoản, ký ứng dụng và kiểm thử trên máy thật.

---

## 2. Hiện trạng project (đối với iOS)

| Hạng mục | Hiện trạng | Ghi chú |
|---|---|---|
| Thư mục `ios/` | **Chưa có** (project mới chỉ tạo cho Android) | Tạo bằng `flutter create --platforms=ios .` |
| Code Dart | Dùng chung, không có nhánh riêng Android | `SystemUiMode.immersiveSticky` không có tác dụng trên iOS (vô hại) |
| Tên app / package Android | `Kids English` / `com.bevui.be_vui_tieng_anh` | **Bundle ID iOS không được chứa dấu `_`** → cần ID mới, ví dụ `com.bevui.kidsenglish` |
| Icon | Có, sinh bằng `flutter_launcher_icons` (chỉ Android) | Bật thêm `ios: true`, `remove_alpha_ios: true` (icon iOS không được có nền trong suốt) |
| Màn hình | Chỉ chạy **ngang** (landscape) | Cấu hình hướng màn hình trong `Info.plist`; với iPad cần thêm `UIRequiresFullScreen` |
| Chính sách quyền riêng tư | Có `docs/PRIVACY_POLICY.md` | Phải đưa lên một URL công khai khi nộp App Store |

### Plugin đang dùng và yêu cầu iOS

| Plugin | Đang dùng trong code? | iOS tối thiểu | Việc cần làm trên iOS |
|---|---|---|---|
| `google_sign_in` 7.2 (`google_sign_in_ios` 6.4) | Có (Drive) | **15.0** | OAuth client iOS + khai báo trong `Info.plist` (mục 4.1) |
| `record` 7.2 (`record_darwin`) | Có (bài nói) | 12.0 | `NSMicrophoneUsageDescription`; mặc định đã phát ra loa ngoài (`defaultToSpeaker`) |
| `just_audio` 0.10 | Có | 12.0 | Cấu hình audio session để vẫn có tiếng khi gạt công tắc im lặng (mục 4.3); `setPitch` có thể không hỗ trợ trên iOS (code đã bọc `try/catch` → chỉ mất hiệu ứng giọng cao) |
| `flutter_tts` 4.2 | Có (giọng dự phòng) | — | Đặt category `playback` cho TTS (mục 4.3) |
| `file_picker` 13.4 | Có (nạp gói từ máy) | — | Đuôi `.bvpack` là đuôi lạ trên iOS → cần khai báo kiểu file hoặc chỉ dùng `.zip` (mục 4.4) |
| `url_launcher` 6.3 | Có (mở trang Drive xin quyền) | 13.0 | Không cần cấu hình thêm cho link `https` |
| `path_provider`, `hive_ce`, `archive`, `http` | Có | — | Không cần cấu hình |
| `permission_handler` 13 | **Không dùng** | 12.0 | Nên **gỡ khỏi `pubspec.yaml`** (bớt cấu hình Podfile và rủi ro khi duyệt) |
| `audioplayers` 6.8 | **Không dùng** | 13.0 | Nên **gỡ** (bớt một thư viện âm thanh tranh chấp audio session) |
| `intl` | Không dùng | — | Có thể gỡ |

→ **iOS tối thiểu của app: 15.0** (do Google Sign-In). Gần như mọi iPhone/iPad đang dùng đều đáp ứng.

---

## 3. Điều kiện tiên quyết (phần anh/chị phải chuẩn bị)

### 3.1. Máy Mac để build
| Phương án | Ưu | Nhược |
|---|---|---|
| **Mac thật** (Mac mini / MacBook, chip Apple) | Nhanh, có Simulator, cắm iPhone debug trực tiếp | Chi phí mua máy |
| **Thuê Mac đám mây** (MacinCloud, MacStadium…) | Không mua máy | Trả theo giờ/tháng, thao tác qua remote desktop chậm |
| **CI build trên cloud** (Codemagic, GitHub Actions macOS) | Build + ký + đẩy TestFlight tự động từ Windows | Không debug trực tiếp được; cấu hình ký ứng dụng phức tạp hơn; có gói miễn phí nhưng giới hạn số phút build |

Khuyến nghị: **Mac thật (kể cả Mac mini đời cũ chip M1)** cho giai đoạn làm và test; sau này có thể thêm Codemagic để build tự động.

Trên Mac cần: Xcode bản mới nhất, CocoaPods, Flutter SDK cùng phiên bản với máy Windows.

### 3.2. Tài khoản Apple
| Loại | Chi phí | Dùng được gì |
|---|---|---|
| Apple ID miễn phí | 0 | Cài thử lên iPhone của mình qua Xcode, **app hết hạn sau 7 ngày** phải cài lại; không TestFlight, không App Store |
| **Apple Developer Program** | **99 USD/năm** | TestFlight (phát cho người thân/tester), App Store, cài lâu dài |

### 3.3. Thiết bị test
- Ít nhất 1 iPhone thật (micro, loa, công tắc im lặng không thử được trên Simulator).
- Nên có thêm 1 iPad nếu cho phép cài trên iPad.

---

## 4. Các hạng mục kỹ thuật cần làm

### 4.1. Đăng nhập Google & đồng bộ Google Drive
1. **Google Cloud Console** (cùng project đang dùng cho Android): tạo thêm **OAuth client loại iOS** với Bundle ID iOS mới. Web client hiện có (`84168100648-5lo1…`) dùng lại làm `serverClientId`.
2. `ios/Runner/Info.plist` thêm:
   - `GIDClientID` = Client ID iOS.
   - `GIDServerClientID` = Web client ID.
   - `CFBundleURLTypes` → URL scheme = **Client ID iOS viết ngược** (`com.googleusercontent.apps.xxxx`), để Google trả kết quả đăng nhập về app.
3. Code `GoogleDriveAuth` (`lib/data/drive_sync_service.dart`) hiện chỉ truyền `serverClientId`; trên iOS cần có `clientId` — đọc từ `Info.plist` (không cần sửa code) hoặc truyền thêm tham số `clientId` khi chạy trên iOS.
4. Màn hình đồng ý OAuth vẫn ở chế độ **Testing** → Gmail dùng trên iPhone cũng phải nằm trong **Test users** (giống Android).

### 4.2. Micro (bài nói)
- `Info.plist`: `NSMicrophoneUsageDescription` – ví dụ: *"Ứng dụng dùng micro để bé tập nói và nghe lại giọng của mình. Bản ghi chỉ lưu tạm trên máy."*
- Thiếu khóa này app sẽ **bị đóng ngay** khi bé bấm micro.

### 4.3. Âm thanh trên iOS (rủi ro trải nghiệm cao nhất)
- Mặc định iOS **tắt tiếng app khi gạt công tắc im lặng**. Với app học có giọng đọc, cần đặt audio session sang chế độ **playback**:
  - `just_audio`: cấu hình qua gói `audio_session` (đã có sẵn dạng phụ thuộc gián tiếp; cần thêm vào `pubspec.yaml` để gọi trực tiếp) khi khởi động app.
  - `flutter_tts`: gọi `setIosAudioCategory(playback, …)` và `setSharedInstance(true)`.
- Phải test kỹ chuỗi: Momo đọc → bé ghi âm (session chuyển sang `playAndRecord`) → phát lại giọng bé → Momo khen, đảm bảo âm lượng không bị nhỏ/chuyển sang loa thoại.
- Hiệu ứng "giọng cao" khi phát lại bản ghi có thể không có trên iOS (không ảnh hưởng chức năng).

### 4.4. Nạp gói `.bvpack` từ máy
- Trình chọn file của iOS lọc theo "kiểu tài liệu" (UTI). Đuôi `.bvpack` không phải kiểu iOS biết → có thể **không chọn được file**.
- Hai cách: (a) khai báo kiểu file riêng `.bvpack` trong `Info.plist` (Exported Type Identifier, kế thừa `public.zip-archive`); hoặc (b) trên iOS chỉ nhận `.zip`. Khuyến nghị (a) và test bằng app Tệp (Files).
- Nạp qua Google Drive không bị ảnh hưởng.

### 4.5. Lưu trữ gói tải về (quy định của Apple)
- Gói chủ đề đang lưu ở `Application Support/packs` (có thể tới ~50 MB cho 20 gói). Trên iOS thư mục này **mặc định được sao lưu iCloud**.
- Apple yêu cầu nội dung **tải lại được** không được sao lưu → đây là lý do bị từ chối khi duyệt (guideline 2.5.x / Data Storage). Cần **đánh dấu "không sao lưu"** thư mục `packs` (cần một đoạn code native nhỏ hoặc plugin) hoặc chuyển sang thư mục phù hợp.

### 4.6. Giao diện & cấu hình chung
- `Info.plist`: chỉ hướng ngang (`UIInterfaceOrientationLandscapeLeft/Right`), ẩn thanh trạng thái (`UIStatusBarHidden`, `UIViewControllerBasedStatusBarAppearance = false`).
- iPad: nếu hỗ trợ iPad mà chỉ chạy ngang thì thêm `UIRequiresFullScreen = YES` (nếu không, Apple yêu cầu hỗ trợ mọi hướng). Kiểm tra bố cục bản đồ, bóng bay, Momo trên màn hình 4:3 của iPad.
- `CFBundleDisplayName` = **Kids English**.
- Icon iOS: thêm cấu hình `flutter_launcher_icons` cho iOS (không có alpha).
- `Podfile`: `platform :ios, '15.0'`.

### 4.7. Quyền riêng tư khi nộp App Store
- **Privacy manifest** (`PrivacyInfo.xcprivacy`): bắt buộc với app mới; các plugin Flutter tự kèm manifest của chúng, app cần kiểm tra và khai báo nếu dùng các API "required reason" (ví dụ đọc thời gian sửa file, `UserDefaults`).
- **App Privacy (nhãn dinh dưỡng)** trên App Store Connect: khai báo dữ liệu thu thập (Gmail phụ huynh khi đăng nhập; ghi âm chỉ lưu tạm trên máy, không gửi đi).
- URL chính sách quyền riêng tư công khai (đưa `docs/PRIVACY_POLICY.md` lên web).

---

## 5. Lưu ý duyệt App Store cho app trẻ em

| Quy định | Ảnh hưởng tới app | Việc cần làm |
|---|---|---|
| **Kids Category** (nếu chọn mục Trẻ em) – không quảng cáo, không analytics bên thứ ba | App hiện không có quảng cáo/analytics | Giữ nguyên, không thêm SDK theo dõi |
| **Cổng phụ huynh** trước mọi liên kết ra ngoài, mua hàng, đăng nhập | App đã có cổng phụ huynh (nhấn giữ + phép tính) trước Khu phụ huynh; đăng nhập Gmail và link Drive nằm trong Khu phụ huynh | Đảm bảo không có link ra ngoài nào trong khu của bé |
| **Sign in with Apple** (guideline 4.8) | Bắt buộc nếu dùng đăng nhập bên thứ ba làm **tài khoản chính**. App chỉ dùng Gmail để **truy cập Google Drive** (thuộc diện được miễn) | Ghi rõ trong ghi chú gửi reviewer |
| Scope `drive.readonly` | Google vẫn ở chế độ Testing (≤100 Gmail) | Reviewer của Apple cần đăng nhập được → cung cấp **tài khoản demo** đã thêm vào Test users, hoặc giải thích tính năng Drive là tuỳ chọn cho phụ huynh |
| Ghi âm giọng trẻ | Nhạy cảm | Mô tả rõ: ghi âm chỉ lưu tạm trên máy, xoá khi rời bài |

Nếu chỉ dùng trong gia đình / nhóm nhỏ: **TestFlight** là đủ (nhóm nội bộ tới 100 người, không cần duyệt đầy đủ như App Store; nhóm ngoài cần duyệt beta nhẹ). Bản TestFlight hết hạn sau 90 ngày, cần đẩy bản mới định kỳ.

---

## 6. Lộ trình đề xuất

| Bước | Việc | Ai làm | Ước tính |
|---|---|---|---|
| 0 | Chuẩn bị Mac + Xcode + CocoaPods + Flutter; đăng ký Apple Developer Program | Anh/chị | 1–3 ngày (chờ Apple duyệt tài khoản) |
| 1 | Gỡ plugin không dùng (`permission_handler`, `audioplayers`, `intl`); tạo `ios/`; đặt Bundle ID, tên, icon, hướng màn hình, `Podfile` iOS 15 | Claude (làm được ngay trên Windows, trừ bước chạy thử) | 0,5 ngày |
| 2 | Micro, audio session (công tắc im lặng), TTS iOS | Claude | 0,5–1 ngày |
| 3 | Kiểu file `.bvpack`, đánh dấu không sao lưu thư mục `packs` | Claude | 0,5 ngày |
| 4 | Tạo OAuth client iOS trên Google Cloud; điền vào `Info.plist` | Anh/chị tạo client, Claude điền cấu hình | 0,5 ngày |
| 5 | Build trên Mac, chạy Simulator + iPhone thật, sửa lỗi bố cục iPad | Anh/chị chạy trên Mac (Claude hỗ trợ nếu chạy được Claude Code trên Mac) | 1–2 ngày |
| 6 | Ký ứng dụng, tạo app trên App Store Connect, đẩy TestFlight | Anh/chị (cần đăng nhập Apple) | 0,5 ngày |
| 7 | (Tuỳ chọn) Privacy manifest, nhãn quyền riêng tư, ảnh chụp màn hình, nộp duyệt App Store | Anh/chị + Claude chuẩn bị nội dung | 1–2 ngày + thời gian Apple duyệt |

Bước 1–3 có thể làm ngay trên máy Windows hiện tại (chỉ là cấu hình + code), nhưng **chỉ kiểm chứng được khi build trên Mac**.

---

## 7. Chi phí dự kiến

| Khoản | Chi phí |
|---|---|
| Apple Developer Program | 99 USD/năm (bắt buộc nếu muốn TestFlight/App Store) |
| Máy Mac | Từ 0 (mượn) đến giá một Mac mini; hoặc thuê Mac cloud theo tháng |
| Google Cloud (OAuth, Drive API) | 0 (đang dùng miễn phí) |
| CI (Codemagic/GitHub Actions) | Tuỳ chọn, có gói miễn phí giới hạn |

---

## 8. Rủi ro & điểm cần kiểm tra kỹ

1. **Âm thanh**: công tắc im lặng, chuyển đổi giữa phát – ghi âm – phát lại (mục 4.3). Đây là chỗ dễ lỗi nhất trên iOS.
2. **Đăng nhập Google trên iOS**: sai Bundle ID / URL scheme sẽ làm đăng nhập không quay về app.
3. **Chọn file `.bvpack`** trong app Tệp.
4. **Bố cục iPad** (tỉ lệ 4:3) cho bản đồ đảo, bóng bay, Momo.
5. **Duyệt App Store**: dung lượng sao lưu iCloud của gói tải về, tài khoản demo cho reviewer, mô tả ghi âm trẻ em.

---

## 9. Việc anh/chị cần quyết định

1. Có Mac thật không, hay dùng phương án thuê/CI?
2. Mục tiêu: chỉ **dùng trong gia đình (TestFlight)** hay **phát hành App Store**?
3. Có hỗ trợ **iPad** không?
4. Bundle ID iOS mong muốn (đề xuất `com.bevui.kidsenglish`).

Khi có các quyết định trên, có thể bắt đầu ngay bước 1–3 trên máy hiện tại.
