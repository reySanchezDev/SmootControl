import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_bloc.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_event.dart';
import 'package:smoo_control/features/audit/presentation/bloc/audit_log_state.dart';

void main() {
  group('AuditLogBloc', () {
    final date = DateTime(2026, 6, 24);
    final entry = AuditLogEntry(
      id: 'audit-1',
      action: 'sales.void',
      entityName: 'sales',
      entityId: 'sale-1',
      details: const {'reason': 'Error'},
      occurredAt: date,
    );

    blocTest<AuditLogBloc, AuditLogState>(
      'loads audit entries by date',
      build: () => AuditLogBloc(
        _AuditRepositoryFake(result: AppSuccess([entry])),
      ),
      act: (bloc) => bloc.add(AuditLogDateRequested(date)),
      expect: () => [
        const AuditLogLoading(),
        AuditLogLoaded(date: date, entries: [entry]),
      ],
    );

    blocTest<AuditLogBloc, AuditLogState>(
      'emits failure when repository fails',
      build: () => AuditLogBloc(
        const _AuditRepositoryFake(
          result: AppFailureResult(
            AppFailure(code: 'audit_error', message: 'Error'),
          ),
        ),
      ),
      act: (bloc) => bloc.add(AuditLogDateRequested(date)),
      expect: () => const [
        AuditLogLoading(),
        AuditLogFailure(AppFailure(code: 'audit_error', message: 'Error')),
      ],
    );
  });
}

final class _AuditRepositoryFake implements IAuditLogRepository {
  const _AuditRepositoryFake({required this.result});

  final AppResult<List<AuditLogEntry>> result;

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return result;
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    return AppSuccess(entry);
  }
}
