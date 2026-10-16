import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/borrower.dart';
import '../../../data/repositories/borrower_repository.dart';

final _borrowerRepo = BorrowerRepository();
final borrowersListProvider = FutureProvider<List<Borrower>>((ref) => _borrowerRepo.getAll());

class BorrowersScreen extends ConsumerWidget {
  const BorrowersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(borrowersListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Người vay')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (borrowers) => borrowers.isEmpty
            ? const Center(child: Text('Chưa có người vay nào'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: borrowers.length,
                itemBuilder: (_, i) {
                  final b = borrowers[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.loanLight,
                      child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.loan, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(b.name),
                    subtitle: b.phone != null ? Text(b.phone!) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditDialog(context, ref, b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final ok = await showConfirmDialog(context, title: 'Xóa người vay', content: 'Xóa "${b.name}"?');
                            if (ok) {
                              await _borrowerRepo.delete(b.id!);
                              ref.refresh(borrowersListProvider);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_borrowers',
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, Borrower? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Thêm người vay' : 'Sửa người vay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên *', border: OutlineInputBorder()), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final b = Borrower(
                id: existing?.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              );
              if (existing == null) { await _borrowerRepo.insert(b); } else { await _borrowerRepo.update(b); }
              if (context.mounted) Navigator.pop(context);
              ref.refresh(borrowersListProvider);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
