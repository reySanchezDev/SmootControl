import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/inventory/data/datasources/inventory_stock_exception.dart';
import 'package:smoo_control/features/inventory/data/datasources/local_inventory_datasource.dart';
import 'package:smoo_control/features/inventory/data/repositories/inventory_repository.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_movement.dart';
import 'package:smoo_control/features/sales/data/datasources/local_sales_datasource.dart';
import 'package:smoo_control/features/sales/data/models/sale_item_model.dart';
import 'package:smoo_control/features/sales/data/models/sale_model.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// Sales repository backed by the local offline database.
final class SalesRepository implements ISalesRepository {
  /// Creates a sales repository.
  const SalesRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    LocalInventoryDataSource? inventoryDataSource,
    CurrentOperatorService? currentOperatorService,
  }) : _syncQueueRepository = syncQueueRepository,
       _inventoryDataSource = inventoryDataSource,
       _currentOperatorService = currentOperatorService;

  final LocalSalesDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final LocalInventoryDataSource? _inventoryDataSource;
  final CurrentOperatorService? _currentOperatorService;

  @override
  Future<AppResult<List<Sale>>> getSales({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final sales = await _localDataSource.getSales(from: from, to: to);
      return AppSuccess(sales.map((sale) => sale.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sales_read_failed',
          message: 'No se pudieron leer las ventas locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<Sale>>> getSalesByCashRegisterSession(
    String sessionId,
  ) async {
    try {
      final sales = await _localDataSource.getSalesByCashRegisterSession(
        sessionId,
      );
      return AppSuccess(sales.map((sale) => sale.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sales_by_cash_read_failed',
          message: 'No se pudieron leer las ventas de la caja.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<SaleItem>>> getSaleItems(String saleId) async {
    try {
      final items = await _localDataSource.getSaleItems(saleId);
      return AppSuccess(items.map((item) => item.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sale_items_read_failed',
          message: 'No se pudo leer el detalle de la venta local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<SaleVoid>>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final voids = await _localDataSource.getSaleVoids(from: from, to: to);
      return AppSuccess(voids.map((saleVoid) => saleVoid.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sale_voids_read_failed',
          message: 'No se pudieron leer las anulaciones locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<Sale>> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    try {
      final saved = await _localDataSource.saveSale(
        sale: SaleModel.fromEntity(sale),
        items: items.map(SaleItemModel.fromEntity).toList(),
        inventoryUserId: _currentOperatorService?.userId,
      );
      final entity = saved.toEntity();
      await _enqueueSale(entity, items);

      return AppSuccess(entity);
    } on InventoryStockException catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'inventory_stock_insufficient',
          message: error.toString(),
          cause: error,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sale_save_failed',
          message: 'No se pudo guardar la venta local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<Sale>> voidSale({
    required String saleId,
    required String reason,
    required String voidedBy,
  }) async {
    try {
      final sale = await _localDataSource.voidSale(
        saleId: saleId,
        reason: reason,
        voidedBy: voidedBy,
      );
      final entity = sale.toEntity();
      await _enqueueSaleVoid(
        sale: entity,
        reason: reason,
        voidedBy: voidedBy,
      );

      return AppSuccess(entity);
    } on InventoryStockException catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'inventory_stock_invalid',
          message: error.toString(),
          cause: error,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sale_void_failed',
          message: 'No se pudo anular la venta local.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueueSale(Sale sale, List<SaleItem> items) async {
    final inventoryMovements = await _inventoryMovementsPayload(
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

  Map<String, Object?> _salePayload(Sale sale) {
    return {
      'id': sale.id,
      'invoiceNumber': sale.invoiceNumber,
      'tableId': sale.tableId,
      'tableAccountId': sale.tableAccountId,
      'paymentMethodId': sale.paymentMethodId,
      'paymentReference': sale.paymentReference,
      'cashRegisterSessionId': sale.cashRegisterSessionId,
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
