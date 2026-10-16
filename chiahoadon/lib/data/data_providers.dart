import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/expense_category.dart';
import '../domain/models/member.dart';
import 'dao/bill_dao.dart';
import 'dao/category_dao.dart';
import 'dao/group_dao.dart';
import 'dao/item_preset_dao.dart';
import 'dao/member_dao.dart';
import 'dao/payment_dao.dart';
import 'dao/settings_dao.dart';
import 'dao/stats_dao.dart';
import 'database/app_database.dart';
import 'repositories/bill_repository.dart';
import 'repositories/group_repository.dart';
import 'repositories/item_preset_repository.dart';
import 'repositories/member_repository.dart';
import 'repositories/settlement_repository.dart';
import 'repositories/stats_repository.dart';

/// Kết nối SQLite của app.
///
/// Được ghi đè trong `main()` bằng một kết nối đã mở sẵn:
/// ```dart
/// ProviderScope(overrides: [databaseProvider.overrideWithValue(db)])
/// ```
/// Mở DB trước `runApp` thay vì dùng `FutureProvider` khiến mọi provider phía
/// sau là đồng bộ — không màn hình nào phải xử lý trạng thái "đang mở DB", và
/// khung xem trước chia tiền không bị nhấp nháy (PLAN §6).
final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError(
    'databaseProvider chưa được ghi đè. '
    'Hãy mở AppDatabase trong main() rồi truyền vào ProviderScope.overrides.',
  );
});

// ─────────────────────────────── DAO ───────────────────────────────

final memberDaoProvider = Provider<MemberDao>(
  (ref) => MemberDao(ref.watch(databaseProvider)),
);

final groupDaoProvider = Provider<GroupDao>(
  (ref) => GroupDao(ref.watch(databaseProvider)),
);

final billDaoProvider = Provider<BillDao>(
  (ref) => BillDao(ref.watch(databaseProvider)),
);

final paymentDaoProvider = Provider<PaymentDao>(
  (ref) => PaymentDao(ref.watch(databaseProvider)),
);

final categoryDaoProvider = Provider<CategoryDao>(
  (ref) => CategoryDao(ref.watch(databaseProvider)),
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => SettingsDao(ref.watch(databaseProvider)),
);

final itemPresetDaoProvider = Provider<ItemPresetDao>(
  (ref) => ItemPresetDao(ref.watch(databaseProvider)),
);

final statsDaoProvider = Provider<StatsDao>(
  (ref) => StatsDao(ref.watch(databaseProvider)),
);

// ──────────────────────────── Repository ───────────────────────────

final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(
    ref.watch(memberDaoProvider),
    ref.watch(groupDaoProvider),
  ),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(ref.watch(groupDaoProvider)),
);

final billRepositoryProvider = Provider<BillRepository>(
  (ref) => BillRepository(ref.watch(billDaoProvider)),
);

final itemPresetRepositoryProvider = Provider<ItemPresetRepository>(
  (ref) => ItemPresetRepository(ref.watch(itemPresetDaoProvider)),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(
    ref.watch(statsDaoProvider),
    ref.watch(memberDaoProvider),
  ),
);

final settlementRepositoryProvider = Provider<SettlementRepository>(
  (ref) => SettlementRepository(
    ref.watch(statsDaoProvider),
    ref.watch(paymentDaoProvider),
  ),
);

// ──────────────────────── Dữ liệu dùng nhiều nơi ───────────────────

/// Bản ghi "Tôi" (SPEC FR-1.6). Mặc định làm người trả trước của hóa đơn mới.
final selfMemberProvider = FutureProvider<Member?>((ref) async {
  final result = await ref.watch(memberRepositoryProvider).getSelf();
  return result.valueOrNull;
});

/// Danh mục hóa đơn, dùng ở form hóa đơn và màn thống kê.
final categoriesProvider = FutureProvider<List<ExpenseCategory>>((ref) async {
  return ref.watch(categoryDaoProvider).getAll();
});

/// Đơn vị làm tròn mặc định cho hóa đơn mới (SPEC FR-5.7).
final defaultRoundingUnitProvider = FutureProvider<int>((ref) async {
  return ref.watch(settingsDaoProvider).roundingUnit();
});
