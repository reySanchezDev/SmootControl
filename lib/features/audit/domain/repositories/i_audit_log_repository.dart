import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';

/// Contract for audit log persistence.
abstract interface class IAuditLogRepository {
  /// Saves one audit log entry.
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry);

  /// Returns audit entries by date.
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date);
}
