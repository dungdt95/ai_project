# PC EXCEL EDITOR (MICROSOFT OFFICE 365 EDITION)

Ứng dụng bảng tính trên máy tính cá nhân (PC Desktop) chuyên dụng để **đọc, chỉnh sửa, tính toán và lưu file Excel (.xlsx)** với giao diện và tính năng tương tự Microsoft Excel 365.

---

## 🚀 HƯỚNG DẪN KHỞI CHẠY ỨNG DỤNG

Thư mục dự án: `c:\workspace\ai_project\excel_app`

### Cách 1: Chạy trực tiếp Gói Portable .EXE (Khuyên dùng nhất - Không cần cài đặt)
- Mở thư mục `release/` và nháy đúp chuột vào:
  👉 **`release\ExcelEditor 1.0.0.exe`** (Gói 81 MB độc lập, mở ngay lập tức, không cần cài đặt bất kỳ môi trường nào).

### Cách 2: Cài đặt vào Windows (NSIS Installer)
- Nháy đúp chuột vào:
  👉 **`release\ExcelEditor Setup 1.0.0.exe`** (Tự động cài đặt 1-click, tạo shortcut ngoài màn hình Desktop và Start Menu).

### Cách 3: Chạy qua Script Desktop (Môi trường dev)
- Nháy đúp chuột vào file: **`run_app.bat`**  
*(Ứng dụng sẽ mở cửa sổ Desktop Windows độc lập với giao diện Microsoft Office 365)*.

### Cách 4: Chạy trên trình duyệt Web Dev
- Nháy đúp chuột vào file: **`run_web.bat`**  
*(Ứng dụng chạy tại địa chỉ `http://localhost:5173`)*.

---

## ✨ CÁC TÍNH NĂNG NỔI BẬT

### 1. Giao diện chuẩn Microsoft Office 365
- **Thanh tiêu đề (TitleBar)**: Tông màu xanh lá chuẩn Office `#107C41`, thanh Quick Access (Tạo mới, Mở file, Lưu file, Undo, Redo), Tên Workbook và Badge trạng thái lưu ("Đã lưu").
- **Thanh công cụ Ribbon với 4 thẻ chức năng**:
  - **Trang đầu (Home)**:
    - Font Family (Segoe UI, Aptos, Arial, Calibri, Times New Roman, Roboto, Consolas), cỡ chữ (8 – 36 pt).
    - Định dạng chữ: **Đậm (B)**, *Nghiêng (I)*, <u>Gạch chân (U)</u>, Gạch ngang chữ.
    - Kẻ viền ô (Borders): Viền tất cả, Viền ngoài dày, Viền dưới đôi, Xóa viền.
    - Màu nền ô (Fill Color Picker), Màu chữ (Font Color Picker).
    - Căn lề: Trái, Giữa, Phải; Trên, Giữa, Dưới.
    - **Gộp ô & Căn giữa (Merge & Center)**.
    - Định dạng số: Số chung (General), Số phân cách hàng nghìn (Number), Tiền tệ VNĐ (`100,000 ₫`), USD (`$100.00`), Phần trăm (%), Ngày tháng.
    - **Tính tổng tự động (AutoSum Σ)** và Sắp xếp A-Z / Z-A.
  - **Chèn (Insert)**: Chèn hàm tính (`fx`), Gộp ô, Tạo sheet mới.
  - **Dữ liệu (Data)**: Nhập file Excel từ máy tính, Xuất file Excel chuẩn `.xlsx`.
  - **Xem (View)**: Tùy chọn phóng to/thu nhỏ (Zoom 50% – 200%).

### 2. Thanh công thức (Formula Bar)
- **Hộp tên (Name Box)**: Hiển thị tọa độ ô đang chọn (A1, B2...); có thể gõ trực tiếp địa chỉ ô bất kỳ và bấm Enter để nhảy tới ô đó.
- Nút xác nhận `✓`, hủy `✗`, và nút **`fx`** mở hộp thoại tra cứu danh mục hàm tính.
- Thanh nhập liệu đồng bộ 2 chiều tức thời với ô tính trên lưới.

### 3. Lưới ô tính (Grid) & Canvas
- Đánh số thứ tự hàng (1, 2, 3...) và cột chữ cái (A, B, C...).
- **Thay đổi kích thước**: Kéo thả vạch kẻ giữa các cột và hàng để mở rộng/thu hẹp kích thước.
- **Chọn vùng (Range Selection)** & **Kéo tự động điền (Auto-fill handle)**: Kéo góc dưới ô để tự động sao chép hoặc tăng tiến chuỗi giá trị.
- **Sửa trực tiếp (Inline Editing)**: Nháy đúp chuột vào ô hoặc bấm phím `F2`.
- **Menu chuột phải (Context Menu)**: Cắt, Sao chép, Dán, Chèn hàng/cột, Xóa hàng/cột, Gộp ô, Xóa nội dung.

### 4. Động cơ công thức (Formula Engine) & Tính toán tự động
- Hỗ trợ đầy đủ các hàm Excel chuẩn:
  - Hàm thống kê & số học: `SUM`, `AVERAGE`, `COUNT`, `MAX`, `MIN`, `PRODUCT`, `ROUND`.
  - Hàm điều kiện & logic: `IF`, `AND`, `OR`.
  - Hàm chuỗi: `CONCATENATE`, `UPPER`, `LOWER`.
  - Hàm tìm kiếm: `VLOOKUP`.
  - Phép tính toán học tự do: `=(A1 + B1) * 1.1`, `=D3 * 10%`, v.v.
- **Cơ chế Reactive Recalculation**: Tự động tính toán lại tất cả các ô phụ thuộc ngay khi thay đổi giá trị nguồn.

### 5. Quản lý Đa Sheet (Multi-sheet Tabs)
- Thanh tab sheet ở góc dưới: Chuyển đổi qua lại giữa các sheet mượt mà.
- Nút **`+`** tạo sheet mới.
- Nháy đúp chuột vào tên tab hoặc nhấp nút để đổi tên sheet (Rename).
- Nút xóa sheet (Xóa an toàn).

### 6. Thanh trạng thái (Status Bar)
- Tự động hiển thị kết quả tính nhanh vùng đang chọn:
  - **Trung bình (Average)**: Giá trị trung bình của các ô số.
  - **Số ô (Count)**: Số lượng ô có dữ liệu.
  - **Tổng cộng (Sum)**: Tổng các giá trị số trong vùng chọn.
- Thanh trượt điều chỉnh thu phóng (Zoom Slider) từ 50% đến 200%.

### 7. Mở và Lưu file Excel (.xlsx) chuẩn 100%
- **Mở file**: Bấm nút **Mở (Open)** hoặc **Kéo & thả (Drag and Drop)** bất kỳ file `.xlsx` từ máy tính vào cửa sổ ứng dụng.
- **Lưu file**: Bấm nút **Lưu (Save)** hoặc phím tắt `Ctrl + S` để xuất ra file `.xlsx` chuẩn tương thích hoàn toàn với Microsoft Excel và Google Sheets.
- Bảo toàn nguyên vẹn 100% công thức, kết quả, kiểu chữ, màu sắc, đường viền borders, căn lề và các ô gộp.

### 8. Hệ thống phím tắt chuẩn Office
- `Ctrl + S`: Lưu file Excel (.xlsx)
- `Ctrl + O`: Mở file Excel từ máy tính
- `Ctrl + C` / `Ctrl + X` / `Ctrl + V`: Sao chép / Cắt / Dán
- `Ctrl + Z` / `Ctrl + Y`: Hoàn tác (Undo) / Làm lại (Redo)
- `Delete` / `Backspace`: Xóa nội dung ô
- `F2`: Sửa nhanh nội dung ô
- `Enter` / `Tab`: Xác nhận hoặc di chuyển sang ô tiếp theo
- `Arrow Keys` (Phím mũi tên): Di chuyển giữa các ô (kết hợp `Shift` để chọn vùng)

---

## 🧪 KẾT QUẢ KIỂM THỬ ĐỘC LẬP
- **Kiểm thử tự động**: Đạt **35/35 Test Cases PASS 100%** (Xem chi tiết tại [TEST_REPORT.md](file:///c:/workspace/ai_project/excel_app/TEST_REPORT.md)).
- **Thẩm định chất lượng & An ninh**: Đạt chuẩn xuất sắc, không lỗ hổng bảo mật IPC (Xem chi tiết tại [REVIEW_REPORT.md](file:///c:/workspace/ai_project/excel_app/REVIEW_REPORT.md)).
- **Checklist nghiệm thu**: Toàn bộ 4 công đoạn đã hoàn tất tại [CHECKLIST.md](file:///c:/workspace/ai_project/excel_app/CHECKLIST.md).
