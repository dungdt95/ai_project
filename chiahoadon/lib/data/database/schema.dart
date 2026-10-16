/// Lược đồ cơ sở dữ liệu, phiên bản 1 (PLAN §4.2).
///
/// Giữ DDL ở dạng chuỗi SQL thay vì qua ORM để:
/// - đối chiếu trực tiếp được với PLAN.md khi review;
/// - viết được các truy vấn thống kê phức tạp bằng SQL thuần (PLAN §4.4);
/// - không cần bước sinh mã (build_runner) trong vòng lặp phát triển.
class Schema {
  const Schema._();

  /// Thứ tự trong danh sách này là thứ tự chạy: bảng cha trước bảng con, để
  /// khóa ngoại luôn trỏ tới bảng đã tồn tại.
  static const List<String> createStatements = [
    _members,
    _memberGroups,
    _groupMembers,
    _categories,
    _bills,
    _billPayers,
    _billParticipants,
    _billItems,
    _billItemParticipants,
    _payments,
    _billTemplates,
    _itemPresets,
    _appSettings,
  ];

  static const List<String> createIndexes = [
    // members
    'CREATE INDEX idx_members_norm ON members(name_norm)',
    'CREATE INDEX idx_members_active ON members(is_active, deleted_at)',
    // Chỉ cho phép đúng một thành viên được đánh dấu "Tôi" (SPEC FR-1.6).
    'CREATE UNIQUE INDEX idx_members_self ON members(is_self) WHERE is_self = 1',

    // nhóm
    'CREATE INDEX idx_gm_member ON group_members(member_id)',

    // hóa đơn
    'CREATE INDEX idx_bills_date ON bills(bill_date DESC)',
    'CREATE INDEX idx_bills_title_norm ON bills(title_norm)',
    'CREATE INDEX idx_bills_status ON bills(status, deleted_at)',
    'CREATE INDEX idx_bills_group ON bills(group_id)',
    'CREATE INDEX idx_bills_category ON bills(category_id)',

    // danh sách món đặt sẵn
    'CREATE INDEX idx_item_presets_norm ON item_presets(name_norm)',

    // người ứng tiền & người tham gia
    'CREATE INDEX idx_payers_member ON bill_payers(member_id)',
    'CREATE INDEX idx_bp_bill ON bill_participants(bill_id)',
    'CREATE INDEX idx_bp_member ON bill_participants(member_id)',

    // món
    'CREATE INDEX idx_items_bill ON bill_items(bill_id, sort_order)',
    'CREATE INDEX idx_iip_member ON bill_item_participants(member_id)',

    // chuyển tiền
    'CREATE INDEX idx_payments_from ON payments(from_member_id)',
    'CREATE INDEX idx_payments_to ON payments(to_member_id)',
    'CREATE INDEX idx_payments_bill ON payments(bill_id)',
  ];

  // ─────────────────────────── THÀNH VIÊN ───────────────────────────

  static const String _members = '''
    CREATE TABLE members (
      id            TEXT PRIMARY KEY,
      name          TEXT    NOT NULL,
      name_norm     TEXT    NOT NULL,
      nickname      TEXT,
      phone         TEXT,
      bank_name     TEXT,
      bank_bin      TEXT,
      bank_account  TEXT,
      bank_holder   TEXT,
      avatar_color  INTEGER NOT NULL,
      note          TEXT,
      is_self       INTEGER NOT NULL DEFAULT 0,
      is_active     INTEGER NOT NULL DEFAULT 1,
      created_at    INTEGER NOT NULL,
      updated_at    INTEGER NOT NULL,
      deleted_at    INTEGER
    )
  ''';

  // ───────────────────────────── NHÓM ──────────────────────────────
  // Tên bảng là `member_groups`, không phải `groups`: GROUPS là từ khóa của
  // SQLite từ 3.28 (hàm cửa sổ) và sẽ gây lỗi cú pháp.

  static const String _memberGroups = '''
    CREATE TABLE member_groups (
      id          TEXT PRIMARY KEY,
      name        TEXT    NOT NULL,
      description TEXT,
      color       INTEGER NOT NULL,
      created_at  INTEGER NOT NULL,
      updated_at  INTEGER NOT NULL,
      deleted_at  INTEGER
    )
  ''';

  static const String _groupMembers = '''
    CREATE TABLE group_members (
      group_id  TEXT NOT NULL REFERENCES member_groups(id) ON DELETE CASCADE,
      member_id TEXT NOT NULL REFERENCES members(id)       ON DELETE CASCADE,
      PRIMARY KEY (group_id, member_id)
    )
  ''';

  // ──────────────────────────── DANH MỤC ───────────────────────────

  static const String _categories = '''
    CREATE TABLE categories (
      id         TEXT PRIMARY KEY,
      name       TEXT    NOT NULL,
      icon       TEXT,
      color      INTEGER NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_builtin INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // ──────────────────────────── HÓA ĐƠN ────────────────────────────
  // `*_mode`  : none | percent | amount
  // `*_value` : basis point nếu percent (8% = 800), số đồng nếu amount
  // `*_amount`: số tiền đã tính ra, luôn là đồng

  static const String _bills = '''
    CREATE TABLE bills (
      id                TEXT PRIMARY KEY,
      title             TEXT    NOT NULL,
      -- Tên đã bỏ dấu và chuyển chữ thường, để gõ "an lau" tìm được
      -- "Ăn lẩu" (SPEC FR-3.12). Do BillDao tự sinh khi ghi, không nằm
      -- trong model Bill.
      title_norm        TEXT    NOT NULL DEFAULT '',
      note              TEXT,
      bill_date         INTEGER NOT NULL,
      category_id       TEXT    REFERENCES categories(id)    ON DELETE SET NULL,
      group_id          TEXT    REFERENCES member_groups(id) ON DELETE SET NULL,

      split_type        TEXT    NOT NULL,
      input_mode        TEXT    NOT NULL,

      subtotal          INTEGER NOT NULL DEFAULT 0,

      discount_mode     TEXT    NOT NULL DEFAULT 'none',
      discount_value    INTEGER NOT NULL DEFAULT 0,
      discount_amount   INTEGER NOT NULL DEFAULT 0,
      tax_mode          TEXT    NOT NULL DEFAULT 'none',
      tax_value         INTEGER NOT NULL DEFAULT 0,
      tax_amount        INTEGER NOT NULL DEFAULT 0,
      service_mode      TEXT    NOT NULL DEFAULT 'none',
      service_value     INTEGER NOT NULL DEFAULT 0,
      service_amount    INTEGER NOT NULL DEFAULT 0,
      tip_amount        INTEGER NOT NULL DEFAULT 0,
      surcharge_alloc   TEXT    NOT NULL DEFAULT 'proportional',

      rounding_unit     INTEGER NOT NULL DEFAULT 1000,
      rounding_mode     TEXT    NOT NULL DEFAULT 'up',
      total_exact       INTEGER NOT NULL DEFAULT 0,
      total_amount      INTEGER NOT NULL DEFAULT 0,
      rounding_delta    INTEGER NOT NULL DEFAULT 0,

      status            TEXT    NOT NULL DEFAULT 'draft',
      image_path        TEXT,
      created_at        INTEGER NOT NULL,
      updated_at        INTEGER NOT NULL,
      deleted_at        INTEGER
    )
  ''';

  static const String _billPayers = '''
    CREATE TABLE bill_payers (
      bill_id     TEXT    NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
      member_id   TEXT    NOT NULL REFERENCES members(id),
      paid_amount INTEGER NOT NULL,
      PRIMARY KEY (bill_id, member_id)
    )
  ''';

  static const String _billParticipants = '''
    CREATE TABLE bill_participants (
      id                   TEXT    PRIMARY KEY,
      bill_id              TEXT    NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
      member_id            TEXT    NOT NULL REFERENCES members(id),
      member_name_snapshot TEXT    NOT NULL,
      sort_order           INTEGER NOT NULL DEFAULT 0,

      weight_num           INTEGER NOT NULL DEFAULT 1,
      weight_den           INTEGER NOT NULL DEFAULT 1,
      percent_bp           INTEGER NOT NULL DEFAULT 0,
      exact_amount         INTEGER NOT NULL DEFAULT 0,

      base_share           INTEGER NOT NULL DEFAULT 0,
      share_amount         INTEGER NOT NULL DEFAULT 0,
      paid_amount          INTEGER NOT NULL DEFAULT 0,
      settled_at           INTEGER,
      UNIQUE (bill_id, member_id)
    )
  ''';

  // ────────────────────────────── MÓN ──────────────────────────────

  static const String _billItems = '''
    CREATE TABLE bill_items (
      id         TEXT    PRIMARY KEY,
      bill_id    TEXT    NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
      name       TEXT    NOT NULL,
      unit_price INTEGER NOT NULL DEFAULT 0,
      quantity   INTEGER NOT NULL DEFAULT 1,
      amount     INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _billItemParticipants = '''
    CREATE TABLE bill_item_participants (
      item_id    TEXT    NOT NULL REFERENCES bill_items(id) ON DELETE CASCADE,
      member_id  TEXT    NOT NULL REFERENCES members(id),
      weight_num INTEGER NOT NULL DEFAULT 1,
      weight_den INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (item_id, member_id)
    )
  ''';

  // ──────────────────────── CHUYỂN TIỀN & KHÁC ─────────────────────

  static const String _payments = '''
    CREATE TABLE payments (
      id             TEXT    PRIMARY KEY,
      bill_id        TEXT    REFERENCES bills(id) ON DELETE SET NULL,
      from_member_id TEXT    NOT NULL REFERENCES members(id),
      to_member_id   TEXT    NOT NULL REFERENCES members(id),
      amount         INTEGER NOT NULL,
      paid_at        INTEGER NOT NULL,
      method         TEXT,
      note           TEXT,
      created_at     INTEGER NOT NULL
    )
  ''';

  static const String _billTemplates = '''
    CREATE TABLE bill_templates (
      id           TEXT    PRIMARY KEY,
      name         TEXT    NOT NULL,
      payload_json TEXT    NOT NULL,
      created_at   INTEGER NOT NULL
    )
  ''';

  /// Danh sách món đặt sẵn tên và giá, để chọn lại khi nhập hóa đơn.
  ///
  /// Không có khóa ngoại nào trỏ tới bảng này: món trong hóa đơn chép lại tên
  /// và giá tại thời điểm chọn, nên xóa một bản mẫu không đụng tới hóa đơn cũ.
  static const String _itemPresets = '''
    CREATE TABLE item_presets (
      id          TEXT    PRIMARY KEY,
      name        TEXT    NOT NULL,
      name_norm   TEXT    NOT NULL,
      unit_price  INTEGER NOT NULL DEFAULT 0,
      sort_order  INTEGER NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL,
      updated_at  INTEGER NOT NULL
    )
  ''';

  static const String _appSettings = '''
    CREATE TABLE app_settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';
}
