import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../data/data_providers.dart';
import '../../domain/models/item_preset.dart';

/// Danh sách món đặt sẵn tên và giá.
class ItemPresetsNotifier extends AsyncNotifier<List<ItemPreset>> {
  @override
  Future<List<ItemPreset>> build() async =>
      (await ref.watch(itemPresetRepositoryProvider).getAll()).valueOr(const []);

  Future<Result<ItemPreset>> create({
    required String name,
    required int unitPrice,
  }) async {
    final result = await ref
        .read(itemPresetRepositoryProvider)
        .create(name: name, unitPrice: unitPrice);

    if (result.isOk) ref.invalidateSelf();
    return result;
  }

  Future<Result<ItemPreset>> save(
    ItemPreset preset, {
    required String name,
    required int unitPrice,
  }) async {
    final result = await ref
        .read(itemPresetRepositoryProvider)
        .update(preset, name: name, unitPrice: unitPrice);

    if (result.isOk) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> delete(String id) async {
    final result = await ref.read(itemPresetRepositoryProvider).delete(id);

    if (result.isOk) ref.invalidateSelf();
    return result;
  }

  /// Lưu nhanh một món vừa gõ tay trong lúc nhập hóa đơn.
  Future<Result<ItemPreset>> saveFromBill({
    required String name,
    required int unitPrice,
  }) async {
    final result = await ref
        .read(itemPresetRepositoryProvider)
        .saveFromBill(name: name, unitPrice: unitPrice);

    if (result.isOk) ref.invalidateSelf();
    return result;
  }
}

final itemPresetsProvider =
    AsyncNotifierProvider<ItemPresetsNotifier, List<ItemPreset>>(
      ItemPresetsNotifier.new,
    );
