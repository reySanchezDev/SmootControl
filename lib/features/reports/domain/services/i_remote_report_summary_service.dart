import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';

/// Contract for online administrative report summaries.
abstract interface class IRemoteReportSummaryService {
  /// Whether remote reporting has enough configuration to run.
  bool get isConfigured;

  /// Loads a report summary from the central remote database.
  Future<AppResult<ReportSummary>> loadSummaryForRange(ReportDateRange range);
}
