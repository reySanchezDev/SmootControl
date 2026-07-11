part of 'reports_page.dart';

/// Daily sales report page.
class DailySalesReportPage extends StatefulWidget {
  /// Creates the daily sales report page.
  const DailySalesReportPage({super.key});

  @override
  State<DailySalesReportPage> createState() => _DailySalesReportPageState();
}

class _DailySalesReportPageState extends State<DailySalesReportPage> {
  late DateTime _from;
  late Future<AppResult<DailySalesReport>> _future;
  late DateTime _to;

  SupabaseDailySalesReportService get _service =>
      serviceLocator<SupabaseDailySalesReportService>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Ventas al dia',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DailySalesFilterCard(
            from: _from,
            onMonthSelected: _selectCurrentMonth,
            onReload: _reload,
            onRangeChanged: _selectRange,
            onTodaySelected: _selectToday,
            to: _to,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AppResult<DailySalesReport>>(
            future: _future,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return const AppLoadingPage();

              return result.when(
                success: (report) => _DailySalesReportView(report: report),
                failure: (failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: 'No se pudo cargar',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<AppResult<DailySalesReport>> _load() {
    return _service.load(from: _from, to: _to);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  void _selectCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month);
      _to = DateTime(now.year, now.month, now.day);
      _future = _load();
    });
  }

  void _selectRange(DateTimeRange range) {
    setState(() {
      _from = range.start;
      _to = range.end;
    });
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, now.day);
      _to = _from;
      _future = _load();
    });
  }
}
