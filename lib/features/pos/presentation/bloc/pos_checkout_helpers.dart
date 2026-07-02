part of 'pos_bloc.dart';

const String _failedCashSessionLookup = '__cash_session_lookup_failed__';

Future<String?> _openCashSessionId({
  required PosBloc bloc,
  required PosReady current,
  required Emitter<PosState> emit,
}) async {
  final session = current.openCashRegisterSession;
  if (session != null) return session.id;

  final result = await bloc._cashRegisterRepository.getOpenSessionForCashier(
    businessDate: DateTime.now(),
    cashierId: bloc._currentOperatorService.userId,
  );

  return switch (result) {
    AppSuccess(:final value) =>
      value?.id ??
          _emitCashSessionFailure(
            emit: emit,
            current: current,
            error: const AppFailure(
              code: 'pos_cash_register_required',
              message: 'Abre la caja diaria antes de cobrar.',
            ),
          ),
    AppFailureResult(:final error) => _emitCashSessionFailure(
      emit: emit,
      current: current,
      error: error,
    ),
  };
}

String _emitCashSessionFailure({
  required Emitter<PosState> emit,
  required PosReady current,
  required AppFailure error,
}) {
  emit(PosFailure(error));
  emit(current);
  return _failedCashSessionLookup;
}

Future<List<String>?> _reserveInvoiceNumbers({
  required PosBloc bloc,
  required int count,
  required PosReady current,
  required Emitter<PosState> emit,
}) async {
  final settingsResult = await bloc._settingsRepository.getSettings();
  final settings = switch (settingsResult) {
    AppSuccess(:final value) => value,
    AppFailureResult(:final error) => _emitReservationFailure(
      emit: emit,
      current: current,
      error: error,
    ),
  };

  if (settings == null) return null;

  final firstNumber = settings.nextInvoiceNumber < settings.initialInvoiceNumber
      ? settings.initialInvoiceNumber
      : settings.nextInvoiceNumber;
  final prefix = settings.invoicePrefix.trim().isEmpty
      ? BusinessSettings.empty.invoicePrefix
      : settings.invoicePrefix.trim().toUpperCase();
  final separator = prefix.endsWith('-') ? '' : '-';
  final numbers = [
    for (var index = 0; index < count; index += 1)
      '$prefix$separator${firstNumber + index}',
  ];
  final saveResult = await bloc._settingsRepository.saveSettings(
    settings.copyWith(nextInvoiceNumber: firstNumber + count),
  );

  switch (saveResult) {
    case AppSuccess():
      return numbers;
    case AppFailureResult(:final error):
      _emitReservationFailure(emit: emit, current: current, error: error);
      return null;
  }
}

BusinessSettings? _emitReservationFailure({
  required Emitter<PosState> emit,
  required PosReady current,
  required AppFailure error,
}) {
  emit(PosFailure(error));
  emit(current);
  return null;
}

List<SaleItem> _buildSplitItems({
  required AccountSplitDraft account,
  required PosReady current,
  required String saleId,
  required DateTime createdAt,
}) {
  final productById = {
    for (final product in current.products) product.id: product,
  };
  final sourceLines =
      current.splitSourceLinesByTable[account.tableId] ?? current.cartLines;
  final draftById = {
    for (final item in _splitDraftItemsFromLines(sourceLines)) item.id: item,
  };

  return _consolidateSaleItems([
    for (final itemId in account.itemIds)
      SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        tableId: current.selectedTableId,
        tableAccountId: account.id,
        productId: draftById[itemId]!.productId,
        productName: draftById[itemId]!.productName,
        selectedOptionsLabel: draftById[itemId]!.selectedOptionsLabel,
        categoryName: _categoryName(
          categories: current.categories,
          categoryId: productById[draftById[itemId]!.productId]!.categoryId,
        ),
        quantity: 1,
        unitPriceInCents: draftById[itemId]!.unitPriceInCents,
        unitCostInCents: productById[draftById[itemId]!.productId]!.costInCents,
        createdAt: createdAt,
      ),
  ]);
}

List<SaleItem> _buildConsolidatedSaleItems({
  required List<PosCartLine> lines,
  required PosReady current,
  required String saleId,
  required DateTime createdAt,
}) {
  return _consolidateSaleItems([
    for (final line in lines)
      SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        tableId: current.selectedTableId,
        productId: line.product.id,
        productName: line.product.name,
        categoryName: _categoryName(
          categories: current.categories,
          categoryId: line.product.categoryId,
        ),
        selectedOptionsLabel: line.selectedOptionsLabel.isEmpty
            ? null
            : line.selectedOptionsLabel,
        quantity: line.quantity,
        unitPriceInCents: line.product.priceInCents,
        unitCostInCents: line.product.costInCents,
        createdAt: createdAt,
      ),
  ]);
}

List<SaleItem> _consolidateSaleItems(List<SaleItem> items) {
  final itemsByKey = <String, SaleItem>{};
  for (final item in items) {
    final key = [
      item.tableId ?? '',
      item.tableAccountId ?? '',
      item.productId,
      item.productName,
      item.categoryName,
      item.selectedOptionsLabel ?? '',
      item.unitPriceInCents,
      item.unitCostInCents,
    ].join('|');
    final existing = itemsByKey[key];
    if (existing == null) {
      itemsByKey[key] = item;
      continue;
    }
    itemsByKey[key] = SaleItem(
      id: existing.id,
      saleId: existing.saleId,
      tableId: existing.tableId,
      tableAccountId: existing.tableAccountId,
      productId: existing.productId,
      productName: existing.productName,
      selectedOptionsLabel: existing.selectedOptionsLabel,
      categoryName: existing.categoryName,
      quantity: existing.quantity + item.quantity,
      unitPriceInCents: existing.unitPriceInCents,
      unitCostInCents: existing.unitCostInCents,
      createdAt: existing.createdAt,
    );
  }
  return itemsByKey.values.toList();
}

List<SaleItemDraft> _splitDraftItemsFromLines(List<PosCartLine> lines) {
  final items = <SaleItemDraft>[];
  for (final line in lines) {
    for (var index = 0; index < line.quantity; index += 1) {
      final itemId = '${line.lineKey}-$index';
      items.add(
        SaleItemDraft(
          id: itemId,
          productId: line.product.id,
          productName: line.product.name,
          selectedOptionsLabel: line.selectedOptionsLabel.isEmpty
              ? null
              : line.selectedOptionsLabel,
          quantity: 1,
          unitPriceInCents: line.product.priceInCents,
        ),
      );
    }
  }
  return items;
}

List<PosCartLine> _cartLinesForSplitAccount(
  AccountSplitDraft account,
  List<PosCartLine> sourceLines,
) {
  final selectedIds = account.itemIds.toSet();
  final linesByKey = <String, PosCartLine>{};
  for (final line in sourceLines) {
    var quantity = 0;
    for (var index = 0; index < line.quantity; index += 1) {
      final itemId = '${line.lineKey}-$index';
      if (selectedIds.contains(itemId)) quantity += 1;
    }
    if (quantity > 0) {
      linesByKey[line.lineKey] = PosCartLine(
        product: line.product,
        quantity: quantity,
        isServed: line.isServed,
        ticketLineId: line.lineKey,
        selectedOptions: line.selectedOptions,
      );
    }
  }
  return linesByKey.values.toList();
}

Map<String, String> _salesTypesWithoutActiveOrder(PosReady current) {
  return Map<String, String>.from(current.salesTypeIdByOrderKey)
    ..remove(current.activeCartKey);
}

String _categoryName({
  required List<ProductCategory> categories,
  required String categoryId,
}) {
  for (final category in categories) {
    if (category.id == categoryId) return category.name;
  }

  return '';
}

AppFailure? _validateCheckout(PosReady state, String? reference) {
  if (state.cartLines.isEmpty) {
    return const AppFailure(
      code: 'pos_empty_cart',
      message: 'Agrega al menos un producto para facturar.',
    );
  }

  if (state.selectedSplitAccountId != null) {
    return _validateSingleSplitCheckout(state, reference);
  }

  if (state.hasSplitAccounts) {
    return _validateSplitCheckout(state);
  }

  final selectedMethod = state.selectedPaymentMethod;
  if (selectedMethod == null) {
    return const AppFailure(
      code: 'pos_payment_method_required',
      message: 'Selecciona un metodo de pago.',
    );
  }

  if (selectedMethod.requiresReference && (reference?.trim().isEmpty ?? true)) {
    return const AppFailure(
      code: 'pos_reference_required',
      message: 'Este metodo de pago requiere referencia.',
    );
  }

  return null;
}

AppFailure? _validateSingleSplitCheckout(PosReady state, String? reference) {
  final selectedMethod = state.selectedPaymentMethod;
  if (selectedMethod == null) {
    return const AppFailure(
      code: 'pos_payment_method_required',
      message: 'Selecciona un metodo de pago.',
    );
  }
  if (selectedMethod.requiresReference && (reference?.trim().isEmpty ?? true)) {
    return const AppFailure(
      code: 'pos_reference_required',
      message: 'Este metodo de pago requiere referencia.',
    );
  }
  return null;
}

AppFailure? _validateSplitCheckout(PosReady state) {
  for (final account in state.splitAccounts) {
    final method = _paymentMethodFor(
      methods: state.paymentMethods,
      methodId: account.paymentMethodId,
    );
    if (method == null) {
      return AppFailure(
        code: 'pos_split_payment_method_required',
        message: 'Selecciona metodo de pago para ${account.name}.',
      );
    }

    if (method.requiresReference &&
        (account.paymentReference?.trim().isEmpty ?? true)) {
      return AppFailure(
        code: 'pos_split_reference_required',
        message: 'Ingresa referencia de pago para ${account.name}.',
      );
    }
  }

  return null;
}

PaymentMethod? _paymentMethodFor({
  required List<PaymentMethod> methods,
  required String? methodId,
}) {
  for (final method in methods) {
    if (method.id == methodId) return method;
  }

  return null;
}
