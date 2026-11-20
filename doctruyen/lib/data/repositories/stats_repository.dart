import '../../domain/stats/activity_accumulator.dart';
import '../../domain/stats/stats_aggregator.dart';
import '../dao/stats_dao.dart';

class StatsRepository {
  StatsRepository(this._dao);

  final StatsDao _dao;

  Future<void> flush(ActivityAccumulator acc) => _dao.addSeconds(acc.drain());

  Future<StatsSummary> summary({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final from = StatsAggregator.dayKey(DateTime(n.year, n.month, n.day - 365));
    return StatsAggregator.summarize(await _dao.since(from), n);
  }
}
