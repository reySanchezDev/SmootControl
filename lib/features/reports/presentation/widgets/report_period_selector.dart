import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Selector for report period and anchor date.
class ReportPeriodSelector extends StatelessWidget {
  /// Creates a report period selector.
  const ReportPeriodSelector({
    required this.onChanged,
    required this.period,
    required this.selectedDate,
    this.rangeFrom,
    this.rangeTo,
    super.key,
  });

  /// Selected period.
  final ReportPeriod period;

  /// Date used to calculate the selected period range.
  final DateTime selectedDate;

  /// Current calculated range start.
  final DateTime? rangeFrom;

  /// Current calculated exclusive range end.
  final DateTime? rangeTo;

  /// Called when either period or date changes.
  final void Function(
    ReportPeriod period,
    DateTime selectedDate,
    ReportDateRange? customRange,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 8,
        children: [
          SegmentedButton<ReportPeriod>(
            segments: [
              ButtonSegment(
                value: ReportPeriod.today,
                label: AppText(l10n.reportPeriodToday),
              ),
              ButtonSegment(
                value: ReportPeriod.week,
                label: AppText(l10n.reportPeriodWeek),
              ),
              ButtonSegment(
                value: ReportPeriod.month,
                label: AppText(l10n.reportPeriodMonth),
              ),
              ButtonSegment(
                value: ReportPeriod.year,
                label: AppText(l10n.reportPeriodYear),
              ),
              ButtonSegment(
                value: ReportPeriod.custom,
                label: AppText(l10n.reportPeriodCustom),
              ),
            ],
            selected: {period},
            onSelectionChanged: (selection) {
              final nextPeriod = selection.first;
              if (nextPeriod == ReportPeriod.custom) {
                unawaited(_selectRange(context));
                return;
              }
              onChanged(nextPeriod, selectedDate, null);
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {
              final action = period == ReportPeriod.custom
                  ? _selectRange
                  : _selectDate;
              unawaited(action(context));
            },
            tooltip: period == ReportPeriod.custom
                ? l10n.reportSelectRange
                : l10n.reportSelectDate,
          ),
          AppText(_rangeLabel(l10n), variant: AppTextVariant.label),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDate: selectedDate,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;
    onChanged(period, picked, null);
  }

  Future<void> _selectRange(BuildContext context) async {
    final initialRange = _initialDateRange();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDateRange: initialRange,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;
    final range = ReportDateRange(
      from: DateTime(picked.start.year, picked.start.month, picked.start.day),
      to: DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      ).add(const Duration(days: 1)),
    );
    onChanged(ReportPeriod.custom, range.from, range);
  }

  DateTimeRange _initialDateRange() {
    final from = rangeFrom ?? selectedDate;
    final to = rangeTo?.subtract(const Duration(days: 1)) ?? selectedDate;
    return DateTimeRange(start: from, end: to.isBefore(from) ? from : to);
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  String _rangeLabel(AppLocalizations l10n) {
    final from = rangeFrom;
    final to = rangeTo;
    if (from == null || to == null) return _formatDate(selectedDate);

    final inclusiveTo = to.subtract(const Duration(days: 1));
    return '${l10n.reportRangeLabel}: '
        '${_formatDate(from)} - ${_formatDate(inclusiveTo)}';
  }
}
