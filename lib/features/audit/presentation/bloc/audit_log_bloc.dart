import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_event.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_state.dart';

/// BLoC for audit log inspection.
final class AuditLogBloc extends Bloc<AuditLogEvent, AuditLogState> {
  /// Creates an audit log BLoC.
  AuditLogBloc(this._repository) : super(const AuditLogInitial()) {
    on<AuditLogDateRequested>(_onDateRequested);
  }

  final IAuditLogRepository _repository;

  Future<void> _onDateRequested(
    AuditLogDateRequested event,
    Emitter<AuditLogState> emit,
  ) async {
    emit(const AuditLogLoading());
    final result = await _repository.getEntriesByDate(event.date);
    emit(
      result.when(
        success: (entries) => AuditLogLoaded(
          date: event.date,
          entries: entries,
        ),
        failure: AuditLogFailure.new,
      ),
    );
  }
}
