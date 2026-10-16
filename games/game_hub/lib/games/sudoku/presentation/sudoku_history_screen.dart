import 'package:flutter/material.dart';
import '../data/sudoku_history_service.dart';
import '../domain/variant.dart';

class SudokuHistoryScreen extends StatelessWidget {
  const SudokuHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = SudokuHistoryService.instance.getAll();
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử Sudoku')),
      body: records.isEmpty
          ? const Center(child: Text('Chưa có ván nào hoàn thành'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (ctx, i) => _RecordTile(record: records[i]),
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});
  final SudokuGameRecord record;

  @override
  Widget build(BuildContext context) {
    final min = record.duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = record.duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return ListTile(
      leading: CircleAvatar(
        child: Icon(_icon()),
      ),
      title: Text('${record.variant.label} — ${record.difficulty.label}'),
      subtitle: Text(
        '${_dateStr(record.completedAt)}  |  $min:$sec  |  '
        '${record.mistakeCount} lỗi  |  ${record.hintsUsed} gợi ý'
        '${record.isDaily ? '  ★ Daily' : ''}',
      ),
    );
  }

  IconData _icon() => switch (record.variant) {
        SudokuVariant.classic => Icons.grid_on,
        SudokuVariant.killer => Icons.calculate_outlined,
        SudokuVariant.xSudoku => Icons.close,
      };

  String _dateStr(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}
