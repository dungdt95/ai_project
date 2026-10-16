import 'package:chiahoadon/data/dao/item_preset_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/data/repositories/item_preset_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_helper.dart';

/// Danh sách món đặt sẵn tên và giá.
void main() {
  setUpAll(DbTestHelper.initFfi);

  late AppDatabase database;
  late ItemPresetDao dao;
  late ItemPresetRepository repository;

  setUp(() async {
    database = await DbTestHelper.openDb();
    dao = ItemPresetDao(database);
    repository = ItemPresetRepository(dao);
  });

  tearDown(() async {
    await database.close();
  });

  group('Thêm món', () {
    test('lưu được tên và giá', () async {
      final preset = (await repository.create(
        name: 'Lẩu thái',
        unitPrice: 500000,
      )).valueOrNull;

      expect(preset, isNotNull);
      expect(preset!.name, 'Lẩu thái');
      expect(preset.unitPrice, 500000);
      expect(preset.nameNorm, 'lau thai', reason: 'Tên bỏ dấu để tìm kiếm');

      expect(await dao.count(), 1);
    });

    test('cắt khoảng trắng thừa ở tên', () async {
      final preset = (await repository.create(
        name: '  Bia Sài Gòn  ',
        unitPrice: 20000,
      )).valueOrNull!;

      expect(preset.name, 'Bia Sài Gòn');
    });

    test('tên rỗng thì không lưu', () async {
      final result = await repository.create(name: '   ', unitPrice: 1000);

      expect(result.isOk, isFalse);
      expect(await dao.count(), 0);
    });

    test('giá âm thì không lưu', () async {
      final result = await repository.create(name: 'Lẩu', unitPrice: -1);

      expect(result.isOk, isFalse);
      expect(await dao.count(), 0);
    });

    test('giá 0 vẫn lưu được — món chưa biết giá', () async {
      final result = await repository.create(name: 'Rau thêm', unitPrice: 0);

      expect(result.isOk, isTrue);
    });

    test('trùng tên thì báo lỗi, kể cả khi khác dấu và hoa thường', () async {
      await repository.create(name: 'Lẩu thái', unitPrice: 500000);

      final again = await repository.create(name: 'LAU THAI', unitPrice: 9000);

      expect(
        again.isOk,
        isFalse,
        reason: 'Hai món cùng tên thì trong bộ chọn không biết chọn cái nào',
      );
      expect(await dao.count(), 1);
    });
  });

  group('Sửa và xóa', () {
    test('đổi tên và giá', () async {
      final preset = (await repository.create(
        name: 'Lẩu thái',
        unitPrice: 500000,
      )).valueOrNull!;

      final updated = (await repository.update(
        preset,
        name: 'Lẩu thái hải sản',
        unitPrice: 650000,
      )).valueOrNull!;

      expect(updated.name, 'Lẩu thái hải sản');
      expect(updated.unitPrice, 650000);
      expect(updated.nameNorm, 'lau thai hai san');
      expect(updated.createdAt, preset.createdAt, reason: 'Giữ ngày tạo');
    });

    test('đổi tên trùng món khác thì báo lỗi', () async {
      await repository.create(name: 'Lẩu thái', unitPrice: 500000);
      final bia = (await repository.create(
        name: 'Bia',
        unitPrice: 20000,
      )).valueOrNull!;

      final result = await repository.update(
        bia,
        name: 'Lẩu thái',
        unitPrice: 20000,
      );

      expect(result.isOk, isFalse);
    });

    test('giữ nguyên tên của chính nó thì sửa được giá', () async {
      final bia = (await repository.create(
        name: 'Bia',
        unitPrice: 20000,
      )).valueOrNull!;

      final result = await repository.update(bia, name: 'Bia', unitPrice: 25000);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.unitPrice, 25000);
    });

    test('xóa hẳn khỏi danh sách', () async {
      final preset = (await repository.create(
        name: 'Lẩu thái',
        unitPrice: 500000,
      )).valueOrNull!;

      await repository.delete(preset.id);

      expect(await dao.count(), 0);
      expect(await dao.getById(preset.id), isNull);
    });
  });

  group('Tìm kiếm', () {
    setUp(() async {
      await repository.create(name: 'Lẩu thái', unitPrice: 500000);
      await repository.create(name: 'Bia Sài Gòn', unitPrice: 20000);
      await repository.create(name: 'Nước ép cam', unitPrice: 35000);
    });

    test('bỏ dấu: gõ "lau thai" ra "Lẩu thái"', () async {
      final found = await dao.search('lau thai');

      expect(found, hasLength(1));
      expect(found.first.name, 'Lẩu thái');
    });

    test('gõ có dấu cũng ra', () async {
      expect(await dao.search('Sài Gòn'), hasLength(1));
    });

    test('khớp giữa chuỗi', () async {
      expect((await dao.search('cam')).first.name, 'Nước ép cam');
    });

    test('ô tìm kiếm rỗng thì trả cả danh sách', () async {
      expect(await dao.search('  '), hasLength(3));
    });

    test('không khớp gì thì rỗng', () async {
      expect(await dao.search('phở'), isEmpty);
    });

    test('sắp xếp theo tên để bộ chọn có thứ tự ổn định', () async {
      final all = await dao.getAll();

      expect(
        [for (final preset in all) preset.name],
        ['Bia Sài Gòn', 'Lẩu thái', 'Nước ép cam'],
      );
    });
  });

  group('Lưu nhanh từ màn nhập hóa đơn', () {
    test('món chưa có thì thêm mới', () async {
      final result = await repository.saveFromBill(
        name: 'Gỏi cuốn',
        unitPrice: 45000,
      );

      expect(result.isOk, isTrue);
      expect(await dao.count(), 1);
    });

    test('món đã có thì cập nhật giá, không báo trùng', () async {
      await repository.create(name: 'Bia', unitPrice: 20000);

      final result = await repository.saveFromBill(
        name: 'bia',
        unitPrice: 25000,
      );

      expect(
        result.isOk,
        isTrue,
        reason: 'Ở ngữ cảnh này người dùng đang nói "lần sau nhớ giá này"',
      );
      expect(await dao.count(), 1);
      expect(result.valueOrNull!.unitPrice, 25000);
      expect(result.valueOrNull!.name, 'Bia', reason: 'Giữ cách viết cũ');
    });
  });

  group('Chép sang món của hóa đơn', () {
    test('chép tên và giá, không giữ tham chiếu', () async {
      final preset = (await repository.create(
        name: 'Lẩu thái',
        unitPrice: 500000,
      )).valueOrNull!;

      final item = preset.toBillItem(id: 'item1', memberIds: ['m1', 'm2']);

      expect(item.name, 'Lẩu thái');
      expect(item.unitPrice, 500000);
      expect(item.participants, hasLength(2));

      // Sửa giá bản mẫu sau đó không được làm đổi món đã chép.
      await repository.update(preset, name: 'Lẩu thái', unitPrice: 999000);
      expect(item.unitPrice, 500000);
    });

    test('số lượng mặc định là 1', () async {
      final preset = (await repository.create(
        name: 'Bia',
        unitPrice: 20000,
      )).valueOrNull!;

      expect(preset.toBillItem(id: 'i', memberIds: const []).quantity, 1);
    });
  });
}
