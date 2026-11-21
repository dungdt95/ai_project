# PC DOC EDITOR (MICROSOFT WORD 365 EDITION)

Ứng dụng soạn thảo, đọc và chỉnh sửa file tài liệu Word (.docx) chuyên nghiệp trên máy tính cá nhân (PC Desktop) với giao diện và trải nghiệm tương tự Microsoft Word 365.

---

## 🚀 HƯỚNG DẪN KHỞI CHẠY ỨNG DỤNG

Thư mục dự án: `c:\workspace\ai_project\doc_app`

### Cách 1: Chạy Bản Portable .exe Độc Lập *(Khuyên dùng nhất)*
- Vào thư mục: `c:\workspace\ai_project\doc_app\release\`
- Nháy đúp chuột vào: **`DocEditor 1.0.0.exe`**  
*(Ứng dụng mở ngay lập tức, không cần cài đặt. Bạn có thể copy file này vào USB hoặc gửi sang bất kỳ máy tính nào để dùng)*.

### Cách 2: Cài đặt vào Windows (Bản Setup Installer)
- Vào thư mục: `c:\workspace\ai_project\doc_app\release\`
- Nháy đúp chuột vào: **`DocEditor Setup 1.0.0.exe`**  
*(Trình cài đặt 1-click tự động tạo biểu tượng trên Desktop và trong Start Menu của Windows)*.

### Cách 3: Chạy qua file Script 1-Click
- Mở thư mục `c:\workspace\ai_project\doc_app\` và nháy đúp:
  - **`run_app.bat`**: Khởi chạy ứng dụng Desktop Windows.
  - **`run_web.bat`**: Khởi chạy phiên bản Web Dev (`http://localhost:5173`).

---

## ✨ CÁC TÍNH NĂNG NỔI BẬT

### 1. Giao diện chuẩn Microsoft Word 365
- **Thanh tiêu đề (TitleBar)**: Tông màu xanh lam Word `#185ABD`, Quick Access Toolbar (Tạo mới, Mở file, Lưu file, In/PDF, Undo, Redo), Tên tài liệu, Badge trạng thái lưu ("Đã lưu vào máy"), Window controls.
- **Thanh công cụ Ribbon đa thẻ (4 Thẻ Ribbon)**:
  - **Trang đầu (Home)**:
    - Font Family (Segoe UI, Aptos, Arial, Calibri, Times New Roman, Roboto, Georgia, Courier New), cỡ chữ (11 – 72 pt).
    - Định dạng chữ: **In đậm (B)**, *In nghiêng (I)*, <u>Gạch chân (U)</u>, Gạch ngang chữ, Chỉ số trên/dưới ($X^2$, $X_2$).
    - Bảng màu chữ (Font Color), Bút dạ quang đánh dấu (Text Highlight Color).
    - Căn lề: Căn trái (Left), Căn giữa (Center), Căn phải (Right), Căn đều hai bên (Justify).
    - Giãn dòng, Danh sách dấu đầu dòng (Bullet list), Danh sách đánh số (Numbered list), Danh sách việc cần làm (Task checklist).
    - Kiểu tiêu đề (Headings): Normal, Heading 1, Heading 2, Heading 3.
  - **Chèn (Insert)**:
    - **Bảng biểu (Table)**: Chèn bảng tùy biến, thêm/xóa hàng cột, gộp ô, tách ô, xóa bảng.
    - **Hình ảnh (Image)**: Tải ảnh từ máy tính chèn vào tài liệu, căn chỉnh kích thước.
    - Đường kẻ ngang (Horizontal Divider), Khối trích dẫn (Blockquote), Khối mã nguồn (Code block), Liên kết (Hyperlink).
  - **Bố trí (Layout)**:
    - Căn lề trang (Margins: Bình thường 2.54cm, Thu hẹp 1.27cm, Rộng 3.81cm).
    - Hướng giấy: Dọc (Portrait) / Ngang (Landscape).
  - **Xem (View)**:
    - Chế độ hiển thị Trang in chuẩn A4 / Chế độ đọc toàn màn hình.
    - Thu phóng nhanh (Zoom 50% – 200%).
- **Khung tài liệu (Page View)**: Khổ giấy A4 trắng tinh tế, lề trang chuẩn, bóng đổ drop-shadow như Word thật.
- **Thanh trạng thái (Status Bar)**: Thống kê số trang, tổng số từ (Word count), số ký tự, thời gian đọc ước tính, thanh trượt zoom.

### 2. Đọc & Ghi file chuẩn Microsoft Word (.docx, .pdf)
- **Mở file Word (.docx)**:
  - Bấm nút **Mở (Open)** hoặc **Kéo & thả (Drag and Drop)** trực tiếp file `.docx` từ máy tính vào cửa sổ ứng dụng.
  - Phân tích cú pháp qua `mammoth`, nạp đầy đủ văn bản, kiểu chữ, danh sách, bảng biểu và ảnh nhúng.
- **Lưu file Word (.docx)**:
  - Bấm nút **Lưu (Save)** hoặc phím tắt `Ctrl + S`.
  - Biên dịch nội dung sang file chuẩn OpenXML `.docx` bằng thư viện `docx`, mở được trên Microsoft Word thật 100% không bị lỗi.
- **Xuất file PDF**: Bấm nút **In (Print)** hoặc phím tắt `Ctrl + P` để in hoặc xuất trực tiếp tài liệu sang file `.pdf`.

### 3. Hệ thống phím tắt chuẩn Word
- `Ctrl + S`: Lưu file Word (.docx)
- `Ctrl + O`: Mở file Word từ PC
- `Ctrl + P`: In / Xuất PDF
- `Ctrl + N`: Tạo tài liệu mới
- `Ctrl + B`: In đậm (Bold)
- `Ctrl + I`: In nghiêng (Italic)
- `Ctrl + U`: Gạch chân (Underline)
- `Ctrl + L` / `Ctrl + E` / `Ctrl + R` / `Ctrl + J`: Căn Trái / Giữa / Phải / Đều
- `Ctrl + Z` / `Ctrl + Y`: Hoàn tác (Undo) / Làm lại (Redo)
- `Ctrl + A`: Chọn toàn bộ văn bản

---

## 🧪 KẾT QUẢ KIỂM THỬ VÀ NGHIỆM THU
- **Kiểm thử tự động**: Đạt **27/27 kịch bản kiểm thử PASS 100%** (Xem chi tiết tại [TEST_REPORT.md](file:///c:/workspace/ai_project/doc_app/TEST_REPORT.md)).
- **Thẩm định an ninh & chất lượng**: Đạt chứng nhận **FINAL APPROVAL - PASS 100%** (Xem chi tiết tại [REVIEW_REPORT.md](file:///c:/workspace/ai_project/doc_app/REVIEW_REPORT.md)).
- **Checklist công đoạn**: Đầy đủ 4 công đoạn nghiệm thu tại [CHECKLIST.md](file:///c:/workspace/ai_project/doc_app/CHECKLIST.md).
