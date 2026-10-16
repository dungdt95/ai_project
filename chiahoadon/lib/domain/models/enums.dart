/// Các kiểu liệt kê được lưu xuống DB dưới dạng chuỗi.
///
/// Mỗi enum có `dbValue` và hàm `fromDb` với giá trị mặc định an toàn, để một
/// bản ghi cũ hoặc tệp sao lưu từ phiên bản khác không làm app crash.
library;

/// Cách chia tiền (SPEC FR-4).
enum SplitType {
  /// Chia theo món, mỗi món có danh sách người dùng riêng.
  ///
  /// Đứng **đầu** danh sách vì là cách dùng chính: chọn món có sẵn rồi chọn
  /// người, không phải gõ gì. Thứ tự khai báo ở đây cũng là thứ tự các nút ở
  /// màn tạo hóa đơn; DB lưu `dbValue` chứ không lưu chỉ số nên đổi thứ tự an
  /// toàn.
  itemized('itemized', 'Theo món'),

  /// Chia đều cho số người tham gia.
  equal('equal', 'Chia đều'),

  /// Mỗi người một tỷ lệ phần trăm.
  percentage('percentage', 'Theo %'),

  /// Mỗi người một số phần.
  shares('shares', 'Theo số phần'),

  /// Nhập tay số tiền từng người.
  exact('exact', 'Số tiền cụ thể');

  const SplitType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static SplitType fromDb(String? value) => values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => SplitType.equal,
  );

  /// Kiểu chia này có cần danh sách món hay không.
  bool get needsItems => this == SplitType.itemized;
}

/// Cách nhập số tiền của hóa đơn.
enum InputMode {
  /// Nhập trực tiếp tổng tiền (chế độ nhanh).
  total('total'),

  /// Nhập từng món, tổng được tính ra.
  items('items');

  const InputMode(this.dbValue);

  final String dbValue;

  static InputMode fromDb(String? value) => values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => InputMode.total,
  );
}

/// Cách khai báo một khoản phụ phí hoặc giảm giá (SPEC FR-5).
enum SurchargeMode {
  /// Không áp dụng.
  none('none'),

  /// Theo phần trăm, giá trị lưu dạng basis point (8% = 800).
  percent('percent'),

  /// Theo số tiền tuyệt đối, đơn vị đồng.
  amount('amount');

  const SurchargeMode(this.dbValue);

  final String dbValue;

  static SurchargeMode fromDb(String? value) => values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => SurchargeMode.none,
  );
}

/// Cách phân bổ phụ phí cho từng người (SPEC FR-5.5, FR-5.6).
enum SurchargeAlloc {
  /// Theo tỷ lệ phần chịu gốc — mặc định, đúng bản chất VAT.
  proportional('proportional', 'Theo tỷ lệ'),

  /// Chia đều cho mọi người tham gia — phù hợp phí ship, phí thuê phòng.
  equal('equal', 'Chia đều');

  const SurchargeAlloc(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static SurchargeAlloc fromDb(String? value) => values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => SurchargeAlloc.proportional,
  );
}

/// Cách làm tròn tổng hóa đơn (SPEC FR-5.8).
enum RoundingMode {
  /// Giữ nguyên số lẻ.
  none('none', 'Không làm tròn'),

  /// Làm tròn lên bội số gần nhất — mặc định, thực tế hay dùng.
  up('up', 'Làm tròn lên'),

  /// Làm tròn tới bội số gần nhất.
  nearest('nearest', 'Làm tròn gần nhất');

  const RoundingMode(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static RoundingMode fromDb(String? value) => values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => RoundingMode.up,
  );
}

/// Trạng thái thanh toán của hóa đơn (SPEC FR-6.2).
enum BillStatus {
  /// Chưa hoàn tất nhập, không tính vào thống kê.
  draft('draft', 'Nháp'),

  /// Chưa ai trả.
  unpaid('unpaid', 'Chưa thanh toán'),

  /// Một số người đã trả.
  partial('partial', 'Trả một phần'),

  /// Mọi người đã trả xong.
  settled('settled', 'Đã xong');

  const BillStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static BillStatus fromDb(String? value) => values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => BillStatus.unpaid,
  );

  /// Hóa đơn nháp bị loại khỏi mọi truy vấn thống kê (PLAN §4.4).
  bool get countsInStats => this != BillStatus.draft;
}

/// Hình thức chuyển tiền (SPEC FR-6.6).
enum PaymentMethod {
  cash('cash', 'Tiền mặt'),
  transfer('transfer', 'Chuyển khoản'),
  other('other', 'Khác');

  const PaymentMethod(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PaymentMethod fromDb(String? value) => values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => PaymentMethod.transfer,
  );
}

/// Trạng thái trả tiền của một người trong một hóa đơn.
enum ParticipantPaymentStatus {
  unpaid('Chưa trả'),
  partial('Trả một phần'),
  paid('Đã trả');

  const ParticipantPaymentStatus(this.label);

  final String label;
}
