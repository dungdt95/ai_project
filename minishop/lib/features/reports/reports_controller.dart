import 'package:flutter/foundation.dart';

import '../../data/models/invoice_counts.dart';
import '../../data/models/revenue_point.dart';
import '../../data/models/top_item.dart';
import '../../data/repositories/report_repository.dart';
import 'report_range.dart';

class ReportsController extends ChangeNotifier {
  final ReportRepository _repo = ReportRepository();

  ReportRange _range = ReportRange.last7Days;
  bool _isLoading = false;
  List<RevenuePoint> _revenueSeries = [];
  List<TopItem> _topItems = [];
  InvoiceCounts _counts = const InvoiceCounts();

  ReportRange get range => _range;
  bool get isLoading => _isLoading;
  List<RevenuePoint> get revenueSeries => _revenueSeries;
  List<TopItem> get topItems => _topItems;
  InvoiceCounts get counts => _counts;

  int get totalRevenue => _revenueSeries.fold(0, (sum, p) => sum + p.revenue);

  Future<void> setRange(ReportRange range) async {
    _range = range;
    await load();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final bounds = _range.bounds();
    _revenueSeries = await _repo.getRevenueByDay(bounds.start, bounds.end);
    _topItems = await _repo.getTopItems(bounds.start, bounds.end);
    _counts = await _repo.getInvoiceCounts(bounds.start, bounds.end);

    _isLoading = false;
    notifyListeners();
  }
}
