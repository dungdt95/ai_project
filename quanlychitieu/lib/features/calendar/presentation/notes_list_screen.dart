import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/lunar_calendar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/calendar_note.dart';
import '../../../data/repositories/calendar_note_repository.dart';
import 'note_editor.dart';

final _noteRepo = CalendarNoteRepository();

final allCalendarNotesProvider = FutureProvider<List<CalendarNote>>(
  (ref) => _noteRepo.getAll(),
);

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotes = ref.watch(allCalendarNotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả ghi chú')),
      body: asyncNotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return const EmptyState(
              message: 'Chưa có ghi chú nào',
              icon: Icons.event_note_outlined,
            );
          }

          // Group by year-month
          final grouped = <String, List<CalendarNote>>{};
          for (final n in notes) {
            final ym = n.date.substring(0, 7); // YYYY-MM
            grouped.putIfAbsent(ym, () => []).add(n);
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(allCalendarNotesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final ym = grouped.keys.elementAt(i);
                final monthNotes = grouped[ym]!;
                final parts = ym.split('-');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Text(
                        'Tháng ${parts[1]}/${parts[0]} (${monthNotes.length} ghi chú)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                    ),
                    ...monthNotes.map((n) => _NoteTile(
                          note: n,
                          onChanged: () => ref.refresh(allCalendarNotesProvider),
                        )),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final CalendarNote note;
  final VoidCallback onChanged;
  const _NoteTile({required this.note, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(note.date);
    final lunar = solarToLunar(date);
    return Card(
      child: ListTile(
        leading: Container(
          width: 52,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${date.day}/${date.month}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.1)),
              Text('Â ${lunar.short}',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[700], height: 1.1)),
            ],
          ),
        ),
        title: Text(note.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: note.content != null
            ? Text(note.content!, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        onTap: () async {
          final saved = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => NoteEditor(date: date, existing: note),
          );
          if (saved == true) onChanged();
        },
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Xóa ghi chú'),
                content: Text('Xóa "${note.title}"?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Xóa')),
                ],
              ),
            );
            if (ok == true) {
              await _noteRepo.delete(note.id!);
              onChanged();
            }
          },
        ),
        isThreeLine: note.content != null,
      ),
    );
  }
}
