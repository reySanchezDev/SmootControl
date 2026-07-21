part of 'reports_page.dart';

/// Cash closing report page.
class CashClosingReportPage extends StatefulWidget {
  /// Creates the cash closing report page.
  const CashClosingReportPage({super.key});

  @override
  State<CashClosingReportPage> createState() => _CashClosingReportPageState();
}

class _CashClosingReportPageState extends State<CashClosingReportPage> {
  late DateTime _from;
  late Future<AppResult<CashClosingReport>> _future;
  late DateTime _to;

  SupabaseCashClosingReportService get _service =>
      serviceLocator<SupabaseCashClosingReportService>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = _from;
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Arqueo de caja',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DailySalesFilterCard(
            compactActions: true,
            from: _from,
            onMonthSelected: _selectCurrentMonth,
            onRangeChanged: _selectRange,
            onReload: _reload,
            onTodaySelected: _selectToday,
            to: _to,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AppResult<CashClosingReport>>(
            future: _future,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return const AppLoadingPage();
              return result.when(
                success: (report) => _CashClosingReportView(
                  onPdfRequested: _shareSessionReport,
                  report: report,
                ),
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

  Future<AppResult<CashClosingReport>> _load() {
    return _service.load(from: _from, to: _to);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _shareSessionReport(CashClosingSessionReport session) async {
    final report = CashClosingReport(
      from: session.businessDate,
      generatedAt: DateTime.now(),
      sessions: [session],
      to: session.businessDate,
    );
    final bytes = await const CashClosingPdfService().buildPdf(report);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'arqueo-caja-${_fileDate(session.businessDate)}.pdf',
    );
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

  String _fileDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}$month$day';
  }
}
