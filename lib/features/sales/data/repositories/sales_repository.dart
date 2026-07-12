import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/inventory/data/datasources/inventory_stock_exception.dart';
import 'package:smoo_control/features/inventory/data/datasources/local_inventory_datasource.dart';
import 'package:smoo_control/features/inventory/data/repositories/inventory_repository.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_movement.dart';
import 'package:smoo_control/features/packaging/data/datasources/local_packaging_datasource.dart';
import 'package:smoo_control/features/packaging/data/datasources/packaging_stock_exception.dart';
import 'package:smoo_control/features/packaging/data/repositories/packaging_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_movement.dart';
import 'package:smoo_control/features/sales/data/datasources/local_sales_datasource.dart';
import 'package:smoo_control/features/sales/data/models/sale_item_model.dart';
import 'package:smoo_control/features/sales/data/models/sale_model.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

part 'sales_repository_sync_support.dart';

/// Sales repository backed by the local offline database.
final class SalesRepository implements ISalesRepository {
  /// Creates a sales repository.
  const SalesRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    LocalInventoryDataSource? inventoryDataSource,
    LocalPackagingDataSource? packagingDataSource,
    CurrentOperatorService? currentOperatorService,
  }) : _syncQueueRepository = syncQueueRepository,
       _inventoryDataSource = inventoryDataSource,
       _packagingDataSource = packagingDataSource,
       _currentOperatorService = currentOperatorService;

  final LocalSalesDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final LocalInventoryDataSource? _inventoryDataSource;
  final LocalPackagingDataSource? _packagingDataSource;
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
    } on PackagingStockException catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_stock_insufficient',
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
}
