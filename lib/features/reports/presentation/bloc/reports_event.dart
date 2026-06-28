import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';

/// Base reports event.
sealed class ReportsEvent extends Equatable {
  /// Creates a reports event.
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the report summary for a period.
final class ReportsSummaryRequested extends ReportsEvent {
  /// Creates a summary load event.
  const ReportsSummaryRequested({
    required this.period,
    required this.now,
    this.customRange,
  });

  /// Selected report period.
  final ReportPeriod period;

  /// Current date used to calculate period boundaries.
  final DateTime now;

  /// User-selected custom range.
  final ReportDateRange? customRange;

  @override
  List<Object?> get props => [period, now, customRange];
}
