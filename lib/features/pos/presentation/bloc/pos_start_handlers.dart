part of 'pos_bloc.dart';

Future<void> _handlePosStarted(
  PosBloc bloc,
  PosStarted event,
  Emitter<PosState> emit,
) async {
  emit(const PosLoading());
  final today = DateTime.now();
  final cashSessionResult = await bloc._cashRegisterRepository
      .getAnyOpenSessionForCashier(bloc._currentOperatorService.userId);
  final categoriesResult = await bloc._catalogRepository.getCategories();
  final productsResult = await bloc._productsRepository.getProducts();
  final inventoryStockResult = await bloc._inventoryRepository
      .getTrackedStock();
  final modifiersResult = await bloc._modifiersRepository.getCatalog();
  final tablesResult = await bloc._tablesRepository.getTables();
  final methodsResult = await bloc._paymentMethodsRepository
      .getPaymentMethods();
  final salesTypesResult = await bloc._packagingRepository.getSalesTypes();
  final openTicketsResult = await bloc._openTicketRepository.getOpenTickets();
  final orderSalesTypesResult = await bloc._openTicketRepository
      .getOrderSalesTypes();

  final CashRegisterSession cashSession;
  switch (cashSessionResult) {
    case AppSuccess(:final value):
      if (value == null) {
        emit(const PosCashRegisterRequired());
        return;
      }
      if (!_isSameBusinessDate(value.businessDate, today)) {
        emit(PosStaleCashRegisterRequired(value));
        return;
      }
      cashSession = value;
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final List<ProductCategory> categories;
  switch (categoriesResult) {
    case AppSuccess(:final value):
      categories = value.where((category) => category.isActive).toList();
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final List<Product> allActiveProducts;
  final List<Product> products;
  final Map<String, int> stockByProductId;
  switch (inventoryStockResult) {
    case AppSuccess(:final value):
      stockByProductId = {
        for (final stock in value) stock.productId: stock.quantityOnHand,
      };
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }
  switch (productsResult) {
    case AppSuccess(:final value):
      allActiveProducts = value.where((product) => product.isActive).toList();
      products = allActiveProducts
          .where(
            (product) =>
                product.isAvailableInPos &&
                _canDisplayProductInPos(product, stockByProductId),
          )
          .toList();
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final ModifierCatalog modifierCatalog;
  switch (modifiersResult) {
    case AppSuccess(:final value):
      modifierCatalog = value;
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final List<RestaurantTable> tables;
  switch (tablesResult) {
    case AppSuccess(:final value):
      tables = value.where((table) => table.isActive).toList();
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final List<PaymentMethod> methods;
  switch (methodsResult) {
    case AppSuccess(:final value):
      methods = value.where((method) => method.isActive).toList();
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final List<SalesType> salesTypes;
  switch (salesTypesResult) {
    case AppSuccess(:final value):
      salesTypes = value.where((type) => type.isActive).toList();
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final Map<String, List<PosCartLine>> cartLinesByTable;
  switch (openTicketsResult) {
    case AppSuccess(:final value):
      cartLinesByTable = _openTicketsToCarts(
        lines: value,
        products: allActiveProducts,
      );
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  final Map<String, String> salesTypeIdByOrderKey;
  switch (orderSalesTypesResult) {
    case AppSuccess(:final value):
      salesTypeIdByOrderKey = value;
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      return;
  }

  emit(
    PosReady(
      categories: categories,
      products: products,
      modifierCatalog: modifierCatalog,
      tables: tables,
      salesTypes: salesTypes,
      salesTypeIdByOrderKey: salesTypeIdByOrderKey,
      paymentMethods: methods,
      cartLinesByTable: cartLinesByTable,
      openCashRegisterSession: cashSession,
      selectedPaymentMethodId: methods.isEmpty ? null : methods.first.id,
      selectedSalesTypeId: _defaultSalesTypeId(salesTypes),
    ),
  );
}

bool _canDisplayProductInPos(
  Product product,
  Map<String, int> stockByProductId,
) {
  if (!product.tracksInventory) return true;
  return (stockByProductId[product.id] ?? 0) > 0;
}

String? _defaultSalesTypeId(List<SalesType> salesTypes) {
  for (final type in salesTypes) {
    if (type.isDefault && type.isActive) return type.id;
  }
  for (final type in salesTypes) {
    if (type.isActive) return type.id;
  }
  return null;
}

bool _isSameBusinessDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

Map<String, List<PosCartLine>> _openTicketsToCarts({
  required List<PosOpenTicketLine> lines,
  required List<Product> products,
}) {
  final productsById = {for (final product in products) product.id: product};
  final carts = <String, List<PosCartLine>>{};
  for (final line in lines) {
    final product = productsById[line.productId];
    if (product == null) continue;
    carts
        .putIfAbsent(line.tableId, () => [])
        .add(
          PosCartLine(
            product: product,
            quantity: line.quantity,
            isServed: line.isServed,
            ticketLineId: line.lineKey,
            selectedOptions: line.selectedOptions,
          ),
        );
  }
  return carts;
}
