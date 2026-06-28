/// Periods available in the initial reports screen.
enum ReportPeriod {
  /// Current business day.
  today,

  /// Current calendar week.
  week,

  /// Current calendar month.
  month,

  /// Current calendar year.
  year,

  /// User-selected date range.
  custom,
}

/// Date range generated from a report period.
final class ReportDateRange {
  /// Creates a report date range.
  const ReportDateRange({
    required this.from,
    required this.to,
  });

  /// Inclusive range start.
  final DateTime from;

  /// Exclusive range end.
  final DateTime to;
}

/// Helpers for report periods.
extension ReportPeriodRange on ReportPeriod {
  /// Returns the date range represented by the period.
  ReportDateRange rangeFor(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    return switch (this) {
      ReportPeriod.today => ReportDateRange(
        from: today,
        to: today.add(const Duration(days: 1)),
      ),
      ReportPeriod.week => ReportDateRange(
        from: today.subtract(Duration(days: now.weekday - 1)),
        to: today
            .subtract(Duration(days: now.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      ReportPeriod.month => ReportDateRange(
        from: DateTime(now.year, now.month),
        to: DateTime(now.year, now.month + 1),
      ),
      ReportPeriod.year => ReportDateRange(
        from: DateTime(now.year),
        to: DateTime(now.year + 1),
      ),
      ReportPeriod.custom => ReportDateRange(
        from: today,
        to: today.add(const Duration(days: 1)),
      ),
    };
  }
}
