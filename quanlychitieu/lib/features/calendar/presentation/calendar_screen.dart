import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/lunar_calendar.dart';
import '../../../data/models/calendar_note.dart';
import '../../../data/repositories/calendar_note_repository.dart';
import 'month_year_picker.dart';
import 'note_editor.dart';
import 'notes_list_screen.dart';

final _noteRepo = CalendarNoteRepository();

final calendarNotesProvider =
    FutureProvider.family<List<CalendarNote>, String>((ref, monthKey) async {
  final parts = monthKey.split('-');
  return _noteRepo.getByMonth(int.parse(parts[0]), int.parse(parts[1]));
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  String get _monthKey =>
      '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final asyncNotes = ref.watch(calendarNotesProvider(_monthKey));
    final selectedLunar = solarToLunar(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Chọn tháng/năm',
            onPressed: _pickMonthYear,
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Hôm nay',
            onPressed: () => setState(() {
              _focusedDay = DateTime.now();
              _selectedDay = DateTime.now();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Tất cả ghi chú',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotesListScreen()),
              );
              ref.invalidate(calendarNotesProvider(_monthKey));
            },
          ),
        ],
      ),
      body: asyncNotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (notes) {
          // Group notes by date string (YYYY-MM-DD)
          final notesByDate = <String, List<CalendarNote>>{};
          for (final n in notes) {
            notesByDate.putIfAbsent(n.date, () => []).add(n);
          }

          final selectedDateKey = toIso(_selectedDay);
          final selectedDayNotes = notesByDate[selectedDateKey] ?? [];

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: TableCalendar(
                  firstDay: DateTime(1950, 1, 1),
                  lastDay: DateTime(DateTime.now().year + 20, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                  calendarFormat: _format,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    setState(() => _focusedDay = focused);
                  },
                  onHeaderTapped: (_) => _pickMonthYear(),
                  onFormatChanged: (f) => setState(() => _format = f),
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Tháng',
                    CalendarFormat.twoWeeks: '2 tuần',
                    CalendarFormat.week: 'Tuần',
                  },
                  eventLoader: (day) => notesByDate[toIso(day)] ?? [],
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                    markerSize: 5,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonShowsNext: false,
                    titleCentered: true,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) =>
                        _buildDayCell(day, isSelected: false, isToday: false),
                    todayBuilder: (context, day, focusedDay) =>
                        _buildDayCell(day, isSelected: false, isToday: true),
                    selectedBuilder: (context, day, focusedDay) =>
                        _buildDayCell(day, isSelected: true, isToday: false),
                    outsideBuilder: (context, day, focusedDay) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${day.day}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                          Text(solarToLunar(day).short,
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Selected day info
              Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatDate(_selectedDay),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Âm lịch: ${selectedLunar.formatted}/${selectedLunar.year}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[700])),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _addNote(_selectedDay),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm ghi chú'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: selectedDayNotes.isEmpty
                    ? const Center(
                        child: Text('Chưa có ghi chú cho ngày này',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: selectedDayNotes.length,
                        itemBuilder: (_, i) {
                          final note = selectedDayNotes[i];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.event_note,
                                    color: Colors.white, size: 20),
                              ),
                              title: Text(note.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: note.content != null
                                  ? Text(note.content!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis)
                                  : null,
                              onTap: () => _editNote(note),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteNote(note),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {required bool isSelected, required bool isToday}) {
    final lunar = solarToLunar(day);
    final isMot = lunar.day == 1; // mùng 1
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : day.weekday == DateTime.sunday
                      ? Colors.red
                      : null,
            ),
          ),
          Text(
            isMot ? '${lunar.day}/${lunar.month}' : '${lunar.day}',
            style: TextStyle(
              fontSize: 9,
              color: isSelected
                  ? Colors.white70
                  : isMot
                      ? AppColors.expense
                      : Colors.grey[600],
              fontWeight: isMot ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonthYear() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthYearPicker(initialDate: _focusedDay),
    );
    if (picked != null) {
      setState(() {
        // Giữ nguyên ngày nếu có thể, nếu không lấy ngày 1
        final day = _focusedDay.day.clamp(1, DateTime(picked.year, picked.month + 1, 0).day);
        _focusedDay = DateTime(picked.year, picked.month, day);
      });
    }
  }

  Future<void> _addNote(DateTime date) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NoteEditor(date: date),
    );
    if (saved == true) ref.invalidate(calendarNotesProvider(_monthKey));
  }

  Future<void> _editNote(CalendarNote note) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NoteEditor(date: DateTime.parse(note.date), existing: note),
    );
    if (saved == true) ref.invalidate(calendarNotesProvider(_monthKey));
  }

  Future<void> _deleteNote(CalendarNote note) async {
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
      ref.invalidate(calendarNotesProvider(_monthKey));
    }
  }
}
