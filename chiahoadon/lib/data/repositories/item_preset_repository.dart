import 'package:uuid/uuid.dart';

import '../../core/utils/result.dart';
import '../../core/utils/vn_text.dart';
import '../../domain/models/item_preset.dart';
import '../dao/item_preset_dao.dart';

/// Quản lý danh sách món đặt sẵn tên và giá.
class ItemPresetRepository {
  const ItemPresetRepository(this._dao);

  static const Uuid _uuid = Uuid();

  final ItemPresetDao _dao;

  Future<Result<List<ItemPreset>>> getAll() => Result.guard(_dao.getAll);

  Future<Result<List<ItemPreset>>> search(String query) =>
      Result.guard(() => _dao.search(query));

  Future<Result<ItemPreset>> create({
    required String name,
    required int unitPrice,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppError.validation('Tên món không được để trống.'));
    }
    if (unitPrice < 0) {
      return const Err(AppError.validation('Đơn giá không được âm.'));
    }

    final existing = await _dao.findByName(trimmed);
    if (existing != null) {
      return Err(
        AppError.validation('Đã có món tên "${existing.name}" trong danh sách.'),
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final preset = ItemPreset(
      id: _uuid.v4(),
      name: trimmed,
      nameNorm: VnText.normalize(trimmed),
      unitPrice: unitPrice,
      createdAt: now,
      updatedAt: now,
    );

    return Result.guard(() async {
      await _dao.save(preset);
      return preset;
    });
  }

  Future<Result<ItemPreset>> update(
    ItemPreset preset, {
    required String name,
    required int unitPrice,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppError.validation('Tên món không được để trống.'));
    }
    if (unitPrice < 0) {
      return const Err(AppError.validation('Đơn giá không được âm.'));
    }

    final clash = await _dao.findByName(trimmed, exceptId: preset.id);
    if (clash != null) {
      return Err(
        AppError.validation('Đã có món tên "${clash.name}" trong danh sách.'),
      );
    }

    final updated = preset.copyWith(
      name: trimmed,
      nameNorm: VnText.normalize(trimmed),
      unitPrice: unitPrice,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    return Result.guard(() async {
      await _dao.save(updated);
      return updated;
    });
  }

  Future<Result<void>> delete(String id) =>
      Result.guard(() => _dao.delete(id));

  /// Thêm món vào danh sách nếu chưa có, dùng khi người dùng vừa gõ tay một
  /// món trong lúc nhập hóa đơn và muốn lưu lại dùng sau.
  ///
  /// Trùng tên thì **cập nhật giá** chứ không báo lỗi: ở ngữ cảnh đó người
  /// dùng đang nói "lần sau nhớ giá này", không phải đang tạo mục mới.
  Future<Result<ItemPreset>> saveFromBill({
    required String name,
    required int unitPrice,
  }) async {
    final existing = await _dao.findByName(name.trim());
    if (existing == null) return create(name: name, unitPrice: unitPrice);

    return update(existing, name: existing.name, unitPrice: unitPrice);
  }
}
