import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/cash_register/data/datasources/local_cash_register_datasource.dart';
import 'package:smoo_control/features/cash_register/data/models/cash_register_session_model.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// Cash register repository backed by the local offline database.
final class CashRegisterRepository implements ICashRegisterRepository {
  /// Creates a cash register repository.
  const CashRegisterRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalCashRegisterDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

  @override
  Future<AppResult<CashRegisterSession>> openSession(
    CashRegisterSession session,
  ) async {
    try {
      final sameDaySession = await _localDataSource.getSessionForCashierOnDate(
        businessDate: session.businessDate,
        cashierId: session.cashierId,
      );
      if (sameDaySession != null && sameDaySession.id != session.id) {
        return AppFailureResult(
          AppFailure(
            code: sameDaySession.status == CashRegisterStatus.open
                ? 'cash_register_already_open'
                : 'cash_register_day_already_closed',
            message: sameDaySession.status == CashRegisterStatus.open
                ? 'Este usuario ya tiene una caja abierta para este dia.'
                : 'La caja de este usuario ya fue cerrada para este dia.',
          ),
        );
      }

      final existingSession = await _localDataSource
          .getAnyOpenSessionForCashier(session.cashierId);
      if (existingSession != null && existingSession.id != session.id) {
        final isSameBusinessDate =
            BusinessDateFormatter.format(existingSession.businessDate) ==
            BusinessDateFormatter.format(session.businessDate);
        final message = isSameBusinessDate
            ? 'Este usuario ya tiene una caja abierta para este dia.'
            : 'Este usuario tiene una caja anterior abierta. '
                  'Debe cerrarla antes de abrir una nueva.';
        return AppFailureResult(
          AppFailure(
            code: isSameBusinessDate
                ? 'cash_register_already_open'
                : 'cash_register_previous_day_open',
            message: message,
          ),
        );
      }

      final model = CashRegisterSessionModel.fromEntity(session);
      final saved = await _localDataSource.openSession(model);
      final entity = saved.toEntity();
      await _enqueueSession(entity, SyncOperation.create);

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_open_failed',
          message: 'No se pudo abrir la caja local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSession(
    DateTime businessDate,
  ) async {
    try {
      final session = await _localDataSource.getOpenSession(businessDate);
      return AppSuccess(session?.toEntity());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_open_session_failed',
          message: 'No se pudo consultar la caja abierta.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSessionForCashier({
    required DateTime businessDate,
    required String cashierId,
  }) async {
    try {
      final session = await _localDataSource.getOpenSessionForCashier(
        businessDate: businessDate,
        cashierId: cashierId,
      );
      return AppSuccess(session?.toEntity());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_cashier_session_failed',
          message: 'No se pudo consultar la caja abierta del usuario.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<CashRegisterSession?>> getAnyOpenSessionForCashier(
    String cashierId,
  ) async {
    try {
      final session = await _localDataSource.getAnyOpenSessionForCashier(
        cashierId,
      );
      return AppSuccess(session?.toEntity());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_cashier_session_failed',
          message: 'No se pudo consultar la caja abierta del usuario.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<CashRegisterSession>>> getSessions({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final sessions = await _localDataSource.getSessions(from: from, to: to);
      return AppSuccess(
        sessions.map((session) => session.toEntity()).toList(),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_sessions_failed',
          message: 'No se pudo consultar las cajas del periodo.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<CashRegisterSummary>> getSummary(
    CashRegisterSession session,
  ) async {
    try {
      final model = CashRegisterSessionModel.fromEntity(session);
      final summary = await _localDataSource.getSummary(model);
      return AppSuccess(summary.toEntity());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_summary_failed',
          message: 'No se pudo calcular el resumen de caja.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<CashRegisterSession>> closeSession({
    required String sessionId,
    required int physicalClosingCashInCents,
  }) async {
    try {
      final current = await _localDataSource.getSessionById(sessionId);
      if (current?.status == CashRegisterStatus.closed) {
        return AppSuccess(current!.toEntity());
      }

      final session = await _localDataSource.closeSession(
        sessionId: sessionId,
        physicalClosingCashInCents: physicalClosingCashInCents,
      );
      final entity = session.toEntity();
      await _enqueueSession(entity, SyncOperation.update);

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_close_failed',
          message: 'No se pudo cerrar la caja local.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueueSession(
    CashRegisterSession session,
    SyncOperation operation,
  ) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'cash_register_sessions',
      entityId: session.id,
      operation: operation,
      payload: {
        'id': session.id,
        'cashierId': session.cashierId,
        'businessDate': session.businessDate.toIso8601String(),
        'openingCashInCents': session.openingCashInCents,
        'physicalClosingCashInCents': session.physicalClosingCashInCents,
        'status': session.status.name,
      },
    );
  }
}
