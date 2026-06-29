part of 'pos_bloc.dart';

Future<void> _saveSelectedSplitAccountSale(
  PosBloc bloc,
  PosReady current,
  PosCheckoutRequested event,
  Emitter<PosState> emit,
) async {
  final account = _selectedSplitAccount(current);
  if (account == null) {
    emit(
      const PosFailure(
        AppFailure(
          code: 'pos_split_account_required',
          message: 'Selecciona una cuenta separada para cobrar.',
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

  final invoiceNumbers = await _reserveInvoiceNumbers(
    bloc: bloc,
    count: 1,
    current: current,
    emit: emit,
  );
  if (invoiceNumbers == null) return;

  final accountsResult = await bloc._tablesRepository.saveTableAccounts([
    TableAccount(
      id: account.id,
      tableId: account.tableId,
      name: account.name,
      status: TableAccountStatus.invoiced,
    ),
  ]);
  switch (accountsResult) {
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      emit(current);
      return;
    case AppSuccess():
      break;
  }

  final now = DateTime.now();
  final saleId = const Uuid().v4();
  final items = _buildSplitItems(
    account: account,
    current: current,
    saleId: saleId,
    createdAt: now,
  );
  final total = items.fold(0, (sum, item) => sum + item.totalInCents);
  final sale = Sale(
    id: saleId,
    invoiceNumber: invoiceNumbers.single,
    tableId: current.selectedTableId,
    tableAccountId: account.id,
    cashRegisterSessionId: cashRegisterSessionId,
    paymentMethodId: current.selectedPaymentMethodId!,
    paymentReference: event.paymentReference?.trim().isEmpty ?? true
        ? null
        : event.paymentReference!.trim(),
    status: SaleStatus.completed,
    subtotalInCents: total,
    totalInCents: total,
    createdAt: now,
  );
  final result = await bloc._salesRepository.saveSale(sale: sale, items: items);
  switch (result) {
    case AppSuccess(:final value):
      var next = _stateAfterSplitAccountPayment(current, account, value);
      if (next.splitAccounts.isEmpty) {
        final ticketCleared = await _clearPersistedActiveTicket(
          bloc,
          current,
          emit,
        );
        if (!ticketCleared) {
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
        next = next.copyWith(tables: tables);
      }
      emit(next);
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      emit(current);
  }
}

AccountSplitDraft? _selectedSplitAccount(PosReady current) {
  final selectedId = current.selectedSplitAccountId;
  if (selectedId == null) return null;
  for (final account in current.splitAccounts) {
    if (account.id == selectedId) return account;
  }
  return null;
}

PosReady _stateAfterSplitAccountPayment(
  PosReady current,
  AccountSplitDraft paidAccount,
  Sale savedSale,
) {
  final remaining = [
    for (final account in current.splitAccounts)
      if (account.id != paidAccount.id) account,
  ];
  final accountsByTable = Map<String, List<AccountSplitDraft>>.of(
    current.splitAccountsByTable,
  );
  final sourceByTable = Map<String, List<PosCartLine>>.of(
    current.splitSourceLinesByTable,
  );
  if (remaining.isEmpty) {
    accountsByTable.remove(paidAccount.tableId);
    sourceByTable.remove(paidAccount.tableId);
  } else {
    accountsByTable[paidAccount.tableId] = remaining;
  }

  return current.copyWith(
    cartLines: const [],
    splitAccounts: remaining,
    splitAccountsByTable: accountsByTable,
    splitSourceLinesByTable: sourceByTable,
    clearSelectedSplitAccount: true,
    lastCompletedSale: savedSale,
    lastCompletedSales: [savedSale],
  );
}
