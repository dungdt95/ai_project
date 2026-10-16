# SPEC — App Chia Hóa Đơn ("ChiaHoaDon")

> Đặc tả chức năng · Phiên bản 1.0 · 2026-10-02
> Stack: Flutter 3.47 + Riverpod + sqflite. **Hoạt động 100% offline, không server, không tài khoản.**

---

## 1. Mục tiêu & bối cảnh

### 1.1 Vấn đề
Khi đi ăn / du lịch / ở ghép, chia tiền thủ công bằng máy tính hoặc Excel gặp các vấn đề:
- Chia đều thì đơn giản nhưng **không công bằng** khi có người gọi món đắt, người không uống bia.
- Có VAT / phí dịch vụ / voucher → không biết phân bổ cho ai bao nhiêu.
- Một người trả trước cho cả nhóm → **không ai nhớ ai còn nợ ai bao nhiêu** sau nhiều lần.
- Không có lịch sử để biết "tháng này mình đã chi bao nhiêu cho nhóm".

### 1.2 Mục tiêu sản phẩm

| # | Mục tiêu | Chỉ số đo |
|---|----------|-----------|
| G1 | Nhập 1 hóa đơn chia đều xong trong **< 30 giây** | Số lần chạm ≤ 8 |
| G2 | Kết quả chia tiền **luôn khớp tuyệt đối** với tổng hóa đơn | `tổng các phần == tổng hóa đơn`, 100% test case |
| G3 | Biết ngay **ai nợ ai bao nhiêu** sau mọi hóa đơn | 1 màn hình "Quyết toán" |
| G4 | Hoạt động hoàn toàn offline, dữ liệu không rời khỏi máy | 0 network permission |
| G5 | Chia sẻ kết quả sang Zalo / Messenger trong 2 chạm | Text + ảnh |

### 1.3 Đối tượng người dùng
- **Người tổ chức (Organizer)** — người nhập hóa đơn, thường là người trả trước. Đây là *người dùng duy nhất* của app (single-user, không đa thiết bị).
- **Thành viên (Member)** — chỉ là dữ liệu trong app, không đăng nhập. Nhận kết quả qua ảnh / text được chia sẻ.

### 1.4 Ngoài phạm vi (Out of scope v1.0)
- Đồng bộ cloud, đăng nhập, nhiều thiết bị cùng sửa.
- Thanh toán thật trong app (chỉ tạo QR chuyển khoản để người dùng tự quét).
- Đa tiền tệ — v1.0 chỉ VND.
- Chia hóa đơn giữa nhiều nhóm lồng nhau.

---

## 2. Thuật ngữ (Glossary)

| Thuật ngữ | Định nghĩa |
|-----------|------------|
| **Thành viên** (Member) | Một người có thể tham gia hóa đơn. Tồn tại độc lập, dùng lại nhiều lần. |
| **Nhóm** (Group) | Tập thành viên hay đi cùng nhau (vd "Team Dev", "Phòng 302"). Dùng để tạo hóa đơn nhanh. |
| **Hóa đơn** (Bill) | Một lần chi tiêu cần chia. Có người trả trước, danh sách người tham gia, cách chia. |
| **Món** (Bill Item) | Một dòng trong hóa đơn (vd "Lẩu thái · 2 × 250.000"). Chỉ dùng khi chia theo món. |
| **Người trả trước** (Payer) | Thành viên đã ứng tiền trả cho cả hóa đơn. Có thể có nhiều người cùng ứng. |
| **Phần phải trả** (Share) | Số tiền một thành viên phải chịu trong 1 hóa đơn. |
| **Số dư ròng** (Net balance) | `(tổng đã ứng trả) − (tổng phải chịu)`. Dương = người khác nợ mình. Âm = mình nợ. |
| **Quyết toán** (Settlement) | Danh sách giao dịch chuyển tiền tối thiểu để mọi số dư ròng về 0. |
| **Đơn vị làm tròn** (Rounding unit) | Bội số tiền nhỏ nhất của kết quả chia: 1đ / 500đ / 1.000đ / 5.000đ. |

---

## 3. Yêu cầu chức năng (Functional Requirements)

### FR-1 — Quản lý thành viên

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-1.1 | Thêm thành viên: **tên (bắt buộc)**, biệt danh, số điện thoại, ghi chú | Must |
| FR-1.2 | Lưu thông tin nhận tiền: tên ngân hàng, số tài khoản, chủ tài khoản — dùng để sinh QR | Must |
| FR-1.3 | Avatar tự sinh: chữ cái đầu + màu nền cố định theo hash tên — không cần upload ảnh | Must |
| FR-1.4 | Sửa / xóa thành viên | Must |
| FR-1.5 | **Không xóa cứng** thành viên đã có trong hóa đơn → chuyển trạng thái *Ngừng hoạt động* (ẩn khỏi danh sách chọn, giữ nguyên lịch sử) | Must |
| FR-1.6 | Đánh dấu 1 thành viên là **"Tôi"** (self) → mặc định là người trả trước, hiển thị nổi bật trong thống kê | Must |
| FR-1.7 | Tìm kiếm thành viên theo tên / biệt danh | Should |
| FR-1.8 | Nhập nhanh nhiều thành viên (mỗi dòng 1 tên) | Should |
| FR-1.9 | Import danh bạ điện thoại | Could — cần quyền READ_CONTACTS, cân nhắc vì trái mục tiêu "offline tối giản" |

**Quy tắc nghiệp vụ**
- Tên thành viên **không nên trùng** (so sánh sau khi trim + bỏ dấu + lowercase) → cảnh báo nhưng vẫn cho lưu nếu người dùng xác nhận (có thể có 2 bạn tên "Anh").
- Phải luôn tồn tại **ít nhất 1** thành viên được đánh dấu "Tôi".

---

### FR-2 — Quản lý nhóm

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-2.1 | Tạo nhóm: tên, mô tả, màu nhận diện, chọn thành viên | Should |
| FR-2.2 | Thêm / bớt thành viên trong nhóm | Should |
| FR-2.3 | Tạo hóa đơn từ nhóm → **tự chọn sẵn toàn bộ thành viên nhóm** | Should |
| FR-2.4 | Xem thống kê riêng theo nhóm | Should |
| FR-2.5 | Xóa nhóm không ảnh hưởng hóa đơn cũ (hóa đơn giữ snapshot danh sách người tham gia) | Must |

---

### FR-3 — Nhập & quản lý hóa đơn

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-3.1 | Tạo hóa đơn: **tên (bắt buộc)**, ngày (mặc định hôm nay), danh mục, ghi chú. **Chọn danh mục là tên hóa đơn được điền theo**, không phải gõ (✅ v1.2) | Must |
| FR-3.2 | Chọn người tham gia: multi-select từ danh sách thành viên, hoặc chọn nhanh cả nhóm, hoặc "chọn tất cả" | Must |
| FR-3.3 | Chọn người trả trước — mặc định là "Tôi" | Must |
| FR-3.4 | **Nhiều người cùng ứng tiền**: mỗi payer ghi số tiền đã ứng; tổng ứng phải bằng tổng hóa đơn | Should |
| FR-3.5 | Nhập tổng tiền trực tiếp (chế độ nhanh, dùng cho chia đều) | Must |
| FR-3.6 | Nhập theo món: tên món, đơn giá, số lượng → tự tính `thành tiền = đơn giá × SL` | Must |
| FR-3.7 | Thêm / sửa / xóa / sắp xếp lại món | Must |
| FR-3.8 | Phụ phí & giảm giá — xem FR-5 | Must |
| FR-3.9 | Đính kèm **ảnh hóa đơn** (chụp hoặc chọn từ thư viện), lưu trong app documents dir | Should |
| FR-3.10 | Lưu nháp (draft) hóa đơn chưa hoàn tất | Should |
| FR-3.11 | Danh sách hóa đơn: sắp xếp theo ngày giảm dần; hiển thị tên / ngày / tổng tiền / số người / trạng thái | Must |
| FR-3.12 | Tìm kiếm theo tên; lọc theo khoảng ngày, nhóm, danh mục, thành viên tham gia, trạng thái | Must |
| FR-3.13 | Sửa hóa đơn → **tính lại toàn bộ** phần chia; cảnh báo nếu đã có người đánh dấu "đã trả" | Must |
| FR-3.14 | Xóa hóa đơn (xác nhận + Undo 5 giây qua SnackBar) | Must |
| FR-3.15 | **Nhân bản hóa đơn** — dùng cho chi phí lặp lại (tiền nhà, internet) | Should |
| FR-3.16 | **Hóa đơn mẫu / định kỳ** (template): lưu cấu hình, 1 chạm tạo hóa đơn tháng mới | Could |
| FR-3.17 | Quét OCR hóa đơn giấy → tự điền danh sách món | Could — on-device ML Kit, vẫn offline |
| FR-3.18 | **Danh sách món đặt sẵn tên và giá**: khai báo một lần, khi nhập hóa đơn chỉ cần chọn | Should · ✅ v1.2 |
| FR-3.19 | Lưu nhanh một món vừa gõ tay vào danh sách món, để lần sau chọn lại | Should · ✅ v1.2 |
| FR-3.20 | **Chia theo món là kiểu mặc định** của hóa đơn mới và đứng đầu dãy nút kiểu chia; mở sheet thêm món **không tự bật bàn phím**, nút "Chọn món có sẵn" là thao tác nổi bật nhất khi đã có món sẵn | Should · ✅ v1.3 |

**Quy tắc nghiệp vụ**
- Hóa đơn phải có **≥ 1 người tham gia** và **tổng tiền > 0** mới lưu được (trừ nháp).
- Khi lưu, hóa đơn **chụp snapshot** danh sách người tham gia — về sau sửa nhóm hoặc ngừng thành viên không làm thay đổi hóa đơn cũ.
- Người trả trước **không bắt buộc** là người tham gia (vd bố trả hộ cho nhóm con) → phần chia của người đó = 0 nhưng vẫn có số dư ròng dương.

---

### FR-4 — Chia tiền (Split Engine)

> Đây là **trái tim của app**. Yêu cầu bất biến: `tổng các phần == tổng hóa đơn`, luôn đúng, mọi trường hợp.

#### FR-4.1 Chia đều (EQUAL) — *Must*
Chia tổng cho số người tham gia.

```
Tổng 1.000.000đ · 3 người · đơn vị làm tròn 1.000đ
→ An 334.000  ·  Bình 333.000  ·  Chi 333.000      (tổng = 1.000.000 ✓)
```

#### FR-4.2 Chia theo món / theo dịch vụ từng người (ITEMIZED) — *Must*
Mỗi món có **giá cho một người** và **danh sách người dùng món đó**. Thành tiền
của món = `giá × số người`; phần của một người = tổng giá các món họ dùng.

```
Phở bò     60.000/người  →  An, Bình        →  60.000 mỗi người  = 120.000
Bún chả    55.000/người  →  Chi             →  55.000            =  55.000
Trà đá      5.000/người  →  An, Bình, Chi   →   5.000 mỗi người  =  15.000
Cà phê     25.000/người  →  An              →  25.000            =  25.000
─────────────────────────────────────────────────────────────────────────
An = 90.000   ·   Bình = 65.000   ·   Chi = 60.000          (Σ = 215.000)
```

> **Giá nhân lên, không chia ra.** Hai người cùng ăn phở thì mỗi người trả
> 60.000đ, tổng món là 120.000đ — không phải mỗi người 30.000đ. Đây là cách
> hiểu tự nhiên của "chia theo giá dịch vụ của từng người": mỗi người trả đúng
> thứ mình gọi.
>
> Hệ quả đáng giá: **không có phép chia nào ở bước này, nên cũng không có phần
> dư**. Mỗi người luôn trả một bội số nguyên của giá món, và tổng các phần luôn
> khớp tuyệt đối với tổng tiền món mà không cần thuật toán phân bổ nào. Largest
> Remainder chỉ còn dùng ở bước phân bổ phụ phí và làm tròn.
>
> Món **cả nhóm cùng chia một suất** (nồi lẩu 500.000đ cho ba người) không
> thuộc kiểu chia này — dùng **chia đều** (FR-4.1), hoặc nhập giá đã chia sẵn
> cho một người.

Chi tiết:
- Mặc định khi thêm món mới: **chọn sẵn tất cả người tham gia hóa đơn** (giảm số chạm).
- Có nút nhanh "Món này của riêng [tên]" và "Chia đều món này cho cả nhóm".
- Mỗi người trong 1 món có thể có **số phần** riêng (vd Bình uống 2 lon bia, An 1 lon → Bình trả gấp đôi). *Ưu tiên: Should.*
- **Không có ô "số lượng" chung cho món**: số lượng nằm ở từng người dưới dạng số phần, vì cùng một món hai người có thể gọi khác số phần nhau.
- Món phải có **ít nhất một người**; số người là một vế của phép nhân nên món không ai dùng thì không có thành tiền. (Split engine vẫn xử lý được món 0 người trong dữ liệu cũ: tính mỗi người tham gia một phần.)
- Có thể **chọn món từ danh sách món đặt sẵn** để khỏi gõ lại tên và giá (FR-3.18).

#### FR-4.3 Chia theo tỷ lệ phần trăm (PERCENTAGE) — *Should*
Mỗi người một %; tổng phải = 100%. UI hiển thị thanh tiến trình và số % còn thiếu / vượt.

#### FR-4.4 Chia theo số phần (SHARES / weight) — *Should*
Mỗi người một số phần. Phổ biến cho tiền nhà (phòng đôi tính 2 phần) hoặc "người ăn ít tính 0,5 phần".

```
Tiền nhà 6.000.000  ·  An 2 phần · Bình 1 phần · Chi 1 phần
→ An 3.000.000  ·  Bình 1.500.000  ·  Chi 1.500.000
```

#### FR-4.5 Chia theo số tiền chỉ định (EXACT) — *Should*
Nhập tay số tiền từng người. Hiển thị **số còn lại chưa phân bổ**; chặn lưu nếu tổng khác tổng hóa đơn, hoặc cho nút "gán phần dư cho người cuối".

#### FR-4.6 Chế độ kết hợp (MIXED) — *Could*
Một số người chia theo món, phần còn lại chia đều. **Hoãn sang v1.1** — UI phức tạp, ít dùng.

**Quy tắc chuyển đổi kiểu chia:** giữ danh sách người tham gia, **xóa** tham số riêng của kiểu cũ (%, weight, exact) sau khi hỏi xác nhận.

---

### FR-5 — Phụ phí, giảm giá & làm tròn

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-5.1 | VAT: nhập theo **% (vd 8%)** hoặc **số tiền tuyệt đối** | Must |
| FR-5.2 | Phí dịch vụ: theo % hoặc số tiền | Must |
| FR-5.3 | Tiền tip / phí khác: số tiền | Should |
| FR-5.4 | Giảm giá / voucher: theo % hoặc số tiền | Must |
| FR-5.5 | Phụ phí & giảm giá **phân bổ theo tỷ lệ** phần chịu gốc của mỗi người | Must |
| FR-5.6 | Tùy chọn phân bổ **chia đều** phụ phí thay vì theo tỷ lệ (vd phí ship 30k chia đều) | Should |
| FR-5.7 | Đơn vị làm tròn cấu hình được: 1đ / 500đ / 1.000đ / 5.000đ — mặc định **1.000đ** | Must |
| FR-5.8 | Cách làm tròn tổng: không / lên / gần nhất — mặc định **lên** | Should |
| FR-5.9 | Hiển thị rõ **chênh lệch do làm tròn** trên màn chi tiết (vd "+500đ do làm tròn") | Must |

#### Thứ tự tính toán (bắt buộc đúng thứ tự này)

```
1.  subtotal      = tổng thành tiền các món   (hoặc tổng nhập tay)
2.  discount      = subtotal × %giảm          (hoặc số tiền giảm)
3.  base          = subtotal − discount
4.  tax           = base × %VAT               (hoặc số tiền VAT)
5.  service       = base × %phí dịch vụ       (hoặc số tiền)
6.  total_exact   = base + tax + service + tip
7.  total         = làm_tròn(total_exact, unit, mode)
8.  ratio_i       = phần_gốc_i / tổng_phần_gốc        ← theo kiểu chia FR-4
9.  share_exact_i = ratio_i × total
10. share_i       = largest_remainder(share_exact, total, unit)
```

> ⚠️ **Lưu ý triển khai**: VAT và phí dịch vụ tính trên `base` (**sau** giảm giá) — đúng chuẩn hóa đơn Việt Nam. Nếu nhà hàng tính VAT trước giảm giá, người dùng nhập VAT dạng số tiền tuyệt đối.

#### Thuật toán phân bổ: Largest Remainder (Hamilton)

Đảm bảo `tổng share_i == total` **tuyệt đối**, không bao giờ lệch:

```
unit        = đơn vị làm tròn
floor_i     = floor(share_exact_i / unit) × unit
distributed = tổng floor_i
remainder   = total − distributed          // luôn là bội của unit, ≥ 0
k           = remainder / unit             // số người được +1 unit

sắp xếp i theo (share_exact_i − floor_i) GIẢM DẦN
   đồng hạng → ưu tiên share_exact lớn hơn
   vẫn đồng hạng → theo thứ tự thêm vào hóa đơn (ổn định, tái lập được)

cộng thêm `unit` cho k người đầu tiên
```

**Ví dụ kiểm chứng** — hóa đơn FR-4.2 + VAT 8% + phí DV 5%, unit 1.000đ, làm tròn lên:

| Bước | Giá trị |
|------|---------|
| subtotal | 215.000 |
| VAT 8% | 17.200 |
| Phí DV 5% | 10.750 |
| total_exact | 242.950 |
| total (làm tròn lên 1.000đ) | **243.000** |

| Người | Phần gốc | ratio | share_exact | floor | phần dư | Kết quả |
|-------|----------|-------|-------------|-------|---------|---------|
| An | 90.000 | 0,418605 | 101.721 | 101.000 | 721 | **102.000** |
| Bình | 65.000 | 0,302326 | 73.465 | 73.000 | 465 | 73.000 |
| Chi | 60.000 | 0,279070 | 67.814 | 67.000 | 814 | **68.000** |
| | | | | *241.000* | *k = 2* | **243.000 ✓** |

Chi có phần dư lớn nhất (814) nên được cộng trước, rồi tới An (721). Bình có
phần dư nhỏ nhất nên giữ nguyên.

> Ví dụ này được cài thành test `★ Ví dụ kiểm chứng của SPEC §FR-5` trong
> `test/domain/split/split_engine_test.dart`, đối chiếu từng con số ở bảng trên.

---

### FR-6 — Thanh toán & quyết toán

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-6.1 | Đánh dấu **từng thành viên** trong 1 hóa đơn: *Chưa trả / Đã trả / Trả một phần* (ghi số tiền đã trả) | Must |
| FR-6.2 | Trạng thái hóa đơn tự suy ra: *Chưa thanh toán / Một phần / Đã xong* | Must |
| FR-6.3 | Nút "Đánh dấu tất cả đã trả" | Should |
| FR-6.4 | **Số dư ròng** từng thành viên trên toàn bộ hóa đơn: `đã ứng − phải chịu` | Must |
| FR-6.5 | Màn **Quyết toán**: gợi ý danh sách chuyển tiền **tối thiểu** để mọi số dư về 0 | Should |
| FR-6.6 | Ghi nhận giao dịch trả tiền độc lập (A chuyển B 200k, không gắn hóa đơn nào) | Should |
| FR-6.7 | Sinh **QR chuyển khoản VietQR** từ STK thành viên + số tiền → quét bằng app bank | Could · ✅ v1.1 |

#### Thuật toán tối thiểu hóa giao dịch (Debt Simplification)

Greedy — luôn ghép người nợ nhiều nhất với người cho nợ nhiều nhất:

```
balance[m] = tổng(m đã ứng trả) − tổng(m phải chịu)      // tổng balance == 0

debtors   = { m : balance[m] < 0 }   (max-heap theo |balance|)
creditors = { m : balance[m] > 0 }   (max-heap theo balance)

while cả hai heap còn phần tử:
    d = pop(debtors);  c = pop(creditors)
    amount = min(|balance[d]|, balance[c])
    ghi nhận giao dịch:  d → c : amount
    cập nhật 2 số dư; đẩy lại vào heap nếu còn khác 0
```

Cho ra **tối đa n−1 giao dịch** với n thành viên có số dư khác 0.

```
Ví dụ:  An +500k  ·  Bình −300k  ·  Chi −200k
→ Bình chuyển An 300.000
→ Chi  chuyển An 200.000          (2 giao dịch thay vì 4)
```

---

### FR-7 — Thống kê & báo cáo

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-7.1 | **Tổng chi phí của từng thành viên** trên toàn bộ lịch sử | Must |
| FR-7.2 | **Chi phí từng lần theo mỗi hóa đơn** của 1 thành viên — dòng thời gian: ngày · tên hóa đơn · số tiền · đã trả? | Must |
| FR-7.3 | Bộ lọc thời gian: tháng này / tháng trước / 3 tháng / năm nay / khoảng ngày tùy chọn | Must |
| FR-7.4 | Bảng xếp hạng thành viên theo tổng chi (giảm dần) + biểu đồ cột | Must |
| FR-7.5 | Biểu đồ tròn: tỷ trọng chi phí theo thành viên | Should |
| FR-7.6 | Biểu đồ cột: tổng chi theo tháng, 12 tháng gần nhất | Should |
| FR-7.7 | Thống kê theo danh mục (Ăn uống / Du lịch / Nhà cửa / Khác) | Should |
| FR-7.8 | Chỉ số trên Dashboard: tổng chi tháng này · số hóa đơn · tiền người khác đang nợ tôi · tiền tôi đang nợ | Must |
| FR-7.9 | Chi tiêu bình quân / hóa đơn · hóa đơn lớn nhất · thành viên đi cùng nhiều nhất | Could |
| FR-7.10 | Thống kê theo nhóm | Should |
| FR-7.11 | **Báo cáo theo tuần**: lọc kỳ theo tuần, và biểu đồ gộp theo tuần | Should · ✅ v1.2 |
| FR-7.12 | **Mọi kỳ thống kê đều ghi rõ khoảng ngày** ("Tuần này · 28/09 – 04/10/2026") | Should · ✅ v1.2 |
| FR-7.13 | **Chi phí từng người theo danh mục**: chọn danh mục ở một ô thả xuống, bên dưới liệt kê từng thành viên đã chi trong danh mục đó — số tiền, số hóa đơn, tỷ trọng | Should · ✅ v1.3 |
| FR-7.14 | **Ẩn bớt thành viên** khỏi báo cáo FR-7.13, có thể hiện lại | Should · ✅ v1.3 |

**FR-7.13 — các ràng buộc**

- Ô thả xuống luôn có mục **"Tất cả danh mục"** đứng đầu và là mặc định; các mục
  sau là những danh mục **có phát sinh trong kỳ**, kể cả nhóm "Chưa phân loại".
  Đổi kỳ mà danh mục đang chọn không còn hóa đơn nào thì quay về "tất cả".
- Cộng `share_amount` (số cuối cùng sau phụ phí và làm tròn), **không** cộng đơn
  giá món. Nhờ vậy ở mục "tất cả danh mục", số của mỗi người **luôn khớp** tổng
  chi của người đó ở bảng xếp hạng FR-7.1 — hai con số lệch nhau thì người dùng
  không biết tin cái nào.
- Hóa đơn chưa chọn danh mục vẫn được tính, gom vào **"Chưa phân loại"**. Bỏ qua
  là làm mất tiền khỏi báo cáo.
- Tỷ trọng tính **trong phạm vi danh mục đang chọn**, không phải trên tổng cả
  nhóm: câu hỏi ở đây là "ai chiếm bao nhiêu phần của khoản này".

**FR-7.14 — các ràng buộc**

- Người bị ẩn ra khỏi **cả tổng** của mục FR-7.13, không chỉ khỏi danh sách —
  nếu còn trong tổng thì các phần trăm cộng lại không thành 100%.
- Chỉ ảnh hưởng mục FR-7.13. Bảng xếp hạng, biểu đồ tròn và ô tổng chi của nhóm
  **giữ nguyên**: ẩn một người khỏi mọi con số sẽ làm tổng trên màn hình không
  còn khớp tổng thật của nhóm.
- Màn hình luôn nói rõ đang ẩn mấy người và có nút **"Hiện lại"**. Một bộ lọc
  không nhìn thấy được là cách chắc nhất để người dùng đọc sai số liệu.
- Trạng thái ẩn chỉ sống trong phiên làm việc, không lưu xuống DB.

---

### FR-8 — Chia sẻ, xuất & sao lưu

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-8.1 | Chia sẻ kết quả chia tiền dạng **text đẹp** sang Zalo / Messenger / SMS | Must |
| FR-8.2 | Chia sẻ dạng **ảnh PNG** (render widget → ảnh) — dễ đọc trên chat | Should |
| FR-8.3 | Xuất CSV: mỗi người trong mỗi hóa đơn một dòng, mở được bằng Excel | Should · ✅ v1.1 |
| FR-8.4 | **Sao lưu toàn bộ** ra 1 file `.json` → lưu vào Downloads / Drive bằng share sheet | Must |
| FR-8.5 | **Phục hồi** từ file sao lưu (ghi đè hoặc gộp, có xác nhận) | Must |
| FR-8.6 | Nhắc sao lưu nếu > 30 ngày chưa backup | Could |
| FR-8.7 | **Chia sẻ báo cáo theo danh mục** (FR-7.13) dạng bảng markdown hoặc ảnh PNG, nhắm tới Mattermost | Should · ✅ v1.3 |
| FR-8.8 | **Mã QR nhận tiền trong ảnh chia sẻ**, hiện cạnh số tài khoản: ảnh hóa đơn dùng QR của người trả trước, ảnh báo cáo theo danh mục dùng QR của "Tôi" | Should · ✅ v1.3 |

**Mẫu text chia sẻ (FR-8.1)**

```
🧾 Ăn trưa văn phòng — 02/10/2026
Tổng: 243.000đ (gồm VAT 8% + phí DV 5%)
Trả trước: Dũng

• An     102.000đ
• Bình    73.000đ
• Chi     68.000đ

💸 Chuyển khoản: Dũng · Vietcombank · 0123456789
```

**FR-8.7 — các ràng buộc**

- Đi qua **bảng chia sẻ của hệ điều hành** (`ACTION_SEND`), app **không** tự kết
  nối tới Mattermost. Đây là điều kiện để giữ NFR-1: bản phát hành vẫn không xin
  quyền mạng. Muốn app tự đăng bài thì phải thêm `INTERNET` và viết lại NFR-1 —
  một quyết định khác hẳn, không nằm trong FR này.
- Text dùng **markdown** (Mattermost render bảng), khác FR-8.1 vốn cố tình tránh
  markdown vì Zalo/Messenger không hiểu. Cột tiền canh phải.
- Nội dung luôn ghi **kỳ nào** (khoảng ngày theo FR-7.12) và **dòng tổng**:
  người nhận không mở app nên không thấy app đang lọc gì.
- Đang ẩn người (FR-7.14) thì phải ghi rõ "Đang ẩn N người" trong nội dung gửi
  đi. Gửi một báo cáo đang lọc mà im lặng là để người đọc hiểu sai về tiền.
- Không còn ai trong danh sách thì **tắt** nút chia sẻ, thay vì gửi bảng rỗng.
- Thêm nút **chép nội dung**: Mattermost trên máy tính thì dán nhanh hơn là gửi
  qua điện thoại.

**FR-8.8 — các ràng buộc**

- QR là **QR tĩnh, không điền số tiền**. Mỗi người trong hóa đơn nợ một số khác
  nhau mà ảnh chỉ có một mã; điền tổng hay phần của một người thì những người
  còn lại quét ra sai tiền. Người quét tự nhập phần của mình, đọc ngay trong
  danh sách phía trên mã. Nội dung chuyển khoản là tên hóa đơn (bỏ dấu, FR-6.7).
- Chỉ dựng khi người trả trước có **cả ngân hàng lẫn số tài khoản**. Thiếu ngân
  hàng thì không có mã BIN, mà đoán BIN là chuyển nhầm sang ngân hàng khác.
- Số tài khoản bằng chữ **luôn có** kèm QR: không phải máy nào cũng quét được
  mã từ một tấm ảnh trong khung chat.
- Mã nằm trên nền trắng có viền đệm cố định, không theo theme, để quét được kể
  cả khi ảnh nằm trên nền chat tối.
- Người trả trước đã có tài khoản mà chưa chọn ngân hàng thì màn xem trước nhắc
  lý do thiếu QR. Lời nhắc nằm **ngoài** vùng được chụp: nó dành cho người gửi.
- **Người nhận tiền**: ảnh hóa đơn lấy người trả trước. Ảnh báo cáo (FR-8.7)
  không có người trả trước nên lấy **"Tôi"** — người đang cầm máy chia sẻ báo cáo
  để thu tiền. Nội dung chuyển khoản là tên danh mục đang xem.
- Ảnh báo cáo thiếu thông tin nhận tiền thì màn xem trước **luôn nhắc** (khác ảnh
  hóa đơn chỉ nhắc khi đã có tài khoản mà thiếu ngân hàng): người dùng chủ động
  bấm chia sẻ để đi thu tiền, nên bỏ khối QR trong im lặng là sai.
- Chỉ áp dụng cho **ảnh**. Bản text (FR-8.1, FR-8.7) không nhúng được mã.

---

### FR-9 — Cài đặt & tiện ích

| ID | Yêu cầu | Ưu tiên |
|----|---------|---------|
| FR-9.1 | Giao diện **tiếng Việt**; tiền `1.234.567 đ`; ngày `dd/MM/yyyy` | Must |
| FR-9.2 | Sáng / Tối / Theo hệ thống | Must |
| FR-9.3 | Cấu hình đơn vị làm tròn & cách làm tròn mặc định | Must |
| FR-9.4 | Quản lý danh mục hóa đơn (thêm / sửa / xóa) | Should |
| FR-9.5 | Khóa app bằng vân tay / FaceID / PIN (`local_auth`) | Could |
| FR-9.6 | Xóa toàn bộ dữ liệu (nhập chữ xác nhận) | Should |
| FR-9.7 | Bàn phím số có nút tính nhanh `+ − × ÷` khi nhập tiền | Could |
| FR-9.8 | Haptic feedback khi chọn người tham gia | Could |
| FR-9.9 | Quản lý danh sách món đặt sẵn (thêm / sửa / xóa) | Should · ✅ v1.2 |

---

## 4. Yêu cầu phi chức năng (NFR)

| ID | Yêu cầu | Ngưỡng |
|----|---------|--------|
| NFR-1 | **Offline tuyệt đối** — không khai báo quyền INTERNET trong `AndroidManifest.xml` | 0 network call |
| NFR-2 | Thời gian khởi động lạnh | < 2 giây |
| NFR-3 | Danh sách 1.000 hóa đơn cuộn mượt — `ListView.builder` + phân trang 50/lần | ≥ 55 FPS |
| NFR-4 | Tính lại split khi sửa input — tính đồng bộ, không cần async | < 16 ms (1 frame) |
| NFR-5 | Dung lượng APK | < 30 MB (không OCR) · < 60 MB (có OCR) |
| NFR-6 | Số tiền lưu dưới dạng **`int` (đơn vị đồng)** — tuyệt đối không dùng `double` cho tiền | 0 lỗi làm tròn |
| NFR-7 | Độ phủ test cho split engine | ≥ 90% line coverage |
| NFR-8 | Hỗ trợ Android | API 23+ (Android 6.0+) |
| NFR-9 | Màn hình nhỏ nhất hỗ trợ | 360 × 640 dp |
| NFR-10 | Không mất dữ liệu khi app bị kill giữa lúc nhập | Auto-save draft mỗi 3 giây |

---

## 5. Ràng buộc kỹ thuật quan trọng

1. **Tiền là số nguyên.** Mọi số tiền lưu `INTEGER` = số đồng. Chia tiền dùng `int` + phần dư, hoặc tỷ số hữu tỷ (tử/mẫu) cho `ratio` để tránh sai số `double`. Chỉ convert sang `double` ở bước cuối khi vẽ biểu đồ.
2. **Snapshot thay vì tham chiếu.** `bill_participants` lưu thêm `member_name_snapshot` để hóa đơn cũ vẫn đọc được tên dù thành viên bị đổi tên.
3. **Idempotent recalculation.** `computeSplit(BillInput) → SplitResult` là **pure function** — không side effect, không đọc DB → test dễ, chạy lại bao nhiêu lần cũng cùng kết quả.
4. **Soft delete.** Thành viên và hóa đơn dùng `deleted_at` thay vì xóa cứng → cho phép Undo và không vỡ khóa ngoại.
5. **Không có network layer.** Không thêm `http`, `dio`, Firebase hay bất kỳ package cần internet.
