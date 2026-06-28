import 'package:equatable/equatable.dart';

/// Result summary for a synchronization processing run.
final class SyncProcessSummary extends Equatable {
  /// Creates a sync processing summary.
  const SyncProcessSummary({
    required this.processed,
    required this.succeeded,
    required this.failed,
  });

  /// Total items inspected.
  final int processed;

  /// Items successfully pushed.
  final int succeeded;

  /// Items that failed.
  final int failed;

  @override
  List<Object?> get props => [processed, succeeded, failed];
}
