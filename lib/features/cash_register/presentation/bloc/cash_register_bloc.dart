import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/cash_register/presentation/bloc/cash_register_event.dart';
import 'package:smoo_control/features/cash_register/presentation/bloc/cash_register_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for daily cash register open and close operations.
final class CashRegisterBloc
    extends Bloc<CashRegisterEvent, CashRegisterState> {
  /// Creates a cash register BLoC.
  CashRegisterBloc({
    required ICashRegisterRepository repository,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const CashRegisterInitial()) {
    on<CashRegisterStarted>(_onCashRegisterStarted);
    on<CashRegisterOpened>(_onCashRegisterOpened);
    on<CashRegisterClosed>(_onCashRegisterClosed);
  }

  final ICashRegisterRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onCashRegisterStarted(
    CashRegisterStarted event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(const CashRegisterLoading());
    final result = await _repository.getOpenSession(DateTime.now());
    switch (result) {
      case AppSuccess(:final value):
        if (value == null) {
          emit(const CashRegisterInitial());
          return;
        }
        await _emitSummary(value, emit);
      case AppFailureResult(:final error):
        emit(CashRegisterFailure(error));
    }
  }

  Future<void> _onCashRegisterOpened(
    CashRegisterOpened event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(const CashRegisterLoading());
    final result = await _repository.openSession(event.session);
    switch (result) {
      case AppSuccess(:final value):
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            actorUserId: value.cashierId,
            action: 'cash.open',
            entityName: 'cash_register_sessions',
            entityId: value.id,
            details: {'openingCashInCents': value.openingCashInCents},
            occurredAt: DateTime.now(),
          ),
        );
        await _emitSummary(value, emit);
      case AppFailureResult(:final error):
        emit(CashRegisterFailure(error));
    }
  }

  Future<void> _onCashRegisterClosed(
    CashRegisterClosed event,
    Emitter<CashRegisterState> emit,
  ) async {
    emit(const CashRegisterLoading());
    final result = await _repository.closeSession(
      sessionId: event.sessionId,
      physicalClosingCashInCents: event.physicalClosingCashInCents,
    );
    switch (result) {
      case AppSuccess(:final value):
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            actorUserId: value.cashierId,
            action: 'cash.close',
            entityName: 'cash_register_sessions',
            entityId: event.sessionId,
            details: {
              'physicalClosingCashInCents': event.physicalClosingCashInCents,
            },
            occurredAt: DateTime.now(),
          ),
        );
        await _emitSummary(value, emit);
      case AppFailureResult(:final error):
        emit(CashRegisterFailure(error));
    }
  }

  Future<void> _emitSummary(
    CashRegisterSession session,
    Emitter<CashRegisterState> emit,
  ) async {
    final summaryResult = await _repository.getSummary(session);
    emit(
      summaryResult.when(
        success: CashRegisterSuccess.new,
        failure: CashRegisterFailure.new,
      ),
    );
  }
}
