part of 'pos_bloc.dart';

Future<void> _handlePosCashRegisterOpened(
  PosBloc bloc,
  PosCashRegisterOpened event,
  Emitter<PosState> emit,
) async {
  emit(const PosLoading());
  final result = await bloc._cashRegisterRepository.openSession(event.session);

  switch (result) {
    case AppSuccess(:final value):
      await _saveCashAuditEntry(
        bloc: bloc,
        action: 'cash.open',
        session: value,
        details: {'openingCashInCents': value.openingCashInCents},
      );
      await _handlePosStarted(bloc, const PosStarted(), emit);
    case AppFailureResult(:final error):
      emit(PosFailure(error));
  }
}

Future<void> _handlePosCashRegisterClosed(
  PosBloc bloc,
  PosCashRegisterClosed event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is PosStaleCashRegisterRequired) {
    await _closeCashRegisterSession(
      bloc: bloc,
      emit: emit,
      session: current.session,
      physicalClosingCashInCents: event.physicalClosingCashInCents,
      onSuccess: () => emit(const PosCashRegisterRequired()),
      onFailure: (error) {
        emit(PosFailure(error));
        emit(current);
      },
    );
    return;
  }

  if (current is! PosReady) return;

  final session = current.openCashRegisterSession;
  if (session == null) {
    emit(const PosCashRegisterRequired());
    return;
  }

  final hasPendingCart =
      current.cartLines.isNotEmpty ||
      current.cartLinesByTable.values.any((lines) => lines.isNotEmpty);
  if (hasPendingCart) {
    emit(
      const PosFailure(
        AppFailure(
          code: 'pos_close_cash_pending_cart',
          message: 'No se puede cerrar caja con productos pendientes.',
        ),
      ),
    );
    emit(current);
    return;
  }

  await _closeCashRegisterSession(
    bloc: bloc,
    emit: emit,
    session: session,
    physicalClosingCashInCents: event.physicalClosingCashInCents,
    onSuccess: () => emit(const PosCashRegisterRequired()),
    onFailure: (error) {
      emit(PosFailure(error));
      emit(current);
    },
  );
}

Future<void> _closeCashRegisterSession({
  required PosBloc bloc,
  required Emitter<PosState> emit,
  required CashRegisterSession session,
  required int physicalClosingCashInCents,
  required void Function() onSuccess,
  required void Function(AppFailure error) onFailure,
}) async {
  emit(const PosLoading());
  final result = await bloc._cashRegisterRepository.closeSession(
    sessionId: session.id,
    physicalClosingCashInCents: physicalClosingCashInCents,
  );
  switch (result) {
    case AppSuccess(:final value):
      await _saveCashAuditEntry(
        bloc: bloc,
        action: 'cash.close',
        session: value,
        details: {
          'physicalClosingCashInCents': physicalClosingCashInCents,
        },
      );
      final clearResult = await bloc._openTicketRepository.clearAllOpenOrders();
      switch (clearResult) {
        case AppSuccess():
          break;
        case AppFailureResult(:final error):
          onFailure(error);
          return;
      }
      onSuccess();
    case AppFailureResult(:final error):
      onFailure(error);
  }
}

Future<void> _saveCashAuditEntry({
  required PosBloc bloc,
  required String action,
  required CashRegisterSession session,
  required Map<String, Object?> details,
}) async {
  await bloc._auditLogRepository.saveEntry(
    AuditLogEntry(
      id: const Uuid().v4(),
      actorUserId: session.cashierId,
      action: action,
      entityName: 'cash_register_sessions',
      entityId: session.id,
      details: details,
      occurredAt: DateTime.now(),
    ),
  );
}
