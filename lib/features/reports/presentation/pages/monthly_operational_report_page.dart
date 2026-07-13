import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/reports/data/services/supabase_monthly_operational_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';
import 'package:smoo_control/features/reports/presentation/widgets/monthly_operational_report_widgets.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Monthly operational comparison report page.
class MonthlyOperationalReportPage extends StatefulWidget {
  /// Creates the monthly operational report page.
  const MonthlyOperationalReportPage({super.key});

  @override
  State<MonthlyOperationalReportPage> createState() =>
      _MonthlyOperationalReportPageState();
}

class _MonthlyOperationalReportPageState
    extends State<MonthlyOperationalReportPage> {
  late DateTime _from;
  late Future<AppResult<MonthlyOperationalReport>> _future;
  late DateTime _to;

  SupabaseMonthlyOperationalReportService get _service =>
      serviceLocator<SupabaseMonthlyOperationalReportService>();

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
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.monthlyOperationalReportTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthlyOperationalFilterCard(
            from: _from,
            onMonthSelected: _selectCurrentMonth,
            onRangeChanged: _selectRange,
            onReload: _reload,
            onTodaySelected: _selectToday,
            to: _to,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AppResult<MonthlyOperationalReport>>(
            future: _future,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return const AppLoadingPage();

              return result.when(
                success: (report) =>
                    MonthlyOperationalReportView(report: report),
                failure: (failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.inventoryValueLoadErrorTitle,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<AppResult<MonthlyOperationalReport>> _load() {
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

class _MonthlyOperationalFilterCard extends StatelessWidget {
  const _MonthlyOperationalFilterCard({
    required this.from,
    required this.onMonthSelected,
    required this.onRangeChanged,
    required this.onReload,
    required this.onTodaySelected,
    required this.to,
  });

  final DateTime from;
  final VoidCallback onMonthSelected;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final VoidCallback onReload;
  final VoidCallback onTodaySelected;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final range = _DateRangeButton(
              from: from,
              onChanged: onRangeChanged,
              to: to,
            );
            final reload = FilledButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              label: AppText(l10n.reloadAction),
            );
            final chips = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.today_outlined, size: 18),
                  label: AppText(l10n.reportPeriodToday),
                  onPressed: onTodaySelected,
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_view_month, size: 18),
                  label: AppText(l10n.reportPeriodMonth),
                  onPressed: onMonthSelected,
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  range,
                  const SizedBox(height: 10),
                  chips,
                  const SizedBox(height: 10),
                  reload,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: range),
                const SizedBox(width: 10),
                chips,
                const SizedBox(width: 10),
                reload,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({
    required this.from,
    required this.onChanged,
    required this.to,
  });

  final DateTime from;
  final ValueChanged<DateTimeRange> onChanged;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          initialDateRange: DateTimeRange(start: from, end: to),
          lastDate: DateTime(2100),
        );
        if (selected != null) onChanged(selected);
      },
      icon: const Icon(Icons.event_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: AppText(_rangeLabel(from, to)),
      ),
    );
  }

  String _rangeLabel(DateTime start, DateTime end) {
    if (_sameDate(start, end)) return _formatDate(start);
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
