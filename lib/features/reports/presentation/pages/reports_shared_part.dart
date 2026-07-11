part of 'reports_page.dart';

class _ReportAmountRow extends StatelessWidget {
  const _ReportAmountRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: AppText(label)),
          AppText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  return '$day/$month/$year';
}

String _rangeLabel(DateTime from, DateTime to) {
  if (_sameDate(from, to)) return 'Rango: ${_formatDate(from)}';
  return 'Rango: ${_formatDate(from)} - ${_formatDate(to)}';
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ReportsContent extends StatelessWidget {
  const _ReportsContent({
    required this.period,
    required this.selectedDate,
    this.child,
    this.rangeFrom,
    this.rangeTo,
    this.summary,
  });

  final Widget? child;
  final ReportPeriod period;
  final DateTime? rangeFrom;
  final DateTime? rangeTo;
  final DateTime selectedDate;
  final ReportSummary? summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReportPeriodSelector(
          period: period,
          rangeFrom: summary?.from ?? rangeFrom,
          rangeTo: summary?.to ?? rangeTo,
          selectedDate: selectedDate,
          onChanged: (period, selectedDate, customRange) {
            context.read<ReportsBloc>().add(
              ReportsSummaryRequested(
                period: period,
                now: selectedDate,
                customRange: customRange,
              ),
            );
          },
        ),
        Expanded(
          child:
              child ??
              (summary == null
                  ? const AppLoadingPage()
                  : ReportSummaryView(summary: summary!)),
        ),
      ],
    );
  }
}
