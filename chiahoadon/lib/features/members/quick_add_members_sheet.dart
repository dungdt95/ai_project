import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vn_text.dart';
import '../../core/widgets/app_feedback.dart';
import 'members_provider.dart';

/// Nhập nhanh nhiều thành viên, mỗi dòng một tên (SPEC FR-1.8).
///
/// Dùng khi mới lập nhóm: gõ một lượt 6 cái tên nhanh hơn nhiều so với mở form
/// đầy đủ sáu lần.
class QuickAddMembersSheet extends ConsumerStatefulWidget {
  const QuickAddMembersSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const QuickAddMembersSheet(),
  );

  @override
  ConsumerState<QuickAddMembersSheet> createState() =>
      _QuickAddMembersSheetState();
}

class _QuickAddMembersSheetState extends ConsumerState<QuickAddMembersSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  /// Các tên hợp lệ sẽ được thêm: bỏ dòng trống và bỏ tên lặp lại.
  ///
  /// Trùng trong cùng một lần nhập gần như luôn là gõ hai lần, nên bỏ luôn;
  /// còn trùng với người đã có trong DB thì vẫn cho thêm (SPEC FR-1).
  List<String> get _names {
    final seen = <String>{};
    final names = <String>[];

    for (final line in _controller.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(VnText.normalize(trimmed))) names.add(trimmed);
    }

    return names;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = _names;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.s16,
        right: AppTheme.s16,
        top: AppTheme.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thêm nhanh nhiều người',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.s4),
          Text(
            'Mỗi dòng một tên',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.s16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 8,
            minLines: 4,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'An\nBình\nChi\nDũng',
            ),
          ),
          const SizedBox(height: AppTheme.s12),
          Text(
            names.isEmpty
                ? 'Chưa có tên nào'
                : 'Sẽ thêm ${names.length} người: ${names.join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: names.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppTheme.s16),
          FilledButton(
            onPressed: (names.isEmpty || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    names.isEmpty
                        ? 'Thêm'
                        : 'Thêm ${names.length} người',
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final result = await ref
        .read(membersProvider.notifier)
        .createMany(_controller.text);
    if (!mounted) return;

    setState(() => _saving = false);

    result.when(
      ok: (members) {
        Navigator.of(context).pop();
        AppSnackBar.success(context, 'Đã thêm ${members.length} thành viên');
      },
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}
