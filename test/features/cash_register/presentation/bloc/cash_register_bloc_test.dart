import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/cash_register/presentation/bloc/cash_register_bloc.dart';
import 'package:smoo_control/features/cash_register/presentation/bloc/cash_register_event.dart';
import 'package:smoo_control/features/cash_register/presentation/bloc/cash_register_state.dart';

void main() {
  group('CashRegisterBloc', () {
    final session = CashRegisterSession(
      id: 'session-1',
      cashierId: 'cashier-1',
      businessDate: DateTime(2026, 6, 23),
      openingCashInCents: 10000,
      status: CashRegisterStatus.open,
    );
    final summary = CashRegisterSummary(
      session: session,
      cashSalesInCents: 5000,
      expensesInCents: 1000,
    );

    blocTest<CashRegisterBloc, CashRegisterState>(
      'opens cash register and writes audit log',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () => CashRegisterBloc(
        repository: _CashRegisterRepositoryFake(
          openResult: AppSuccess(session),
          summaryResult: AppSuccess(summary),
        ),
        auditLogRepository: audit,
      ),
      act: (bloc) => bloc.add(CashRegisterOpened(session)),
      expect: () => [
        const CashRegisterLoading(),
        CashRegisterSuccess(summary),
      ],
      verify: (_) {
        expect(audit.entries.single.action, 'cash.open');
        expect(audit.entries.single.entityId, 'session-1');
        expect(audit.entries.single.actorUserId, 'cashier-1');
      },
    );

    blocTest<CashRegisterBloc, CashRegisterState>(
      'closes cash register and writes audit log',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () => CashRegisterBloc(
        repository: _CashRegisterRepositoryFake(
          openResult: AppSuccess(session),
          summaryResult: AppSuccess(summary),
        ),
        auditLogRepository: audit,
      ),
      act: (bloc) => bloc.add(
        const CashRegisterClosed(
          sessionId: 'session-1',
          physicalClosingCashInCents: 14000,
        ),
      ),
      expect: () => [
        const CashRegisterLoading(),
        CashRegisterSuccess(summary),
      ],
      verify: (_) {
        expect(audit.entries.single.action, 'cash.close');
        expect(audit.entries.single.entityId, 'session-1');
      },
    );

    blocTest<CashRegisterBloc, CashRegisterState>(
      'emits failure when open fails',
      build: () => CashRegisterBloc(
        repository: _CashRegisterRepositoryFake(
          openResult: const AppFailureResult(
            AppFailure(code: 'cash_error', message: 'Error'),
          ),
        ),
        auditLogRepository: AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(CashRegisterOpened(session)),
      expect: () => const [
        CashRegisterLoading(),
        CashRegisterFailure(AppFailure(code: 'cash_error', message: 'Error')),
      ],
    );
  });
}

late AuditLogRepositoryFake audit;

final class _CashRegisterRepositoryFake implements ICashRegisterRepository {
  _CashRegisterRepositoryFake({
    required this.openResult,
    this.summaryResult,
  });

  final AppResult<CashRegisterSession> openResult;
  final AppResult<CashRegisterSummary>? summaryResult;

  @override
  Future<AppResult<CashRegisterSession>> openSession(
    CashRegisterSession session,
  ) async {
    return openResult;
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSession(
    DateTime businessDate,
  ) async {
    return openResult.when<AppResult<CashRegisterSession?>>(
      success: AppSuccess<CashRegisterSession?>.new,
      failure: AppFailureResult<CashRegisterSession?>.new,
    );
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSessionForCashier({
    required DateTime businessDate,
    required String cashierId,
  }) async {
    return getOpenSession(businessDate);
  }

  @override
  Future<AppResult<CashRegisterSession?>> getAnyOpenSessionForCashier(
    String cashierId,
  ) async {
    return getOpenSession(DateTime.now());
  }

  @override
  Future<AppResult<List<CashRegisterSession>>> getSessions({
    required DateTime from,
    required DateTime to,
  }) async {
    return openResult.when<AppResult<List<CashRegisterSession>>>(
      success: (session) => AppSuccess([session]),
      failure: AppFailureResult<List<CashRegisterSession>>.new,
    );
  }

  @override
  Future<AppResult<CashRegisterSummary>> getSummary(
    CashRegisterSession session,
  ) async {
    return summaryResult ??
        AppSuccess(
          CashRegisterSummary(
            session: session,
            cashSalesInCents: 0,
            expensesInCents: 0,
          ),
        );
  }

  @override
  Future<AppResult<CashRegisterSession>> closeSession({
    required String sessionId,
    required int physicalClosingCashInCents,
  }) async {
    return openResult;
  }
}

final class AuditLogRepositoryFake implements IAuditLogRepository {
  final List<AuditLogEntry> entries = [];

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return AppSuccess(entries);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    entries.add(entry);
    return AppSuccess(entry);
  }
}
