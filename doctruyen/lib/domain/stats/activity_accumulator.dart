import 'stats_aggregator.dart';

/// Số giây chờ ghi xuống DB cho một (ngày, truyện).
class PendingSeconds {
  int read = 0;
  int listen = 0;

  bool get isEmpty => read == 0 && listen == 0;
}

/// Cộng dồn thời gian đọc/nghe theo từng nhịp `tick(now)`.
///
/// - Nghe (TTS đang phát) được tính bất kể màn hình đang ở đâu.
/// - Đọc chỉ tính khi màn đọc đang mở, app ở foreground, không nghe TTS (để
///   khỏi cộng đôi) và lần chạm gần nhất cách chưa quá [idleLimit].
/// - Khoảng cách giữa hai nhịp quá [maxGap] (app bị treo/ngủ) bị cắt bớt.
class ActivityAccumulator {
  ActivityAccumulator({
    this.idleLimit = const Duration(minutes: 2),
    this.maxGap = const Duration(seconds: 10),
  });

  final Duration idleLimit;
  final Duration maxGap;

  int? _readingBookId;
  int? _listeningBookId;
  bool appActive = true;
  DateTime? _lastInteraction;
  DateTime? _lastTick;
  final Map<(String, int), PendingSeconds> _pending = {};

  /// Màn đọc truyện [bookId] đang hiển thị (null = không).
  void setReading(int? bookId, DateTime now) {
    _readingBookId = bookId;
    if (bookId != null) _lastInteraction = now;
  }

  void setListening(int? bookId) => _listeningBookId = bookId;

  void interaction(DateTime now) => _lastInteraction = now;

  void tick(DateTime now) {
    final last = _lastTick;
    _lastTick = now;
    if (last == null) return;
    var dt = now.difference(last);
    if (dt <= Duration.zero) return;
    if (dt > maxGap) dt = maxGap;
    final seconds = dt.inMilliseconds / 1000.0;
    final key = StatsAggregator.dayKey(now);

    final listening = _listeningBookId;
    final reading = _readingBookId;
    if (listening != null) {
      _add(key, listening).listen += _round(seconds);
    } else if (reading != null && appActive) {
      final li = _lastInteraction;
      if (li != null && now.difference(li) <= idleLimit) {
        _add(key, reading).read += _round(seconds);
      }
    }
  }

  // Cộng phần lẻ để không mất giây khi nhịp không tròn.
  double _carry = 0;
  int _round(double seconds) {
    final total = seconds + _carry;
    final whole = total.floor();
    _carry = total - whole;
    return whole;
  }

  PendingSeconds _add(String day, int bookId) =>
      _pending.putIfAbsent((day, bookId), PendingSeconds.new);

  /// Lấy và xóa dữ liệu chờ ghi.
  Map<(String, int), PendingSeconds> drain() {
    final out = Map<(String, int), PendingSeconds>.fromEntries(
      _pending.entries.where((e) => !e.value.isEmpty),
    );
    _pending.clear();
    return out;
  }
}
