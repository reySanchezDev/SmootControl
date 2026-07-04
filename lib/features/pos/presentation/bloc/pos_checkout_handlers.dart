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

Future<void> _saveSplitSales(
  PosBloc bloc,
  PosReady current,
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
    count: current.splitAccounts.length,
    current: current,
    emit: emit,
  );
  if (invoiceReservation == null) return;

  final accounts = [
    for (final account in current.splitAccounts)
      TableAccount(
        id: account.id,
        tableId: account.tableId,
        name: account.name,
        status: TableAccountStatus.invoiced,
      ),
  ];
  final accountsResult = await bloc._tablesRepository.saveTableAccounts(
    accounts,
  );
  switch (accountsResult) {
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      emit(current);
      return;
    case AppSuccess():
      break;
  }

  final savedSales = <Sale>[];
  final now = DateTime.now();
  for (var index = 0; index < current.splitAccounts.length; index += 1) {
    final account = current.splitAccounts[index];
    final saleId = const Uuid().v4();
    final salesType = current.selectedSalesType;
    final items = _buildSplitItems(
      account: account,
      current: current,
      saleId: saleId,
      createdAt: now,
    );
    final total = items.fold(0, (sum, item) => sum + item.totalInCents);
    final sale = Sale(
      id: saleId,
      invoiceNumber: invoiceReservation.invoiceNumbers[index],
      tableId: current.selectedTableId,
      tableAccountId: account.id,
      cashRegisterSessionId: cashRegisterSessionId,
      paymentMethodId: account.paymentMethodId!,
      salesTypeId: salesType?.id,
      salesTypeName: salesType?.name,
      paymentReference: account.paymentReference?.trim().isEmpty ?? true
          ? null
          : account.paymentReference!.trim(),
      status: SaleStatus.completed,
      subtotalInCents: total,
      totalInCents: total,
      createdAt: now,
    );
    final result = await bloc._salesRepository.saveSale(
      sale: sale,
      items: items,
    );
    switch (result) {
      case AppSuccess(:final value):
        savedSales.add(value);
        await _commitInvoiceNumbers(
          bloc: bloc,
          invoiceNumbers: [invoiceReservation.invoiceNumbers[index]],
          current: current,
          emit: emit,
        );
      case AppFailureResult(:final error):
        emit(PosFailure(error));
        emit(current);
        return;
    }
  }

  final ticketCleared = await _clearPersistedActiveTicket(bloc, current, emit);
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
      lastCompletedSale: savedSales.last,
      lastCompletedSales: savedSales,
    ),
  );
}
