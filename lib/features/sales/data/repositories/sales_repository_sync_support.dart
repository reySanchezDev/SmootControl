part of 'sales_repository.dart';

extension _SalesRepositorySyncSupport on SalesRepository {
  Future<void> _enqueueSale(Sale sale, List<SaleItem> items) async {
    final inventoryMovements = await _inventoryMovementsPayload(
      referenceType: 'sale',
      referenceId: sale.id,
    );
    final packagingMovements = await _packagingMovementsPayload(
      referenceType: 'sale',
      referenceId: sale.id,
    );
    await _syncQueueRepository?.enqueue(
      entityType: 'sales',
      entityId: sale.id,
      operation: SyncOperation.create,
      payload: {
        'sale': _salePayload(sale),
        'items': items.map(_saleItemPayload).toList(),
        'inventoryMovements': inventoryMovements,
        'packagingMovements': packagingMovements,
      },
    );
  }

  Future<void> _enqueueSaleVoid({
    required Sale sale,
    required String reason,
    required String voidedBy,
  }) async {
    final inventoryMovements = await _inventoryMovementsPayload(
      referenceType: 'sale_void',
      referenceId: sale.id,
    );
    final packagingMovements = await _packagingMovementsPayload(
      referenceType: 'sale_void',
      referenceId: sale.id,
    );
    await _syncQueueRepository?.enqueue(
      entityType: 'sales',
      entityId: sale.id,
      operation: SyncOperation.update,
      payload: {
        'sale': _salePayload(sale),
        'void': {
          'reason': reason,
          'voidedBy': voidedBy,
        },
        'inventoryMovements': inventoryMovements,
        'packagingMovements': packagingMovements,
      },
    );
  }

  Future<List<Map<String, Object?>>> _inventoryMovementsPayload({
    required String referenceType,
    required String referenceId,
  }) async {
    final movements = await _inventoryDataSource?.getMovementsForReference(
      referenceType: referenceType,
      referenceId: referenceId,
    );
    return [
      for (final movement in movements ?? const <InventoryMovement>[])
        InventoryRepository.movementPayload(movement),
    ];
  }

  Future<List<Map<String, Object?>>> _packagingMovementsPayload({
    required String referenceType,
    required String referenceId,
  }) async {
    final movements = await _packagingDataSource?.getMovementsForReference(
      referenceType: referenceType,
      referenceId: referenceId,
    );
    return [
      for (final movement in movements ?? const <PackagingMovement>[])
        PackagingRepository.movementPayload(movement),
    ];
  }

  Map<String, Object?> _salePayload(Sale sale) {
    return {
      'id': sale.id,
      'invoiceNumber': sale.invoiceNumber,
      'saleKind': switch (sale.saleKind) {
        SaleKind.sale => 'sale',
        SaleKind.staffConsumption => 'staff_consumption',
      },
      'tableId': sale.tableId,
      'tableAccountId': sale.tableAccountId,
      'paymentMethodId': sale.paymentMethodId,
      'salesTypeId': sale.salesTypeId,
      'salesTypeName': sale.salesTypeName,
      'employeeId': sale.employeeId,
      'internalReceiptNumber': sale.internalReceiptNumber,
      'payrollRunId': sale.payrollRunId,
      'paymentReference': sale.paymentReference,
      'cashRegisterSessionId': sale.cashRegisterSessionId,
      'cashierId': _currentOperatorService?.userId,
      'businessDate': sale.createdAt.toIso8601String().substring(0, 10),
      'status': sale.status.name,
      'subtotalInCents': sale.subtotalInCents,
      'totalInCents': sale.totalInCents,
      'createdAt': sale.createdAt.toIso8601String(),
    };
  }

  Map<String, Object?> _saleItemPayload(SaleItem item) {
    return {
      'id': item.id,
      'saleId': item.saleId,
      'tableId': item.tableId,
      'tableAccountId': item.tableAccountId,
      'productId': item.productId,
      'productName': item.productName,
      'categoryName': item.categoryName,
      'selectedOptionsLabel': item.selectedOptionsLabel,
      'quantity': item.quantity,
      'unitPriceInCents': item.unitPriceInCents,
      'unitCostInCents': item.unitCostInCents,
      'createdAt': item.createdAt.toIso8601String(),
    };
  }
}
