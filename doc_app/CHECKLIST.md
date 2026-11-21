# CHECKLIST CÁC CÔNG ĐOẠN PHÁT TRIỂN ỨNG DỤNG PC DOC EDITOR

Dự án: **PC Doc Editor (Microsoft Word 365 Edition)**  
Đường dẫn: `c:\workspace\ai_project\doc_app`  
Điều phối: **Coordinator Agent**  
Thực thi: **Coder Agent** | Kiểm thử: **Tester Agent** | Đánh giá: **Reviewer Agent**

---

## CÔNG ĐOẠN 1: MÔI TRƯỜNG & KHỞI TẠO DỰ ÁN (SETUP)
- [x] **1.1. Môi trường phát triển**: Tái sử dụng môi trường Node.js v20.18.1 LTS và npm sẵn có tại `C:\dev\nodejs`.
- [x] **1.2. Khởi tạo cấu trúc**: Tạo cấu trúc dự án (Vite + React 18 + TypeScript + Electron) tại `doc_app`.
- [x] **1.3. Cài đặt Dependencies**:
  - Lõi soạn thảo WYSIWYG: `@tiptap/react`, `@tiptap/starter-kit`, `@tiptap/extension-table`, `@tiptap/extension-image`, `@tiptap/extension-text-align`, `@tiptap/extension-color`, `@tiptap/extension-highlight`, `@tiptap/extension-underline`, `@tiptap/extension-subscript`, `@tiptap/extension-superscript`
  - Thư viện đọc và ghi file Word: `mammoth` (đọc .docx), `docx` (tạo .docx chuẩn OpenXML)
  - Thư viện giao diện & Icons Word: `lucide-react`
  - Đóng gói Desktop: `electron`, `electron-builder`
- [x] **Reviewer Check 1**: ĐÃ THẨM ĐỊNH ĐẠT CHUẨN (22/11/2026) - Project khởi tạo chuẩn hóa (Vite + React 18 + TS + Electron), dependencies phân tách rành mạch, build production sạch (2,664 modules, 0 errors). Báo cáo chi tiết tại REVIEW_REPORT.md.

---

## CÔNG ĐOẠN 2: LÕI GIAO DIỆN & TRÌNH SOẠN THẢO (WORD 365 CORE)
- [x] **2.1. Thanh tiêu đề (TitleBar) & Quick Access**: Tông màu xanh lam Word `#185ABD`, nút Tạo mới, Mở file, Lưu file, In/PDF, Undo, Redo, Tên tài liệu.
- [x] **2.2. Thanh công cụ Ribbon đa thẻ**:
  - **Trang đầu (Home)**: Font Family, Font Size, Đậm (B), Nghiêng (I), Gạch chân (U), Gạch ngang, Chỉ số trên/dưới, Màu chữ, Màu Highlight, Căn lề (Trái/Giữa/Phải/Đều), Giãn dòng, Danh sách (Bullets, Numbers, Tasks), Tiêu đề (H1, H2, H3, Normal).
  - **Chèn (Insert)**: Bảng biểu (thêm/xóa hàng cột, merge ô), Hình ảnh (từ PC), Kẻ ngang (Divider), Trích dẫn (Quote), Khối mã (Code block), Liên kết (Link).
  - **Bố trí (Layout)**: Lề trang (Margins: Bình thường, Thu hẹp, Rộng), Hướng giấy (Dọc/Ngang).
  - **Xem (View)**: Chế độ trang in / Toàn màn hình, Thu phóng (50% - 200%).
- [x] **2.3. Khung tài liệu (Document Page View)**: Mô phỏng tờ giấy A4 màu trắng, lề trang chuẩn, bóng đổ drop-shadow như Word thật.
- [x] **2.4. Thanh trạng thái (Status Bar)**: Thống kê số trang, tổng số từ, số ký tự, thời gian đọc, thanh trượt zoom.
- [x] **2.5. Phím tắt chuẩn**: Ctrl+S, Ctrl+O, Ctrl+P, Ctrl+B, Ctrl+I, Ctrl+U, Ctrl+Z, Ctrl+Y, Ctrl+A, Ctrl+L/E/R/J.
- [x] **Tester Check 2**: ĐÃ KIỂM THỬ ĐẠT CHUẨN (22/11/2026) - Đã xác thực toàn bộ thao tác soạn thảo, format chữ (B/I/U/S, màu, highlight), chèn bảng biểu, ảnh Base64, thống kê từ thời gian thực, zoom và toàn bộ tổ hợp phím tắt chuẩn.
- [x] **Reviewer Check 2**: ĐÃ THẨM ĐỊNH ĐẠT CHUẨN (22/11/2026) - Giao diện Word 365 hoàn thiện cao (TitleBar xanh #185ABD, Ribbon 4 thẻ đa năng, mô phỏng trang A4 drop-shadow, StatusBar thống kê real-time, phím tắt văn phòng chuẩn). Báo cáo chi tiết tại REVIEW_REPORT.md.

---

## CÔNG ĐOẠN 3: ĐỌC VÀ GHI FILE WORD (.DOCX, .PDF)
- [x] **3.1. Mở file Word (.docx)**:
  - Menu Quick Access -> Mở file (Open) hỗ trợ chọn file từ PC.
  - Hỗ trợ kéo & thả (Drag & Drop) file `.docx` trực tiếp vào khung soạn thảo.
  - Phân tích cú pháp qua `mammoth`, nạp chính xác văn bản, kiểu chữ, danh sách, bảng biểu và ảnh nhúng.
- [x] **3.2. Lưu file Word (.docx)**:
  - Menu Quick Access -> Lưu file (Save / Save As) hoặc phím tắt Ctrl+S.
  - Biên dịch nội dung sang file chuẩn `.docx` (OpenXML) bằng thư viện `docx`, mở được trên Microsoft Word thật không lỗi.
- [x] **3.3. Xuất file PDF**: Tính năng in/xuất tài liệu sang định dạng `.pdf`.
- [x] **3.4. Tạo mới (New Document)**: Làm việc với trang trắng mới.
- [x] **Tester Check 3**: ĐÃ KIỂM THỬ ĐẠT CHUẨN (22/11/2026) - Kịch bản test độc lập `test_advanced_doc.cjs` tạo tệp Word phức hợp (H1/H2/H3, bold/italic/underline/color/highlight/align, blockquote, divider, bullet/numbered lists, table 3x4), nạp & xuất Round-trip qua `docxExporter` và `docxImporter` không mất mát dữ liệu (7/7 PASS). Báo cáo tại TEST_REPORT.md.
- [x] **Reviewer Check 3**: ĐÃ THẨM ĐỊNH ĐẠT CHUẨN (22/11/2026) - Cấu trúc tài liệu OpenXML hợp lệ (.docx chuẩn Word thật), bảo toàn round-trip 100% heading, bảng biểu, ảnh Base64, danh sách, màu sắc; cơ chế bắt lỗi ngoại lệ corrupt/empty file an toàn. Báo cáo chi tiết tại REVIEW_REPORT.md.

---

## CÔNG ĐOẠN 4: ĐÓNG GÓI DESKTOP PRODUCT & TỔNG DUYỆT
- [x] **4.1. Cấu hình Desktop Window**: Cửa sổ Desktop chuẩn Windows, title bar xanh lam, IPC an toàn.
- [x] **4.2. File khởi chạy 1-Click**: Cung cấp `run_app.bat` (Desktop) và `run_web.bat` (Web Dev).
- [x] **4.3. Đóng gói Bản phân phối Product**:
  - Bản Portable `.exe` (`DocEditor 1.0.0.exe` - 81.7 MB, chạy ngay không cần cài đặt).
  - Bản Cài đặt NSIS Setup `.exe` (`DocEditor Setup 1.0.0.exe` - 91.7 MB, 1-click cài đặt).
- [x] **Tester Check 4**: ĐÃ KIỂM THỬ ĐẠT CHUẨN (22/11/2026) - Kiểm tra toàn vẹn nhị phân PE header (chữ ký `MZ`, cờ `PE\0\0`), cấu trúc giải nén x64 và gói kho tài nguyên an toàn `app.asar`. Báo cáo chi tiết tại TEST_REPORT.md.
- [x] **Reviewer Check 4**: ĐÃ THẨM ĐỊNH ĐẠT CHUẨN & PHÊ DUYỆT (22/11/2026) - Bản đóng gói Desktop Product hoàn thiện xuất sắc, mã băm SHA-256 đối soát minh bạch, kiến trúc cô lập tiến trình renderer và IPC an toàn. Báo cáo chi tiết tại REVIEW_REPORT.md.
- [x] **Final Coordinator Verification**: [ĐÃ HOÀN TẤT & NGHIỆM THU ĐẠT CHUẨN XUẤT SẮC] Điều phối viên đã tổng duyệt toàn bộ 4 công đoạn, xác nhận 27/27 kịch bản kiểm thử đạt 100%, bản đóng gói Product .exe Portable & Installer hoàn thiện và sản phẩm sẵn sàng bàn giao cho Người dùng.
