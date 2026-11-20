/// Định dạng thời lượng và thời điểm bằng tiếng Việt.
class Fmt {
  const Fmt._();

  static String duration(int seconds) {
    if (seconds < 60) return seconds <= 0 ? '0 phút' : '< 1 phút';
    final m = seconds ~/ 60;
    if (m < 60) return '$m phút';
    final h = m ~/ 60;
    final rest = m % 60;
    return rest == 0 ? '$h giờ' : '$h giờ $rest phút';
  }

  static String clock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String relative(DateTime? t, DateTime now) {
    if (t == null) return 'Chưa đọc';
    final d = now.difference(t);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    if (d.inDays < 30) return '${d.inDays} ngày trước';
    return '${t.day}/${t.month}/${t.year}';
  }
}
