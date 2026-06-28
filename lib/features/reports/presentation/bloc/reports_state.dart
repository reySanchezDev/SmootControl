import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';

/// Base reports state.
sealed class ReportsState extends Equatable {
  /// Creates a reports state.
  const ReportsState();

  @override
  List<Object?> get props => [];
}

/// Initial reports state.
final class ReportsInitial extends ReportsState {
  /// Creates an initial reports state.
  const ReportsInitial();
}

/// Loading reports state.
final class ReportsLoading extends ReportsState {
  /// Creates a loading reports state.
  const ReportsLoading({
    required this.period,
    this.customRange,
  });

  /// Period being loaded.
  final ReportPeriod period;

  /// User-selected custom range.
  final ReportDateRange? customRange;

  @override
  List<Object?> get props => [period, customRange];
}

/// Loaded reports state.
final class ReportsLoaded extends ReportsState {
  /// Creates a loaded reports state.
  const ReportsLoaded({
    required this.period,
    required this.summary,
  });

  /// Selected period.
  final ReportPeriod period;

  /// Calculated summary.
  final ReportSummary summary;

  @override
  List<Object?> get props => [period, summary];
}

/// Reports failure state.
final class ReportsFailure extends ReportsState {
  /// Creates a reports failure state.
  const ReportsFailure({
    required this.period,
    required this.failure,
    this.customRange,
  });

  /// Selected period.
  final ReportPeriod period;

  /// Failure details.
  final AppFailure failure;

  /// User-selected custom range.
  final ReportDateRange? customRange;

  @override
  List<Object?> get props => [period, failure, customRange];
}
