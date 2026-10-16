# PLAN — Ứng dụng đọc / hiển thị / chỉnh sửa Text · Excel · Word (Android, offline)

Ngày lập: 2026-09-13 · Đã duyệt · Tiến độ: GĐ0 ✅ · GĐ1 ✅ · GĐ2 ✅ · GĐ3 ✅ · GĐ4 ✅ · GĐ5 ✅ (2026-09-14) · GĐ6 ✅ (2026-10-03)

## 1. Quyết định đã chốt

| Hạng mục | Lựa chọn |
|---|---|
| Nền tảng | Mobile app, **Android**, hoàn toàn offline |
| Framework | **Flutter** (Dart) |
| Chọn / lưu file | Hộp thoại hệ thống Android (SAF) + **lưu đè file gốc**, có "Lưu thành…" |
| Định dạng | Text (`.txt .md .json .xml .log .yaml` + mã nguồn phổ biến), **`.csv` `.tsv`** (mở dạng bảng tính), **`.xlsx`**, **`.docx`** |
| Phạm vi sửa Office | **B1 — xem + sửa cơ bản**, chấp nhận mất định dạng phức tạp khi lưu |
| Ngôn ngữ UI | Tiếng Việt |
| Phân phối | File APK cài trực tiếp (chưa lên Google Play) |

## 2. Kiến trúc tổng thể

```
bybrowser/
├── android/app/src/main/kotlin/.../SafPlugin.kt   ← MethodChannel: mở/đọc/ghi file qua SAF
├── lib/
│   ├── main.dart, app.dart                        ← MaterialApp, theme sáng/tối, locale vi
│   ├── core/
│   │   ├── saf/saf_service.dart                   ← gọi Kotlin: openDocument, readBytes, writeBytes, createDocument
│   │   ├── models/document_ref.dart               ← {uri, tên, mime, loại: text|xlsx|docx|unsupported}
│   │   ├── recent/recent_files.dart               ← danh sách file gần đây (shared_preferences)
│   │   └── encoding/text_codec.dart               ← phát hiện UTF-8/UTF-16 BOM, giữ CRLF/LF
│   ├── features/
│   │   ├── home/                                  ← nút "Mở file", danh sách gần đây
│   │   ├── text_editor/                           ← re_editor: số dòng, highlight, tìm/thay thế, wrap
│   │   ├── excel_editor/                          ← package excel + grid TableView, tab sheet, sửa ô
│   │   └── docx_editor/
│   │       ├── docx_reader.dart                   ← unzip → parse document.xml → Quill Delta
│   │       ├── docx_writer.dart                   ← Quill Delta → document.xml, giữ nguyên các part khác
│   │       └── docx_editor_page.dart              ← flutter_quill + toolbar
│   └── shared/                                    ← dialog "chưa lưu", status bar, toolbar chung
└── test/                                          ← unit test: encoding, docx reader/writer, excel round-trip
```

**Nguyên tắc chung**
- Mỗi loại file là một "editor page" độc lập, cùng interface: `load(bytes) / hasChanges / save() → bytes`.
- Lưu = ghi đè trực tiếp lên URI gốc qua SAF (không cần quyền "All files access").
- Word/Excel: khi lưu chỉ **thay phần nội dung**, giữ nguyên các thành phần còn lại trong file zip (styles, numbering, header/footer, media…) để giảm mất mát định dạng.

## 3. Thư viện dự kiến

| Mục đích | Package | Ghi chú |
|---|---|---|
| Text editor | `re_editor` | số dòng, highlight, tìm/thay thế, xử lý tốt file lớn |
| Highlight | `re_highlight` | đi kèm re_editor |
| Excel đọc/ghi | `excel` | đọc/ghi xlsx, giữ công thức dạng chuỗi (không tính lại) |
| Grid Excel | `two_dimensional_scrollables` | TableView chính thức của Flutter, ghim hàng/cột tiêu đề, không vấn đề license |
| Word editor | `flutter_quill` | rich text: bold/italic/underline/strike, heading, list, align |
| Docx parse | `archive` + `xml` | tự viết reader/writer |
| Lưu trữ nhỏ | `shared_preferences` | recent files, theme |
| SAF | **tự viết Kotlin** (~150 dòng) | đáng tin cậy hơn các package bên thứ 3, kiểm soát đầy đủ |

## 4. Giới hạn cần chấp nhận (sẽ ghi rõ trong app)

- **Excel**: chart, conditional formatting, data validation, pivot **được giữ nguyên trong file** (không hiển thị trong app). Công thức giữ nguyên và được dịch tham chiếu khi chèn/xóa dòng cột, nhưng **không tính toán lại** trong app (hiển thị giá trị cache; Excel tính lại khi mở). Hiển thị: bold, căn lề, định dạng số/ngày/% cơ bản; không hiển thị màu nền, viền. Vùng conditional formatting / data validation / hyperlink không được dịch khi chèn/xóa dòng cột.
- **Word**: sửa được văn bản, đậm/nghiêng/gạch chân/gạch ngang, màu chữ, nền, cỡ chữ, font, heading 1-6, danh sách bullet/số nhiều cấp, căn lề, thụt lề, hyperlink. **Bảng, ảnh, hộp văn bản, biểu đồ, công thức toán** hiển thị chỉ đọc và được giữ nguyên XML khi lưu (không sửa được trong app). Header/footer, khổ giấy, lề, styles giữ nguyên. Mất khi lưu: footnote/endnote, comment, field tự động (số trang, mục lục → thành text tĩnh), track changes (chấp nhận hết). Ngắt dòng mềm (Shift+Enter) và ngắt trang thành đoạn mới.
- **Text**: file > ~5 MB sẽ cảnh báo và mở ở chế độ chỉ đọc.
- Không hỗ trợ `.doc` / `.xls` (định dạng cũ 97-2003).

## 5. Các giai đoạn thực hiện

### Giai đoạn 0 — Chuẩn bị môi trường (≈ 30 phút)
- [x] `flutter upgrade` lên stable mới nhất (hiện 3.19.6 / Dart 3.3.4 quá cũ cho các package trên).
- [x] `flutter doctor --android-licenses` chấp nhận license.
- [x] `flutter create` project, package name `com.dtdung.bybrowser`, min SDK 24 (Android 7+).
- [x] `git init`, `.gitignore`.
- [x] Chạy thử app trống trên emulator Android 14 để chắc chắn toolchain OK.

### Giai đoạn 1 — Khung app + mở/lưu file qua SAF
- [x] Kotlin `SafPlugin`: `openDocument(mimeTypes)`, `createDocument(name, mime)`, `readBytes(uri)`, `writeBytes(uri, bytes)`, `getInfo(uri)` (tên, size, mime), `takePersistablePermission`.
- [x] Dart `SafService` + model `DocumentRef`, nhận diện loại file theo đuôi/mime.
- [x] Màn hình Home: nút "Mở file", danh sách gần đây (lưu URI đã persist), xóa khỏi danh sách.
- [x] Khung editor chung: AppBar (tên file, dấu `*` khi chưa lưu, nút Lưu / Lưu thành…), xử lý nút Back → hỏi "Lưu thay đổi?".
- [x] Loại file không hỗ trợ → thông báo rõ ràng.
- **Kiểm tra**: mở file `.txt` bất kỳ từ máy, xem nội dung thô, lưu đè lại thành công.

### Giai đoạn 2 — Text editor
- [x] `TextCodec`: phát hiện BOM UTF-8/UTF-16 LE/BE, mặc định UTF-8, giữ nguyên kiểu xuống dòng khi lưu.
- [x] Editor `re_editor`: số dòng, highlight theo đuôi file (md, json, xml, yaml, dart, js, py, html, css, sql…), bật/tắt word wrap.
- [x] Tìm kiếm / thay thế (panel tự thiết kế cho mobile trên CodeFindController).
- [x] Status bar: encoding, kiểu xuống dòng, ngôn ngữ, số dòng, dòng:cột (+ nút undo/redo).
- [x] Undo/redo.
- [x] Unit test `TextCodec` (11 test).
- **Kiểm tra**: mở/sửa/lưu file UTF-8 có tiếng Việt, file CRLF, file JSON lớn ~2 MB.

### Giai đoạn 3 — Excel editor
- [x] Đọc `.xlsx` bằng reader tự viết (archive + xml) → `Worksheet` (ô, kiểu, công thức + giá trị cache, merge, cols, row attrs). **Bỏ package `excel`** vì xử lý công thức sai và ghi lại toàn bộ file (mất chart/định dạng).
- [x] Grid `TableView`: cuộn 2 chiều, ghim tiêu đề, độ rộng cột / chiều cao dòng từ file, ô gộp, bold, căn lề.
- [x] Tab chuyển sheet ở dưới (+ undo/redo).
- [x] Sửa ô: chạm chọn, thanh công thức phía trên, Enter → xuống dòng dưới, chạm đúp → focus.
- [x] Thêm/xóa dòng, thêm/xóa cột (menu ⋮) — **có dịch tham chiếu công thức** (A1, $A$1, vùng, A:A, 1:1, sheet khác).
- [x] Tìm kiếm trong sheet.
- [x] Lưu: vá `<sheetData>` (+cols, mergeCells, dimension) trong XML gốc; bỏ calcChain; đặt fullCalcOnLoad để Excel tính lại.
- [x] Unit test: reader, number format, writer round-trip, FormulaShift, controller (27 test).
- **Kiểm tra**: file nhiều sheet, có công thức, có merge; mở lại bằng Excel/LibreOffice trên máy tính để xác nhận không hỏng.

### Giai đoạn 4 — Word editor
- [x] `DocxReader`: document.xml → Quill Delta. Paragraph, heading 1-6 (theo styles.xml), run format (b/i/u/strike/color/highlight/shd/sz/rFonts/vertAlign), list bullet/số + cấp (numbering.xml), căn lề, hyperlink, tab, field → text tĩnh. Ảnh/đối tượng inline và bảng/phần tử lạ giữ **XML thô** (embed tùy chỉnh); phần pPr/rPr không ánh xạ được giữ làm "residual" để ghi lại.
- [x] `DocxWriter`: dựng lại `<w:body>` trong document.xml gốc (giữ root/namespace/sectPr); merge residual + thuộc tính theo đúng thứ tự schema; tự thêm style Heading, numbering (bullet/số), relationship hyperlink khi thiếu.
- [x] Page `flutter_quill` 11.5 + toolbar 1 hàng cuộn ngang sát bàn phím (cỡ chữ, B/I/U/S, màu, nền, heading, list, căn lề, thụt lề, link, undo/redo, tìm kiếm); embed builder cho ảnh (Image.memory) và bảng (Table chỉ đọc).
- [x] Hộp thoại cảnh báo khi mở nếu file có footnote/comment/field/track changes; menu "Giới hạn hỗ trợ Word".
- [x] Unit test (7): reader với file Word thật, round-trip, ghi đủ loại định dạng, file thiếu numbering/heading style.
- **Kiểm tra**: tạo docx mẫu trên máy tính (heading, list, bold, ảnh, bảng) → mở, sửa, lưu → mở lại bằng Word/LibreOffice.

### Giai đoạn 5 — Hoàn thiện
- [x] Theme sáng/tối (theo hệ thống + tùy chọn, lưu SharedPreferences) — menu ⋮ ở Home.
- [x] "Mở bằng…" (ACTION_VIEW) cho text/json/xml/xlsx/docx theo mime + đuôi file; MethodChannel `com.dtdung.bybrowser/intent` (pending khi khởi động, callback khi đang chạy).
- [x] Tên app "ByBrowser", icon adaptive (assets/icon, flutter_launcher_icons), splash indigo + icon (values-v31 cho Android 12+).
- [x] Màn hình "Giới thiệu & giới hạn" (phiên bản từ package_info_plus).
- [x] Build release: `dist/ByBrowser-1.0.0-arm64.apk` (20.6 MB, điện thoại 64-bit), `-arm32.apk` (18.7 MB), `-universal.apk` (60 MB, mọi ABI kể cả emulator x86_64).
- **Kiểm tra**: cài APK lên emulator (và điện thoại thật nếu có), chạy qua toàn bộ kịch bản 3 loại file.

### Giai đoạn 6 — Mở CSV/TSV dạng bảng tính (2026-10-03)
Hướng làm: đọc CSV thành `Workbook` 1 sheet để dùng lại `SheetGrid` + `ExcelController`; lưu thì ghi ngược ra CSV theo định dạng gốc. Code ở `lib/features/excel_editor/csv/`.
- [x] `CsvCodec`: parser RFC 4180 (ngoặc kép, `""`, xuống dòng trong ô, không ném lỗi với ngoặc không đóng); tự nhận dấu phân cách `, ; \t |` (số dòng đều cột nhiều nhất); hỗ trợ dòng `sep=;` của Excel.
- [x] `CsvDocument`: mọi ô là text, giữ nguyên chuỗi (`007`, `1.50`); giữ encoding/BOM, kiểu xuống dòng, dòng trống, xuống dòng cuối file, dòng thiếu cột (file không đều), kiểu đặt ngoặc (tối thiểu / tất cả / chỉ ô chữ); độ rộng cột theo nội dung.
- [x] `CsvController extends ExcelController`: nhập liệu giữ nguyên (không chuẩn hóa số, `=…` là text), ô trông như số căn phải, chèn/xóa cột cập nhật số trường mỗi dòng, chưa sửa thì lưu trả lại đúng byte gốc, "Đổi dấu phân cách…" (đọc lại, chỉ khi không có thay đổi chưa lưu).
- [x] `DocumentKind.csv` (đuôi csv/tsv, mime text/csv…); mặc định mở dạng bảng; menu "Mở dạng văn bản" ↔ "Mở dạng bảng tính" (hỏi lưu, thay màn hình hiện tại); parse trong isolate (`compute`); > 200.000 ô hoặc > 5 MB thì hỏi mở dạng bảng hay văn bản.
- [x] Thanh dưới hiện `CSV · dấu phân cách · encoding · xuống dòng` thay cho tab sheet; manifest thêm `.tsv`; hộp chọn file thêm mime `application/vnd.ms-excel` (một số trình quản lý file gán cho .csv).
- [x] Unit test 24 (`test/csv_test.dart`); tổng 58 test pass.
- [x] Build release 1.1.0+2: `dist/ByBrowser-1.1.0-arm64.apk` (20.6 MB), `-arm32.apk` (18.8 MB), `-universal.apk` (60 MB).
- **Kiểm tra** (AVD `bybrowser_test`): CSV `;` + BOM + CRLF + tiếng Việt + ô nhiều dòng → hiển thị đúng, sửa ô → lưu → file kéo về giữ BOM/CRLF/ngoặc, `007` nguyên; chuyển bảng ↔ văn bản; xlsx không bị ảnh hưởng.
- Chưa làm: "Xuất ra .xlsx" (để lần sau); giải mã Windows-1258/1252 cho CSV ANSI do Excel tiếng Việt xuất (hiện rơi về Latin-1 → lỗi dấu).

## 6. Thứ tự bàn giao / điểm dừng để bạn kiểm tra

Sau mỗi giai đoạn 1 → 4 tôi sẽ dừng, chạy thử trên emulator, chụp màn hình gửi bạn và chờ xác nhận trước khi làm giai đoạn kế tiếp.

## 7. Rủi ro & phương án dự phòng

| Rủi ro | Dự phòng |
|---|---|
| `flutter upgrade` gặp lỗi mạng/quyền | Cài Flutter mới vào thư mục riêng, hoặc pin phiên bản package cũ tương thích Dart 3.3 (chất lượng thấp hơn) |
| `re_editor` không ổn với file lớn trên emulator | Chuyển sang `code_text_field` hoặc TextField thường + giới hạn kích thước |
| `excel` mất định dạng nhiều hơn dự kiến | Chuyển sang cách "vá" trực tiếp `sheetN.xml` trong zip (giống cách làm với docx) |
| Docx phức tạp làm reader lỗi | Fallback: hiển thị text thuần read-only, không cho lưu |

## 8. Ghi chú môi trường (rút ra khi thực hiện)

- Flutter đã nâng lên **3.47.4 / Dart 3.13.3**; Android SDK 36 + build-tools 36 + NDK 28.2.13676358 đã cài.
- `android/gradle.properties` có `kotlin.incremental=false` — Windows hay lỗi "Could not close incremental caches".
- Manifest tắt Impeller (`EnableImpeller=false`) vì emulator x86 (emulator 32.1) không link được shader → màn hình trống. Thiết bị thật không bị ảnh hưởng; có thể bật lại khi cập nhật emulator.
- Trên Git Bash, đường dẫn `/sdcard/...` bị chuyển thành đường dẫn Windows → dùng PowerShell cho `adb push/shell cat`.
- Text editor: highlight tắt với file > 512 KB (re_highlight xử lý cả file một lần, rất chậm); file > 5 MB chỉ đọc. re_editor tự xin focus khi khởi tạo → dùng `FocusNode(canRequestFocus: false)` cho tới khi người dùng chạm vào editor.
- Downloads provider trả về 2 URI khác nhau cho cùng file (`raw:` / `msf:`) → danh sách gần đây loại trùng theo (tên, kích thước) ngoài URI.
- Thanh dưới của editor phải đặt trong `body` (Column) thay vì `bottomNavigationBar`, nếu không bị bàn phím che.
- Excel: package `excel` 4.0.6 lưu ô công thức dạng `t="str"` sai (giá trị cache thành công thức) và vứt giá trị cache → thay bằng reader/writer tự viết ở `lib/features/excel_editor/xlsx/`. Fixture `test/fixtures/mau.xlsx` tạo bằng Excel COM; kiểm chứng file lưu ra bằng Excel COM (PowerShell) — mở không cần repair.
- Emulator có app `com.daotrongdung.music_player` (dự án khác) thỉnh thoảng chiếm foreground → test tự động bằng `adb input` cần kiểm tra `mCurrentFocus` trước mỗi bước.
- Word: fixture `test/fixtures/mau.docx` tạo bằng Word COM; kiểm chứng file lưu ra bằng Word COM. flutter_quill chỉ giữ thuộc tính inline chuẩn khi gõ tiếp (residual `docxrpr` không lan sang text mới → text mới lấy font mặc định của đoạn).
- GĐ5 test trên AVD riêng `bybrowser_test` (Pixel 6, API 34, port 5556, `-gpu swiftshader_indirect`) vì emulator 5554 có app khác của người dùng đang `flutter run` và tự chiếm foreground. Kịch bản release: xlsx sửa+lưu → Excel mở OK, docx sửa+lưu → Word mở OK, txt sửa+lưu giữ BOM/CRLF, "Mở bằng…", theme tối lưu qua khởi động lại, splash + icon.
- Release APK ký bằng debug keystore (chưa có keystore riêng) — đủ để cài trực tiếp; nếu phát hành Play Store cần tạo keystore và cấu hình `signingConfigs` trong `android/app/build.gradle.kts`.
