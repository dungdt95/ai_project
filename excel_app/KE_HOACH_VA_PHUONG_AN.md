# KẾ HOẠCH & BÁO CÁO PHÂN TÍCH: XÂY DỰNG ỨNG DỤNG EXCEL TRÊN PC

- **Dự án**: PC Excel Editor (Ứng dụng đọc và chỉnh sửa bảng tính Excel trên PC)
- **Thư mục lưu trữ**: `c:\workspace\ai_project\excel_app`
- **Ngày lập**: 21/11/2026

---

## 1. KẾT QUẢ KHẢO SÁT MÔI TRƯỜNG MÁY TÍNH HIỆN TẠI

Qua rà soát hệ thống, môi trường hiện tại ghi nhận các công cụ sau:
- **Hệ điều hành**: Windows 64-bit
- **Đã có sẵn**:
  - `Microsoft Edge WebView2 Runtime`: Đã cài sẵn (phiên bản 157.x)
  - `Git`: Phiên bản 2.56.0
  - `Visual Studio Code`: Đã cài đặt
  - `Flutter SDK`: Đã có tại `C:\dev\flutter`
  - `Java JDK 17`: Đã có tại `C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot`
- **Chưa có**:
  - `Node.js / npm`: Chưa được cài đặt
  - `Python`: Chưa được cài đặt (chỉ có alias mặc định của Windows)
  - `Visual Studio C++ Build Tools` (cần thiết nếu muốn build native C++/Flutter Windows)

---

## 2. PHÂN TÍCH YÊU CẦU: "CÓ CHỨC NĂNG TƯƠNG TỰ EXCEL"

Để một ứng dụng đạt tiêu chuẩn "tương tự Excel", hệ thống bắt buộc phải giải quyết các bài toán sau:
1. **Giao diện lưới ô tính (Data Grid / Canvas)**:
   - Hiển thị hàng số (1, 2, 3...) và cột chữ cái (A, B, C...).
   - Thao tác chọn ô (single cell), chọn vùng (range selection), kéo thả vùng dữ liệu (auto-fill handle).
   - Kéo giãn độ rộng cột, chiều cao hàng; ẩn/hiện hàng và cột.
2. **Hệ thống công thức (Formula Engine)**:
   - Thanh công thức (Formula Bar) nhập liệu trực quan.
   - Hỗ trợ các hàm thông dụng: `SUM`, `AVERAGE`, `COUNT`, `IF`, `VLOOKUP`, `INDEX`, `MATCH`, `MAX`, `MIN`...
   - Tự động cập nhật giá trị các ô phụ thuộc khi ô nguồn thay đổi (Dependency graph).
3. **Định dạng dữ liệu & Trực quan hóa (Formatting)**:
   - Kiểu chữ (Font, Size, Bold, Italic, Underline), màu chữ, màu nền (Fill Color).
   - Kẻ khung (Border: All, Outer, Top, Bottom...).
   - Định dạng số: Số nguyên, số thập phân, tiền tệ, phần trăm, ngày tháng.
   - Gộp ô (Merge cells), canh lề (Trái, Giữa, Phải, Trên, Dưới, Wrap text).
4. **Quản lý Sheet (Multi-sheet tabs)**:
   - Thêm, sửa tên, đổi màu tab, xóa, sao chép sheet.
5. **Đọc & Ghi file Excel chuẩn**:
   - Mở và import file `.xlsx`, `.xls`, `.csv`.
   - Xuất (Export) và Lưu (Save / Save As) file `.xlsx` giữ nguyên công thức và định dạng.
6. **Tiện ích người dùng**:
   - Phím tắt chuẩn Excel (Ctrl+C, Ctrl+V, Ctrl+Z, Ctrl+Y, F2 sửa ô, Delete...).
   - Tìm kiếm và thay thế (Find & Replace).
   - Sắp xếp và Lọc dữ liệu (Sort & Filter).

---

## 3. ĐÁNH GIÁ CÁC PHƯƠNG ÁN CÔNG NGHỆ

### Phương án 1: Electron / WebView2 + Univer Sheet (Khuyên dùng - Tối ưu nhất)
- **Công nghệ**: Electron (hoặc WebView2 Wrapper) kết hợp lõi bảng tính **Univer** (thế hệ kế thừa vượt trội của Luckysheet) hoặc **FortuneSheet**.
- **Ưu điểm**:
  - Giao diện và trải nghiệm giống **Microsoft Excel / Google Sheets tới 95%** ngay khi khởi tạo.
  - Tích hợp sẵn Formula Engine với hơn 300 hàm chuẩn Excel.
  - Hỗ trợ canvas rendering hiệu năng cao (xử lý hàng chục nghìn dòng không giật lag).
  - Tương thích phím tắt, copy/paste trực tiếp từ Excel máy tính vào app và ngược lại.
  - Tích hợp import/export file `.xlsx` hoàn chỉnh.
- **Yêu cầu cài thêm**: **Node.js LTS (v20 hoặc v22)**.

### Phương án 2: Flutter Desktop Windows
- **Công nghệ**: Flutter Desktop (C++ Runner + Dart).
- **Ưu điểm**: Máy đã có sẵn Flutter SDK.
- **Nhược điểm**:
  - Dart/Flutter chưa có bộ mã nguồn mở bảng tính toàn diện như Excel. Các thư viện hiện có (`pluto_grid`, `syncfusion_flutter_datagrid`) chủ yếu là bảng hiển thị dữ liệu (DataGrid) chứ không phải ứng dụng tính toán spreadsheet.
  - Tự xây dựng Formula Engine, xử lý gộp ô động, thanh công thức và vẽ border phức tạp tốn rất nhiều thời gian và dễ phát sinh lỗi.
- **Yêu cầu cài thêm**: Visual Studio 2022 Community (workload C++ Desktop Development - dung lượng khoảng 7-10 GB).

### Phương án 3: Python Desktop App (PyQt6 + openpyxl)
- **Công nghệ**: PyQt6 / PySide6 + QTableWidget / QTableView + thư viện `openpyxl`.
- **Ưu điểm**: Xử lý dữ liệu Excel bằng Python rất mạnh mẽ.
- **Nhược điểm**: `QTableWidget` mặc định có trải nghiệm người dùng rất cứng nhắc, không hỗ trợ sẵn thanh công thức tương tác thời gian thực, khó đạt độ mượt và tính năng tương tự Excel.
- **Yêu cầu cài thêm**: Python 3.12 + PyQt6 + openpyxl.

---

## 4. KẾ HOẠCH TRIỂN KHAI THEO PHƯƠNG ÁN TỐI ƯU (PHƯƠNG ÁN 1)

| Giai đoạn | Nội dung công việc | Kết quả đầu ra |
|---|---|---|
| **Giai đoạn 1: Chuẩn bị công cụ** | Cài đặt **Node.js LTS** lên máy tính (tải từ nodejs.org hoặc winget) | Có lệnh `node -v` và `npm -v` |
| **Giai đoạn 2: Thiết lập khung ứng dụng** | Khởi tạo dự án Desktop trong `c:\workspace\ai_project\excel_app` với khung Electron + React + Univer Core | Ứng dụng Desktop mở lên có sẵn giao diện lưới bảng tính |
| **Giai đoạn 3: Tích hợp Đọc/Ghi file Excel** | Xây dựng chức năng: Kéo thả file, Menu "Mở file Excel (.xlsx)" và "Lưu file (.xlsx)" | Mở được file Excel có sẵn trên PC và chỉnh sửa |
| **Giai đoạn 4: Hoàn thiện tính năng Excel** | Bổ sung thanh công cụ Ribbon (Format, Font, Color, Border), thanh Formula Bar, quản lý Sheet tab, Undo/Redo | Trải nghiệm tương tự Excel hoàn chỉnh |
| **Giai đoạn 5: Đóng gói ứng dụng PC** | Đóng gói thành file chạy `.exe` độc lập cho Windows | File cài đặt hoặc `.exe` chạy trực tiếp trên PC |

---

## 5. HÀNH ĐỘNG CẦN THỰC HIỆN TIẾP THEO

- Cài đặt **Node.js LTS** (chỉ cần 1 công cụ này duy nhất để bắt đầu dựng app).
- Sau khi cài đặt Node.js, tiến hành tạo dự án và dựng giao diện ứng dụng ngay tại thư mục `excel_app`.
