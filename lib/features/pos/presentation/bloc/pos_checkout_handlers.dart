part of 'pos_bloc.dart';

Future<void> _handleCheckoutRequested(
  PosBloc bloc,
  PosCheckoutRequested event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;

  final failure = _validateCheckout(current, event.paymentReference);
  if (failure != null) {
    emit(PosFailure(failure));
    emit(current);
    return;
  }

  if (bloc._checkoutInProgress) return;
  bloc._checkoutInProgress = true;
  try {
    if (current.selectedSplitAccountId != null) {
      await _saveSelectedSplitAccountSale(bloc, current, event, emit);
      return;
    }

    if (current.hasSplitAccounts) {
      await _saveSplitSales(bloc, current, emit);
      return;
    }

    await _saveSingleSale(bloc, current, event, emit);
  } finally {
    bloc._checkoutInProgress = false;
  }
}

Future<void> _handleStaffConsumptionRequested(
  PosBloc bloc,
  PosStaffConsumptionRequested event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;

  if (current.cartLines.isEmpty) {
    emit(
      const PosFailure(
        AppFailure(
          code: 'staff_consumption_empty_cart',
          message: 'Agrega productos antes de registrar consumo de personal.',
        ),
      ),
    );
    emit(current);
    return;
  }

  final paymentMethodId =
      current.selectedPaymentMethodId ??
      current.paymentMethods
          .where((method) => method.isPaymentTarget && method.isActive)
          .map((method) => method.id)
          .cast<String?>()
          .firstWhere((id) => id != null, orElse: () => null);
  if (paymentMethodId == null) {
    emit(
      const PosFailure(
        AppFailure(
          code: 'staff_consumption_payment_method_missing',
          message: 'Sincroniza metodos de pago antes de registrar consumo.',
        ),
      ),
    );
    emit(current);
    return;
  }

  final cashRegisterSessionId = await _openCashSessionId(
    bloc: bloc,
    current: current,
    emit: emit,
  );
  if (cashRegisterSessionId == _failedCashSessionLookup) return;

  final now = event.deliveredAt;
  final saleId = const Uuid().v4();
  final salesType = current.selectedSalesType;
  final sale = Sale(
    id: saleId,
    invoiceNumber: 'CP-PEND-${saleId.substring(0, 8)}',
    saleKind: SaleKind.staffConsumption,
    employeeId: event.employeeId,
    tableId: current.selectedTableId,
    cashRegisterSessionId: cashRegisterSessionId,
    paymentMethodId: paymentMethodId,
    salesTypeId: salesType?.id,
    salesTypeName: salesType?.name,
    status: SaleStatus.completed,
    subtotalInCents: current.totalInCents,
    totalInCents: current.totalInCents,
    createdAt: now,
  );
  final items = _buildConsolidatedSaleItems(
    lines: current.cartLines,
    current: current,
    saleId: saleId,
    createdAt: now,
  );

  final result = await bloc._salesRepository.saveSale(sale: sale, items: items);
  switch (result) {
    case AppSuccess(:final value):
      final ticketCleared = await _clearPersistedActiveTicket(
        bloc,
        current,
        emit,
      );
      if (!ticketCleared) {
        emit(current);
        return;
      }
      final contextCleared = await _clearPersistedActiveOrderContext(
        bloc,
        current,
        emit,
      );
      if (!contextCleared) {
        emit(current);
        return;
      }
      final tables = await _resetSelectedTableDisplayNameIfNeeded(
        bloc,
        current,
        emit,
      );
      if (tables == null) {
        emit(current);
        return;
      }
      emit(
        current.copyWith(
          cartLines: const [],
          cartLinesByTable: _cartsWithActiveCart(current, const []),
          salesTypeIdByOrderKey: _salesTypesWithoutActiveOrder(current),
          selectedSalesTypeId: _defaultSalesTypeId(current.salesTypes),
          splitAccountsByTable: _splitAccountsWithoutActiveTable(current),
          tables: tables,
          clearSplitAccounts: true,
          lastCompletedSale: value,
          lastCompletedSales: [value],
        ),
      );
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      emit(current);
  }
}

Future<void> _saveSingleSale(
  PosBloc bloc,
  PosReady current,
  PosCheckoutRequested event,
  Emitter<PosState> emit,
) async {
  final cashRegisterSessionId = await _openCashSessionId(
    bloc: bloc,
    current: current,
    emit: emit,
  );
  if (cashRegisterSessionId == _failedCashSessionLookup) return;

  final invoiceReservation = await _prepareInvoiceNumbers(
    bloc: bloc,
    count: 1,
    current: current,
    emit: emit,
  );
  if (invoiceReservation == null) return;

  final now = DateTime.now();
  final saleId = const Uuid().v4();
  final salesType = current.selectedSalesType;
  final sale = Sale(
    id: saleId,
    invoiceNumber: invoiceReservation.invoiceNumbers.single,
    tableId: current.selectedTableId,
    cashRegisterSessionId: cashRegisterSessionId,
    paymentMethodId: current.selectedPaymentMethodId!,
    salesTypeId: salesType?.id,
    salesTypeName: salesType?.name,
    paymentReference: event.paymentReference?.trim().isEmpty ?? true
        ? null
        : event.paymentReference!.trim(),
    status: SaleStatus.completed,
    subtotalInCents: current.totalInCents,
    totalInCents: current.totalInCents,
    createdAt: now,
  );
  final items = _buildConsolidatedSaleItems(
    lines: current.cartLines,
    current: current,
    saleId: saleId,
    createdAt: now,
  );

  final result = await bloc._salesRepository.saveSale(sale: sale, items: items);
  switch (result) {
    case AppSuccess(:final value):
      await _commitInvoiceNumbers(
        bloc: bloc,
        invoiceNumbers: invoiceReservation.invoiceNumbers,
        current: current,
        emit: emit,
      );
      final ticketCleared = await _clearPersistedActiveTicket(
        bloc,
        current,
        emit,
      );
      if (!ticketCleared) {
        emit(current);
        return;
      }
      final contextCleared = await _clearPersistedActiveOrderContext(
        bloc,
        current,
        emit,
      );
      if (!contextCleared) {
        emit(current);
        return;
      }
      final tables = await _resetSelectedTableDisplayNameIfNeeded(
        bloc,
        current,
        emit,
      );
      if (tables == null) {
        emit(current);
        return;
      }
      emit(
        current.copyWith(
          cartLines: const [],
          cartLinesByTable: _cartsWithActiveCart(current, const []),
          salesTypeIdByOrderKey: _salesTypesWithoutActiveOrder(current),
          selectedSalesTypeId: _defaultSalesTypeId(current.salesTypes),
          splitAccountsByTable: _splitAccountsWithoutActiveTable(current),
          tables: tables,
          clearSplitAccounts: true,
          lastCompletedSale: value,
          lastCompletedSales: [value],
        ),
      );
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      emit(current);
  }
}

Future<bool> _clearPersistedActiveTicket(
  PosBloc bloc,
  PosReady current,
  Emitter<PosState> emit,
) async {
  final tableId = current.selectedTableId;
  if (tableId == null) return true;

  final result = await bloc._openTicketRepository.saveTableTicket(
    tableId: tableId,
    lines: const [],
  );
  switch (result) {
    case AppSuccess():
      return true;
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return false;
  }
}

Future<bool> _clearPersistedActiveOrderContext(
  PosBloc bloc,
  PosReady current,
  Emitter<PosState> emit,
) async {
  final result = await bloc._openTicketRepository.clearOrderContext(
    current.activeCartKey,
  );
  switch (result) {
    case AppSuccess():
      return true;
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return false;
  }
}
