part of 'pos_bloc.dart';

Future<void> _handleProductAdded(
  PosBloc bloc,
  PosProductAdded event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;
  if (current.selectedTableId == null) {
    emit(
      const PosFailure(
        AppFailure(
          code: 'pos_table_required_for_product',
          message: 'Selecciona una mesa antes de agregar productos al pedido.',
        ),
      ),
    );
    emit(current);
    return;
  }
  if (current.selectedSplitAccountId != null) return;

  final newLine = PosCartLine(
    product: event.product,
    quantity: 1,
    ticketLineId: const Uuid().v4(),
    selectedOptions: event.selectedOptions,
  );
  final lines = [...current.cartLines];
  final index = lines.indexWhere((line) {
    return line.cartKey == newLine.cartKey && !line.isServed;
  });
  if (index == -1) {
    lines.add(newLine);
  } else {
    lines[index] = lines[index].incremented();
  }

  await _emitCartUpdate(bloc: bloc, current: current, lines: lines, emit: emit);
}

Future<void> _handleProductRemoved(
  PosBloc bloc,
  PosProductRemoved event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;
  if (current.selectedSplitAccountId != null) return;
  final lines = current.cartLines
      .where((line) => line.lineKey != event.cartLineKey)
      .toList();

  await _emitCartUpdate(bloc: bloc, current: current, lines: lines, emit: emit);
}

Future<void> _handleCartLineIncremented(
  PosBloc bloc,
  PosCartLineIncremented event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;
  if (current.selectedSplitAccountId != null) return;
  final lines = <PosCartLine>[];
  for (final line in current.cartLines) {
    if (line.lineKey != event.cartLineKey) {
      lines.add(line);
      continue;
    }
    if (line.isServed) {
      lines
        ..add(line)
        ..add(
          PosCartLine(
            product: line.product,
            quantity: 1,
            ticketLineId: const Uuid().v4(),
            selectedOptions: line.selectedOptions,
          ),
        );
      continue;
    }
    lines.add(line.incremented());
  }

  await _emitCartUpdate(bloc: bloc, current: current, lines: lines, emit: emit);
}

Future<void> _handleCartLineDecremented(
  PosBloc bloc,
  PosCartLineDecremented event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;
  if (current.selectedSplitAccountId != null) return;
  final lines = [
    for (final line in current.cartLines)
      if (line.lineKey == event.cartLineKey) line.decremented() else line,
  ];

  await _emitCartUpdate(bloc: bloc, current: current, lines: lines, emit: emit);
}

Future<void> _handleCartLineServedToggled(
  PosBloc bloc,
  PosCartLineServedToggled event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;
  if (current.selectedSplitAccountId != null) return;
  final lines = [
    for (final line in current.cartLines)
      if (line.lineKey == event.cartLineKey)
        line.copyWith(isServed: !line.isServed)
      else
        line,
  ];

  await _emitCartUpdate(bloc: bloc, current: current, lines: lines, emit: emit);
}

void _handleTableSelected(
  PosBloc bloc,
  PosTableSelected event,
  Emitter<PosState> emit,
) {
  final current = bloc.state;
  if (current is! PosReady) return;
  final key = event.tableId ?? '__no_table__';
  final selectedSalesTypeId =
      current.salesTypeIdByOrderKey[key] ??
      _defaultSalesTypeId(current.salesTypes);

  emit(
    current.copyWith(
      cartLines: current.cartLinesByTable[key] ?? const [],
      selectedTableId: event.tableId,
      selectedSalesTypeId: selectedSalesTypeId,
      splitAccounts: event.tableId == null
          ? const []
          : current.splitAccountsByTable[event.tableId] ?? const [],
      clearSelectedSplitAccount: true,
      clearSelectedTable: event.tableId == null,
      clearLastCompletedSale: true,
    ),
  );
}

Future<void> _handleSalesTypeSelected(
  PosBloc bloc,
  PosSalesTypeSelected event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;

  final updatedByOrder = Map<String, String>.from(
    current.salesTypeIdByOrderKey,
  )..[current.activeCartKey] = event.salesTypeId;
  final result = await bloc._openTicketRepository.saveOrderSalesType(
    orderKey: current.activeCartKey,
    salesTypeId: event.salesTypeId,
  );
  switch (result) {
    case AppSuccess():
      emit(
        current.copyWith(
          salesTypeIdByOrderKey: updatedByOrder,
          selectedSalesTypeId: event.salesTypeId,
          clearLastCompletedSale: true,
        ),
      );
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      emit(current);
  }
}

void _handleSplitAccountSelected(
  PosBloc bloc,
  PosSplitAccountSelected event,
  Emitter<PosState> emit,
) {
  final current = bloc.state;
  if (current is! PosReady) return;
  final accounts = current.splitAccountsByTable[event.tableId] ?? const [];
  AccountSplitDraft? selectedAccount;
  for (final account in accounts) {
    if (account.id == event.accountId) {
      selectedAccount = account;
      break;
    }
  }
  if (selectedAccount == null) return;

  final sourceLines =
      current.splitSourceLinesByTable[event.tableId] ?? const <PosCartLine>[];
  emit(
    current.copyWith(
      cartLines: _cartLinesForSplitAccount(selectedAccount, sourceLines),
      selectedTableId: event.tableId,
      selectedSplitAccountId: event.accountId,
      splitAccounts: accounts,
      clearLastCompletedSale: true,
    ),
  );
}

Future<void> _handleCartCleared(
  PosBloc bloc,
  PosCartCleared event,
  Emitter<PosState> emit,
) async {
  final current = bloc.state;
  if (current is! PosReady) return;
  if (current.selectedSplitAccountId != null) return;

  await _emitCartUpdate(
    bloc: bloc,
    current: current,
    lines: const [],
    emit: emit,
  );
}

Future<void> _emitCartUpdate({
  required PosBloc bloc,
  required PosReady current,
  required List<PosCartLine> lines,
  required Emitter<PosState> emit,
}) async {
  if (current.selectedTableId != null) {
    final result = await bloc._openTicketRepository.saveTableTicket(
      tableId: current.selectedTableId!,
      lines: lines,
    );
    switch (result) {
      case AppSuccess():
        break;
      case AppFailureResult(:final error):
        emit(PosFailure(error));
        emit(current);
        return;
    }
  }

  final tables = lines.isEmpty
      ? await _resetSelectedTableDisplayNameIfNeeded(bloc, current, emit)
      : current.tables;
  if (tables == null) {
    emit(current);
    return;
  }

  emit(
    current.copyWith(
      cartLines: lines,
      cartLinesByTable: _cartsWithActiveCart(current, lines),
      splitAccountsByTable: _splitAccountsWithoutActiveTable(current),
      tables: tables,
      clearSplitAccounts: true,
      clearLastCompletedSale: true,
    ),
  );
}

Map<String, List<PosCartLine>> _cartsWithActiveCart(
  PosReady current,
  List<PosCartLine> lines,
) {
  final carts = Map<String, List<PosCartLine>>.of(
    current.cartLinesByTable,
  );
  if (lines.isEmpty) {
    carts.remove(current.activeCartKey);
  } else {
    carts[current.activeCartKey] = lines;
  }
  return carts;
}

Map<String, List<AccountSplitDraft>> _splitAccountsWithoutActiveTable(
  PosReady current,
) {
  return Map<String, List<AccountSplitDraft>>.of(
    current.splitAccountsByTable,
  )..remove(current.activeCartKey);
}
