# Hướng dẫn cấu hình nạp chủ đề từ Google Drive

Tài liệu dành cho chủ app / phụ huynh quản trị. Chỉ gồm các bước **bắt buộc phải làm bằng tay**. Phần code đã làm xong.

Thông tin cố định:

| Mục | Giá trị |
|---|---|
| Package name (applicationId) | `com.bevui.be_vui_tieng_anh` |
| SHA-1 của debug keystore trên máy build này | `88:79:B1:44:E5:D3:57:C4:49:49:24:7F:B6:67:EB:24:4C:C8:24:53` |
| Folder Drive | `10d5w1ZMGNRy4OmdX6_6nnhpaIu1H6hHm` |
| Scope | `https://www.googleapis.com/auth/drive.readonly` |

SHA-1 trên được lấy từ `~/.android/debug.keystore` (alias `androiddebugkey`, mật khẩu `android`). Nếu build trên máy khác thì SHA-1 sẽ khác, xem mục A.5.

---

## A. Cấu hình Google Cloud (làm một lần)

### A.1. Tạo project và bật Drive API
1. Vào https://console.cloud.google.com, đăng nhập bằng Gmail chủ app.
2. Tạo project mới (ví dụ `be-vui-tieng-anh`).
3. Vào **APIs & Services > Library**, tìm **Google Drive API** và bấm **Enable**.

### A.2. Màn hình đồng ý OAuth (OAuth consent screen)
1. **APIs & Services > OAuth consent screen** (hoặc **Google Auth Platform > Branding/Audience**).
2. User type: **External**. Điền tên app, email hỗ trợ, email liên hệ.
3. Ở phần Data Access / Scopes, thêm scope `.../auth/drive.readonly`.
4. Trạng thái xuất bản: để **Testing**.
5. Mục **Audience > Test users**: bấm **Add users** và thêm **từng Gmail** sẽ dùng app (tối đa 100).

Lưu ý quan trọng:
- Ở chế độ **Testing**, chỉ các Gmail nằm trong danh sách Test users mới đăng nhập được. Gmail khác sẽ bị Google chặn.
- Mỗi lần đăng nhập ở chế độ Testing, token làm mới (refresh) hết hạn sau 7 ngày, nên có thể phải đăng nhập lại khoảng mỗi tuần. Tính năng đồng bộ ngầm chỉ im lặng bỏ qua khi phiên hết hạn.
- `drive.readonly` là scope **restricted**. Nếu sau này bấm **Publish app** (In production) để mọi người dùng được, Google yêu cầu xác minh app (verification) và có thể cả đánh giá bảo mật (security assessment) cho scope restricted. Với app gia đình / nhóm nhỏ, nên giữ Testing, hoặc dùng phương án công khai ở mục D.

### A.3. Tạo OAuth client kiểu Android
1. **APIs & Services > Credentials > Create credentials > OAuth client ID**.
2. Application type: **Android**.
3. Package name: `com.bevui.be_vui_tieng_anh`.
4. SHA-1 certificate fingerprint: `88:79:B1:44:E5:D3:57:C4:49:49:24:7F:B6:67:EB:24:4C:C8:24:53` (debug).
5. Bấm **Create**. Không cần tải file gì về.

Có thể tạo nhiều Android client cho cùng package (một cho debug, một cho release), mỗi client một SHA-1.

### A.4. Tạo OAuth client kiểu Web (bắt buộc với google_sign_in v7 trên Android)
Bản `google_sign_in` 7.x trên Android dùng Credential Manager và **bắt buộc có `serverClientId`**, là Client ID của một client kiểu **Web application**.
1. **Credentials > Create credentials > OAuth client ID**, Application type: **Web application**, đặt tên bất kỳ, bấm **Create**.
2. Sao chép **Client ID** (dạng `1234567890-abc.apps.googleusercontent.com`). Không cần Client secret, không cần Authorized redirect URI.
3. Đưa giá trị này vào app khi build/chạy bằng `--dart-define` (đã được code đọc ở `lib/data/drive_sync_service.dart`, hằng `googleServerClientId`):

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
```

Nếu muốn khỏi gõ mỗi lần, có thể sửa giá trị mặc định `defaultValue` của hằng đó trong code (Client ID không phải bí mật).

### A.5. SHA-1 cho bản release / Google Play
- Lấy SHA-1 của keystore release:
  ```bash
  keytool -list -v -keystore đường_dẫn/release.jks -alias tên_alias
  ```
- Nếu phát hành lên Google Play với **Play App Signing** (mặc định): lấy SHA-1 ở Play Console > **Setup > App signing** (mục "App signing key certificate") và **thêm một Android OAuth client nữa** với SHA-1 đó. SHA-1 của upload key chỉ dùng khi cài trực tiếp bản ký bằng upload key.
- Mỗi cặp (package + SHA-1) cần có một Android OAuth client. Sai hoặc thiếu SHA-1 gây lỗi ở mục F.

---

## B. Chuẩn bị thư mục Google Drive

1. Mở folder `10d5w1ZMGNRy4OmdX6_6nnhpaIu1H6hHm`, đặt chia sẻ **Restricted** (Hạn chế).
2. Tải lên cùng một folder (không tạo thư mục con): `index.json` và các file `.bvpack` do mục C tạo ra.
3. Duyệt quyền: khi phụ huynh bấm "Gửi yêu cầu cấp quyền truy cập" trong app, bạn nhận email từ Google Drive. Bấm **Approve**, chọn quyền **Viewer**. Hoặc chủ động chia sẻ (Share) cho Gmail của họ với quyền Viewer.
4. Gmail đó cũng phải nằm trong danh sách **Test users** (mục A.2) khi app còn ở chế độ Testing.
5. Cập nhật chủ đề: tạo lại gói bằng công cụ ở mục C (version tự tăng), rồi tải `index.json` và `.bvpack` mới lên, chọn **Manage versions / Replace** hoặc xóa file cũ rồi tải lên để giữ tên file. App chỉ tải gói khi `version` trong `index.json` cao hơn bản đã cài.
6. Nếu chỉ thả `.bvpack`/`.zip` mà chưa sửa `index.json`: app dùng ngày sửa đổi (modifiedTime) của file để phát hiện bản mới. Hãy đặt tên file trùng mã chủ đề (ví dụ `t06_fruits.bvpack`).

---

## C. Tạo gói chủ đề bằng công cụ

Trong thư mục `app/`:

```bash
dart run tools/pack_topic.dart t06_fruits
dart run tools/pack_topic.dart t06_fruits --version 3 --out build/packs
```

- Đọc `assets/content/topics/<topicId>.json` và gom ảnh/âm thanh liên quan từ `assets/`.
- Tạo `build/packs/<topicId>.bvpack` và tạo hoặc gộp `build/packs/index.json`.
- Không truyền `--version`: gói mới là 1, gói đã có trong index tự tăng thêm 1.
- Công cụ in cảnh báo cho mọi file được tham chiếu nhưng không tồn tại. Hãy sửa hết cảnh báo trước khi tải lên.
- Chủ đề mới phải có file JSON trong `assets/content/topics/` và ảnh/âm thanh trong `assets/` (theo `docs/ASSET_SPEC.md`). Không cần khai báo thêm trong `curriculum.json` nếu chỉ phát hành qua gói.
- Mã chủ đề chỉ gồm chữ thường, số và dấu gạch dưới (`a-z`, `0-9`, `_`).

---

## D. Phương án công khai bằng API key (tuỳ chọn, để test nhanh)

Dùng khi chưa cấu hình OAuth hoặc muốn máy nào cũng nạp được mà không cần đăng nhập. Đổi lại, **ai có link folder đều tải được gói**.

1. Google Cloud > **Credentials > Create credentials > API key**.
2. Bấm vào key vừa tạo để giới hạn:
   - **API restrictions**: chỉ chọn **Google Drive API**.
   - **Application restrictions**: chọn **Android apps**, thêm package `com.bevui.be_vui_tieng_anh` + SHA-1.

   Lưu ý: app gọi bằng HTTP thường, không gửi kèm chữ ký ứng dụng Android, nên giới hạn Android apps có thể làm request bị từ chối. Nếu gặp lỗi 403, chỉ giữ giới hạn theo API (Drive API) và coi key là công khai.
3. Đặt folder Drive thành **Anyone with the link: Viewer**.
4. Chạy/build với key:
   ```bash
   flutter run --dart-define=DRIVE_API_KEY=AIza...
   ```
5. Khi chưa đăng nhập Gmail, app sẽ dùng `?key=` để đọc folder. Khi đã đăng nhập, app luôn dùng token Gmail.

---

## E. Checklist kiểm thử trên máy thật

1. Cài bản build (debug cùng máy build có SHA-1 ở trên).
2. Khu Phụ huynh > tab **Gói chủ đề** > bấm **Đăng nhập Gmail**, chọn Gmail nằm trong Test users, đồng ý quyền xem Google Drive.
3. Dùng Gmail **chưa** được chia sẻ folder: phải thấy khung cam "chưa được cấp quyền" và nút **Gửi yêu cầu cấp quyền truy cập** mở trang Drive.
4. Dùng Gmail **đã** được duyệt, bấm **Kiểm tra lại**: hiện "Đã kết nối kho chủ đề".
5. Bấm **Kiểm tra & Nạp từ Google Drive ngay**: thấy tiến trình từng gói, đảo mới xuất hiện trên bản đồ của bé, mở được bài học, nghe được âm thanh, xem được ảnh.
6. Bấm lại nút: báo "Tất cả chủ đề đã là bản mới nhất".
7. Tăng version trong `index.json`, tải lên, bấm lại: gói được cập nhật.
8. Bật công tắc tự động, thoát hẳn app, mở lại, vào màn hình bản đồ: có thông báo "Đã cập nhật N chủ đề mới" khi có gói mới.
9. Tắt mạng rồi mở app: app vẫn chạy bình thường, không báo lỗi cho bé.
10. Xóa một gói cài thêm bằng biểu tượng thùng rác, đồng bộ lại: gói được nạp lại.
11. Thử nạp file `.bvpack` từ bộ nhớ máy (nút "Chọn file gói từ thiết bị").

---

## F. Xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Thông báo cấu hình đăng nhập, log có `DEVELOPER_ERROR` hoặc code `10` | SHA-1 hoặc package name của build không khớp Android OAuth client | Kiểm tra lại mục A.3 và A.5. Với bản cài từ Play phải dùng SHA-1 của Play App Signing. Đợi vài phút sau khi tạo client. |
| `serverClientId must be provided` hoặc lỗi cấu hình client | Chưa truyền `GOOGLE_SERVER_CLIENT_ID` hoặc dùng nhầm Client ID kiểu Android | Tạo client kiểu **Web** (A.4) và truyền bằng `--dart-define`. |
| "Access blocked: app has not completed verification" / `access_denied` | Gmail chưa nằm trong Test users | Thêm vào Test users (A.2). |
| Đăng nhập OK nhưng báo "chưa được cấp quyền" | Gmail chưa được chia sẻ folder (Drive trả 403/404) | Duyệt yêu cầu truy cập hoặc Share quyền Viewer (mục B). |
| Lỗi 403 `accessNotConfigured` / "Drive API has not been used" | Chưa bật Drive API trong đúng project | Bật ở A.1, đúng project chứa OAuth client. |
| Lỗi 403 khi dùng API key | Folder chưa chia sẻ "Anyone with the link", hoặc key bị giới hạn sai | Xem mục D. |
| Phải đăng nhập lại sau khoảng 7 ngày | App đang ở chế độ Testing | Bình thường. Đăng nhập lại trong tab Gói chủ đề. |
| "topic.json không đọc được" / "Chủ đề có lỗi cấu trúc" | Gói sai định dạng hoặc tham chiếu từ không tồn tại | Chạy lại `tools/pack_topic.dart`, xem cảnh báo, kiểm tra JSON. |
| Gói tải về nhưng thiếu ảnh/âm thanh | File media không có trong `assets/` lúc đóng gói | Xem cảnh báo "thiếu file" của công cụ và bổ sung file. |
| Không nạp được trên bản release, bản debug thì được | Thiếu quyền INTERNET | Đã thêm vào `AndroidManifest.xml`. Hãy build lại. |
