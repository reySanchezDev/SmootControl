part of 'pos_bloc.dart';

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
