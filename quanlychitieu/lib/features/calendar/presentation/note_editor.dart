import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/lunar_calendar.dart';
import '../../../data/models/calendar_note.dart';
import '../../../data/repositories/calendar_note_repository.dart';

class NoteEditor extends StatefulWidget {
  final DateTime date;
  final CalendarNote? existing;
  const NoteEditor({super.key, required this.date, this.existing});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _repo = CalendarNoteRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleCtrl.text = widget.existing!.title;
      _contentCtrl.text = widget.existing!.content ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lunar = solarToLunar(widget.date);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.existing == null ? 'Thêm ghi chú' : 'Sửa ghi chú',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatDate(widget.date)}  •  Âm lịch ${lunar.formatted}',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập tiêu đề' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: 'Nội dung (tùy chọn)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(widget.existing == null ? 'Thêm' : 'Lưu'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final note = CalendarNote(
      id: widget.existing?.id,
      date: toIso(widget.date),
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    if (widget.existing == null) {
      await _repo.insert(note);
    } else {
      await _repo.update(note);
    }
    if (mounted) Navigator.pop(context, true);
  }
}
