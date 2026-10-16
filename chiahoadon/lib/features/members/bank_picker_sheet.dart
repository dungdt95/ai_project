import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../data/bank_directory.dart';

/// Bộ chọn ngân hàng nhận tiền (SPEC FR-1.2, FR-6.7).
///
/// Phải chọn trong danh sách chứ không gõ tay, vì QR cần **mã BIN** chứ không
/// cần tên: gõ "Vietcombank" không sinh được QR, chọn Vietcombank thì mới có
/// mã `970436`.
///
/// Trả về ngân hàng đã chọn, hoặc `null` nếu người dùng đóng sheet.
class BankPickerSheet extends StatefulWidget {
  const BankPickerSheet({super.key});

  static Future<Bank?> show(BuildContext context) =>
      showModalBottomSheet<Bank>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const BankPickerSheet(),
      );

  @override
  State<BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<BankPickerSheet> {
  final _searchController = TextEditingController();

  List<Bank> _results = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final found = await BankDirectory.search(query);
    if (!mounted) return;

    setState(() {
      _results = found;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          AppBar(
            title: const Text('Chọn ngân hàng'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.s16,
              0,
              AppTheme.s16,
              AppTheme.s8,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tên ngân hàng hoặc mã BIN',
              ),
            ),
          ),
          Expanded(
            child: switch ((_loading, _results.isEmpty)) {
              (true, _) => const Center(child: CircularProgressIndicator()),
              (_, true) => const EmptyState(
                icon: Icons.search_off,
                title: 'Không tìm thấy ngân hàng',
                message: 'Thử gõ tên ngắn, ví dụ "vietcom" hoặc "mb".',
              ),
              _ => ListView.builder(
                controller: scrollController,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final bank = _results[index];

                  return ListTile(
                    title: Text(bank.shortName),
                    subtitle: Text(
                      bank.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      bank.bin,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(bank),
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}
