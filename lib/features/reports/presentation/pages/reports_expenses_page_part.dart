part of 'reports_page.dart';

/// Operational expenses report page.
class ExpensesReportPage extends StatefulWidget {
  /// Creates the expenses report page.
  const ExpensesReportPage({super.key});

  @override
  State<ExpensesReportPage> createState() => _ExpensesReportPageState();
}

class _ExpensesReportPageState extends State<ExpensesReportPage> {
  late DateTime _from;
  late Future<AppResult<ExpensesReport>> _future;
  late DateTime _to;

  SupabaseExpensesReportService get _service =>
      serviceLocator<SupabaseExpensesReportService>();

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
      title: 'Gastos al dia',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DailySalesFilterCard(
            from: _from,
            onMonthSelected: _selectCurrentMonth,
            onRangeChanged: _selectRange,
            onReload: _reload,
            onTodaySelected: _selectToday,
            to: _to,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AppResult<ExpensesReport>>(
            future: _future,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return const AppLoadingPage();

              return result.when(
                success: (report) => _ExpensesReportView(report: report),
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

  Future<AppResult<ExpensesReport>> _load() {
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
