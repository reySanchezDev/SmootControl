import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/features/reports/domain/services/report_summary_service.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_event.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_state.dart';

/// BLoC for business reports.
final class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  /// Creates a reports BLoC.
  ReportsBloc(this._summaryService) : super(const ReportsInitial()) {
    on<ReportsSummaryRequested>(_onSummaryRequested);
  }

  final ReportSummaryService _summaryService;

  Future<void> _onSummaryRequested(
    ReportsSummaryRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(
      ReportsLoading(period: event.period, customRange: event.customRange),
    );
    final result = await _summaryService.loadSummary(
      period: event.period,
      now: event.now,
      customRange: event.customRange,
    );

    emit(
      result.when(
        success: (summary) => ReportsLoaded(
          period: event.period,
          summary: summary,
        ),
        failure: (failure) => ReportsFailure(
          period: event.period,
          failure: failure,
          customRange: event.customRange,
        ),
      ),
    );
  }
}
