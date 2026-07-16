part of 'reports_page.dart';

/// Report page with product sales and profitability indicators.
class ProductPerformanceReportPage extends StatefulWidget {
  /// Creates the product performance report page.
  const ProductPerformanceReportPage({super.key});

  @override
  State<ProductPerformanceReportPage> createState() {
    return _ProductPerformanceReportPageState();
  }
}

class _ProductPerformanceReportPageState
    extends State<ProductPerformanceReportPage> {
  late DateTime _from;
  late DateTime _to;
  late Future<AppResult<ProductPerformanceReport>> _future;
  Set<_ProductSegmentFilter> _segments = {_ProductSegmentFilter.all};
  List<_ProductPerformanceSort> _sorts = [_ProductPerformanceSort.profit];

  SupabaseProductPerformanceReportService get _service {
    return serviceLocator<SupabaseProductPerformanceReportService>();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 90));
    _reload();
  }

  void _reload() {
    _future = _service.load(from: _from, to: _to);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Desempeno de productos',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DailySalesFilterCard(
            from: _from,
            to: _to,
            onRangeChanged: _setRange,
            onReload: () => setState(_reload),
            onTodaySelected: _setToday,
            onMonthSelected: _setLastThreeMonths,
            compactActions: true,
            monthLabel: '3 meses',
          ),
          const SizedBox(height: 12),
          FutureBuilder<AppResult<ProductPerformanceReport>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const AppLoadingPage();
              return snapshot.requireData.when(
                success: (report) => _ProductPerformanceView(
                  onSegmentToggled: _toggleSegment,
                  onSortToggled: _toggleSort,
                  report: report,
                  segments: _segments,
                  sorts: _sorts,
                ),
                failure: (error) => AppEmptyState(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Desempeno de productos',
                  message: error.message,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _setRange(DateTimeRange range) {
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(range.end.year, range.end.month, range.end.day);
      _reload();
    });
  }

  void _setToday() {
    final now = DateTime.now();
    setState(() {
      _to = DateTime(now.year, now.month, now.day);
      _from = _to;
      _reload();
    });
  }

  void _setLastThreeMonths() {
    final now = DateTime.now();
    setState(() {
      _to = DateTime(now.year, now.month, now.day);
      _from = _to.subtract(const Duration(days: 90));
      _reload();
    });
  }

  void _toggleSegment(_ProductSegmentFilter value) {
    setState(() {
      if (value == _ProductSegmentFilter.all) {
        _segments = {_ProductSegmentFilter.all};
        return;
      }
      final next = {..._segments}..remove(_ProductSegmentFilter.all);
      next.contains(value) ? next.remove(value) : next.add(value);
      _segments = next.isEmpty ? {_ProductSegmentFilter.all} : next;
    });
  }

  void _toggleSort(_ProductPerformanceSort value) {
    setState(() {
      final next = [..._sorts];
      next.contains(value) ? next.remove(value) : next.add(value);
      _sorts = next.isEmpty ? [_ProductPerformanceSort.profit] : next;
    });
  }
}
