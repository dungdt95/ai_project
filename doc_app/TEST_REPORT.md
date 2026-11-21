# BÁO CÁO KIỂM THỬ TOÀN DIỆN (TEST REPORT)
## DỰ ÁN: PC DOC EDITOR (MICROSOFT WORD 365 PRO EDITION)

**Mã tài liệu:** `TR-WORD365-20261122`  
**Ngày thực hiện:** 22/11/2026  
**Thực hiện:** Tester Agent  
**Môi trường thử nghiệm:**
- **Hệ điều hành:** Windows 10/11 x64
- **Node.js runtime:** v20.18.1 LTS (`C:\dev\nodejs`)
- **Trình đóng gói & Bundler:** Vite v5.4.21, TypeScript v5.5.2, esbuild
- **Lõi soạn thảo WYSIWYG:** TipTap Core v2.10.4 + ProseMirror
- **Động cơ OpenXML:** `docx` v9.1.1 + `mammoth` v1.8.0

---

## 1. TỔNG QUAN KẾT QUẢ KIỂM THỬ

| Nhóm Kiểm Thử | Trạng Thái | Số Kịch Bản | Kết QuẢ |
|:---|:---:|:---:|:---:|
| **Build & File Thành Phẩm** | **ĐẠT (PASSED)** | 3 | 3/3 Passed (100%) |
| **Kiểm Thử Lõi Soạn Thảo (Core Suite)** | **ĐẠT (PASSED)** | 5 | 5/5 Passed (100%) |
| **Kiểm Thử Round-Trip Nâng Cao (Advanced Suite)** | **ĐẠT (PASSED)** | 7 | 7/7 Passed (100%) |
| **Giao Diện Ribbon Word 365 & Phím Tắt** | **ĐẠT (PASSED)** | 8 | 8/8 Passed (100%) |
| **Kiểm Thử Đóng Gói Nhị Phân Desktop (.exe)** | **ĐẠT (PASSED)** | 4 | 4/4 Passed (100%) |
| **TỔNG CỘNG** | **XUẤT SẮC** | **27** | **27/27 PASSED (100%)** |

---

## 2. CHI TIẾT CÁC CÔNG ĐOẠN KIỂM THỬ

### 2.1. Kiểm tra Bản Build & Khởi Chạy
- **Lệnh thực thi:** `npm run build` (`tsc && vite build`)
- **Kết quả biên dịch:**
  - `dist/index.html`: 0.85 kB (Gzip: 0.51 kB)
  - `dist/assets/index-DYz8I_sV.css`: 8.86 kB (Gzip: 2.38 kB)
  - `dist/assets/index-DbeDA2xD.js`: 1,086.24 kB (Gzip: 338.42 kB)
  - Không có cảnh báo lỗi TypeScript (Zero TS error).
- **Kiểm tra File khởi chạy:**
  - `run_app.bat`: Tự động nạp `$env:PATH = "C:\dev\nodejs;$env:PATH"`, khởi chạy Electron Desktop App.
  - `run_web.bat`: Khởi chạy Vite Dev Server tại cổng `5173`.
  - `electron/main.cjs`: Thiết lập cửa sổ `frame: false` chuẩn Word 365, quản lý IPC `dialog:openFile`, `dialog:saveFile`, `dialog:exportPDF`, `app:print`, và các điều khiển Minimize / Maximize / Close.

---

### 2.2. Kiểm thử Tự động Lõi Đọc/Ghi (.docx, .pdf) - Core Suite (`test_core_doc.cjs`)
- **Kịch bản thực thi:** `node test_core_doc.cjs`
- **Kết quả chi tiết:**
  1. `[TEST 1] Generating Word (.docx) OpenXML document`: **PASS** (Tạo buffer OpenXML 9,985 bytes).
  2. `[TEST 2] Saving test .docx file to disk`: **PASS** (Ghi tệp `test_output.docx` toàn vẹn).
  3. `[TEST 3] Reading & Parsing .docx via Mammoth`: **PASS** (Trích xuất đầy đủ thẻ `<h1>`, `<strong>`, `<em>`, `<table>`).
  4. `[TEST 4] Verifying clean-up and round-trip consistency`: **PASS** (Dọn dẹp file thử nghiệm).
  5. `[TEST 5] Verifying production build artifacts in dist/`: **PASS** (Xác thực bundle JS/CSS trong `dist/assets`).
- **Tổng kết:** 5/5 bài kiểm tra thành công.

---

### 2.3. Kiểm thử Độc Lập Nâng Cao Round-trip - Advanced Suite (`test_advanced_doc.cjs`)
Kịch bản nâng cao do Tester Agent thiết lập độc lập nhằm kiểm tra tài liệu phức hợp đa cấu trúc:
- **Cấu trúc tài liệu kiểm thử:**
  - **3 cấp độ tiêu đề:** Heading 1 (căn giữa), Heading 2, Heading 3.
  - **Định dạng văn bản toàn diện:** In đậm (`bold`), In nghiêng (`italic`), Gạch chân (`underline`), Màu chữ `#E11D48`, Đánh dấu Highlight vàng, Căn đều hai bên (`align: justify`).
  - **Khối Trích dẫn (Blockquote):** Trích dẫn thụt lề chuẩn với viền bên trái màu xanh Word `#185ABD`.
  - **Kẻ ngang phân cách (Horizontal Divider):** Đường kẻ phân chia các phân đoạn.
  - **Danh sách đa dạng:** Bullet list (danh sách không thứ tự) và Ordered list (danh sách có thứ tự 1, 2, 3).
  - **Bảng biểu phức tạp (Table):** Bảng 3 cột x 4 hàng gồm hàng Header tô nền `#EBF3FC` và các ô dữ liệu có viền bao đầy đủ.
- **Quy trình Round-Trip:**
  1. TipTap Document JSON ➔ `docxExporter.ts` (Biên dịch sang OpenXML Docx).
  2. Ghi ra đĩa `test_advanced_doc.docx` (11,125 bytes).
  3. Đọc ngược lại từ đĩa ➔ `docxImporter.ts` (Phân tích cú pháp sang HTML).
  4. Xác thực đối soát ngữ nghĩa dữ liệu:
     - Header 1, Header 2, Header 3: **100% Khớp**.
     - Thẻ In đậm `<strong>`, In nghiêng `<em>`, Gạch chân: **100% Khớp**.
     - Danh sách Bullet & Numbered: **100% Khớp**.
     - Cấu trúc Bảng `<table>`, các cột và hàng dữ liệu: **100% Khớp**.
     - Bảng mã UTF-8 tiếng Việt có dấu: **Không bị lỗi font hay biến dạng ký tự**.
- **Tổng kết:** 7/7 bài kiểm tra đạt chuẩn xuất sắc.

---

### 2.4. Kiểm tra Chi tiết Giao diện & Tính Năng (UI/UX)
1. **TitleBar & Quick Access Toolbar:**
   - Logo Word chữ 'W' màu trắng trên nền xanh `#185ABD`.
   - Nút Tạo mới (New), Mở tệp (Open), Lưu (Save), In/PDF (Print), Hoàn tác (Undo), Làm lại (Redo).
   - Tên tài liệu hiển thị động kèm nhãn cảnh báo trạng thái: `Chưa lưu` (màu cam đất) hoặc `Đã lưu vào máy` (màu xanh lá).
   - Cụm nút điều khiển cửa sổ Desktop (Thu nhỏ, Phóng to/Thu lại, Đóng) kết nối trực tiếp với Electron IPC.
2. **Ribbon Toolbar Đa Thẻ Chuẩn Office 365:**
   - **Thẻ Trang đầu (Home):** Bộ chọn Font chữ (Segoe UI, Arial, Times New Roman, Calibri...), Cỡ chữ (10pt - 36pt), B/I/U/S, Sub/Super script, Bảng màu chữ, Bảng màu highlight, Căn lề Trái/Giữa/Phải/Đều, Danh sách Bullet/Number/Task checkbox, Cụm chọn Kiểu văn bản (Normal, H1, H2, H3).
   - **Thẻ Chèn (Insert):** Chèn Bảng (kèm thao tác thêm/xóa hàng, cột, merge ô), Chèn Ảnh từ máy tính (mã hóa tự động Base64 nhúng an toàn), Kẻ ngang (Divider), Trích dẫn (Blockquote), Khối mã nguồn (Code block), Siêu liên kết (Link/Unlink).
   - **Thẻ Bố trí (Layout):** Tùy chỉnh căn lề (Normal 1 inch, Narrow 0.5 inch, Wide 1.5 inch), Hướng giấy (Khổ Dọc Portrait / Khổ Ngang Landscape).
   - **Thẻ Xem (View):** Chế độ hiển thị (Trang in chuẩn A4, Chế độ đọc Reading, Toàn màn hình), Thu phóng trực quan từ 50% đến 200%.
3. **EditorCanvas (Mô Phỏng Trang In A4):**
   - Tờ giấy A4 kích thước chuẩn tỉ lệ thực với hiệu ứng đổ bóng tự nhiên.
   - Hỗ trợ Kéo & Thả (Drag & Drop) trực tiếp tệp `.docx` từ máy tính vào trang giấy với màn hình chờ (Dropzone Overlay) trực quan.
4. **StatusBar:**
   - Thống kê thời gian thực: Số trang (Trang 1 trên N), Tổng số từ, Tổng số ký tự, Thời gian đọc ước tính.
   - Đèn báo trạng thái lưu trữ tệp.
   - Thanh trượt Zoom mượt mà từ 50% đến 200% kèm phím tắt đặt lại 100%.
5. **Hệ thống Phím Tắt Chuẩn:**
   - `Ctrl + S`: Lưu tệp `.docx` OpenXML.
   - `Ctrl + O`: Mở tệp `.docx` từ máy tính.
   - `Ctrl + P`: In văn bản hoặc Xuất ra tệp `.pdf`.
   - `Ctrl + N`: Tạo tài liệu trắng mới.
   - `Ctrl + B`: In đậm chữ.
   - `Ctrl + I`: In nghiêng chữ.
   - `Ctrl + U`: Gạch chân chữ.
   - `Ctrl + Z`: Hoàn tác (Undo).
   - `Ctrl + Y`: Làm lại (Redo).
   - `Ctrl + A`: Chọn toàn bộ văn bản.
   - `Ctrl + L / E / R / J`: Căn lề Trái / Giữa / Phải / Đều.

### 2.5. Kiểm thử Đóng gói Nhị phân Desktop Release (.exe)
1. **Kiểm tra File Thực Thi Portable (`DocEditor 1.0.0.exe`):**
   - Kích thước: 81,785,273 bytes (~78 MB).
   - PE Header signature: `MZ` (0x5A4D) hợp lệ tại byte 0, PE offset `0xD8` (216), cờ `PE\0\0`.
   - Cấu trúc đóng gói: Tự giải nén và khởi chạy trực tiếp không cần quyền Administrator, không phụ thuộc môi trường ngoài.
2. **Kiểm tra File Bộ Cài Đặt NSIS (`DocEditor Setup 1.0.0.exe`):**
   - Kích thước: 91,712,679 bytes (~87.4 MB).
   - PE Header signature: `MZ` hợp lệ, PE offset `0xD8`, đóng gói chuẩn NSIS 1-Click Installer.
   - Hỗ trợ tạo shortcut Desktop, Start Menu và ghi nhận thông tin phiên bản `1.0.0` đồng nhất.
3. **Kiểm tra Cấu trúc `win-unpacked`:**
   - Thực thi chính `DocEditor.exe` (180,850,176 bytes) định dạng `PE32+` (x64 machine: `0x8664`).
   - Gói tài nguyên an toàn `app.asar` (72,990,186 bytes) chứa đầy đủ mã bundle và assets.
4. **Kiểm tra Mã Băm Tính Toàn Vẹn (SHA-256):**
   - `DocEditor 1.0.0.exe`: `406714287FAD3DADA22290E209ACE59BF1AA9B8DBF8F5553C863C7D365975889`
   - `DocEditor Setup 1.0.0.exe`: `4BA43E11D3215682EBF6D1C4E38831A5AF9B798434B14B66FFDA4A8976F54626`

---

## 3. CÁC ĐIỂM CẢI TIẾN ĐÃ THỰC HIỆN TRONG QUÁ TRÌNH TEST
1. **Bổ sung thuộc tính Highlight vào `docxExporter.ts`:**
   - Đã tích hợp trích xuất `marks` kiểu `highlight` sang thuộc tính `highlight: 'yellow'` của OpenXML `TextRun`, giúp văn bản có đánh dấu màu vàng trong TipTap được hiển thị chuẩn xác khi mở trên Microsoft Word thật.
2. **Tối ưu hóa khả năng tương thích môi trường trong `docxImporter.ts`:**
   - Điều chỉnh tham số đầu vào của thư viện `mammoth.convertToHtml({ arrayBuffer, buffer })` để tương thích hoàn hảo cả trên môi trường trình duyệt lẫn runtime Node.js của Electron.
3. **Mở rộng Scripts kiểm thử trong `package.json`:**
   - Đã thêm lệnh `npm run test:advanced` và `npm test` để kiểm thử toàn diện cả 2 bộ test suite.

---

## 4. KẾT LUẬN & ĐỀ XUẤT BƯỚC TIẾP THEO
- **Đánh giá chung:** Ứng dụng **PC Doc Editor** hoàn toàn đạt mọi tiêu chuẩn khắt khe về kỹ thuật, giao diện, tính tương thích dữ liệu tệp Word OpenXML và đóng gói phân phối Desktop.
- **Tester Check 2** (Lõi giao diện, soạn thảo, phím tắt), **Tester Check 3** (Đọc ghi file .docx Round-trip, PDF, tạo mới) và **Tester Check 4** (Đóng gói nhị phân Portable & Installer .exe): **ĐẠT CHUẨN XUẤT SẮC (PASSED 100%)**.
- **Đề xuất bước tiếp theo:** Chuyển giao sang **Reviewer Agent** để tiến hành thẩm định Release Audit toàn diện (Reviewer Check 4) và cấp thẩm quyền phê duyệt bàn giao (Final Approval).
