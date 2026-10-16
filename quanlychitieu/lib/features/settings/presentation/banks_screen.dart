import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/bank.dart';
import '../../../data/repositories/bank_repository.dart';

final _bankRepo = BankRepository();
final banksProvider = FutureProvider<List<Bank>>((ref) => _bankRepo.getAll());

class BanksScreen extends ConsumerWidget {
  const BanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(banksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ngân hàng')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (banks) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: banks.length,
          itemBuilder: (_, i) {
            final b = banks[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.depositLight,
                child: Text(b.code, style: const TextStyle(color: AppColors.deposit, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              title: Text(b.name),
              subtitle: Text(b.code),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final ok = await showConfirmDialog(context, title: 'Xóa ngân hàng', content: 'Xóa ngân hàng "${b.name}"?');
                  if (ok) {
                    await _bankRepo.delete(b.id!);
                    ref.refresh(banksProvider);
                  }
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_banks',
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm ngân hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Mã viết tắt (VD: VCB)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên ngân hàng', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              await _bankRepo.insert(Bank(code: codeCtrl.text.trim().toUpperCase(), name: nameCtrl.text.trim()));
              if (context.mounted) Navigator.pop(context);
              ref.refresh(banksProvider);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}
