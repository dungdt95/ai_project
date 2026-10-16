import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/avatar_color.dart';
import '../../core/utils/vn_text.dart';
import '../../data/data_providers.dart';

/// Màn hình tạm để kiểm tra nền tảng của Phase 0 và Phase 1.
///
/// Sẽ được thay bằng Dashboard thật ở Phase 8. Giữ lại trong lúc phát triển vì
/// nó xác nhận bằng mắt rằng font tiếng Việt, theme sáng/tối, bộ định dạng tiền
/// và kết nối cơ sở dữ liệu đều hoạt động.
class DevCheckScreen extends ConsumerWidget {
  const DevCheckScreen({super.key});

  static const List<String> _sampleNames = [
    'Dũng',
    'An',
    'Bình',
    'Chi',
    'Nguyễn Văn Đức',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final self = ref.watch(selfMemberProvider);
    final categories = ref.watch(categoriesProvider);
    final roundingUnit = ref.watch(defaultRoundingUnitProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra nền tảng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Đọc lại từ DB',
            onPressed: () {
              ref.invalidate(selfMemberProvider);
              ref.invalidate(categoriesProvider);
              ref.invalidate(defaultRoundingUnitProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.s16),
        children: [
          _Section(
            title: 'Phase 1 — Cơ sở dữ liệu',
            children: [
              switch (self) {
                AsyncData(:final value) => _Row(
                  'Thành viên "Tôi"',
                  value == null ? 'CHƯA CÓ (lỗi seed)' : value.name,
                ),
                AsyncError(:final error) => _Row('Thành viên "Tôi"', '$error'),
                _ => const _Row('Thành viên "Tôi"', 'đang đọc...'),
              },
              switch (categories) {
                AsyncData(:final value) => _Row(
                  'Danh mục mặc định',
                  '${value.length} mục: '
                      '${value.map((c) => c.icon ?? '').join(' ')}',
                ),
                AsyncError(:final error) => _Row('Danh mục', '$error'),
                _ => const _Row('Danh mục', 'đang đọc...'),
              },
              switch (roundingUnit) {
                AsyncData(:final value) => _Row(
                  'Đơn vị làm tròn mặc định',
                  value.toVnd(),
                ),
                AsyncError(:final error) => _Row('Làm tròn', '$error'),
                _ => const _Row('Làm tròn', 'đang đọc...'),
              },
            ],
          ),
          const SizedBox(height: AppTheme.s16),
          _Section(
            title: 'Định dạng tiền (NFR-6: tiền là int)',
            children: [
              _Row('1.000.000 đồng', 1000000.toVnd()),
              _Row('Phần dư 1.000.000/3', 333333.toVnd()),
              _Row('Số dư dương', 500000.toVndSigned()),
              _Row('Số dư âm', (-300000).toVndSigned()),
              _Row('Dạng ngắn (biểu đồ)', 1200000.toVndCompact()),
              _Row('VAT 8% (basis point 800)', 800.toPercent()),
              _Row('Phí DV 8,5% (bp 850)', 850.toPercent()),
            ],
          ),
          const SizedBox(height: AppTheme.s16),
          _Section(
            title: 'Định dạng ngày',
            children: [
              _Row('Hôm nay', DateTime.now().toRelativeDate()),
              _Row('Ngày đầy đủ', DateTime(2026, 10, 2).toShortDate()),
            ],
          ),
          const SizedBox(height: AppTheme.s16),
          _Section(
            title: 'Avatar & bỏ dấu tiếng Việt',
            children: [
              Wrap(
                spacing: AppTheme.s12,
                runSpacing: AppTheme.s12,
                children: [
                  for (final name in _sampleNames)
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AvatarColor.forName(name),
                          child: Text(
                            VnText.initial(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.s4),
                        Text(name, style: theme.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.s12),
              _Row(
                'normalize("Nguyễn Văn Đức")',
                VnText.normalize('Nguyễn Văn Đức'),
              ),
              _Row(
                'contains("Bình", "binh")',
                VnText.contains('Bình', 'binh').toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.s12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: AppTheme.s8),
          Flexible(
            child: Text(
              value,
              style: MoneyTextStyle.small,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
