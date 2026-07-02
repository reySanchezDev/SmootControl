import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/packaging/data/datasources/local_packaging_datasource.dart';
import 'package:smoo_control/features/packaging/data/datasources/packaging_stock_exception.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_movement.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/domain/repositories/i_packaging_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Packaging repository backed by local storage and optional remote sync.
final class PackagingRepository implements IPackagingRepository {
  /// Creates the repository.
  const PackagingRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender;

  final LocalPackagingDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;

  @override
  Future<AppResult<List<SalesType>>> getSalesTypes() async {
    try {
      return AppSuccess(await _localDataSource.getSalesTypes());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sales_types_read_failed',
          message: 'No se pudieron leer los tipos de venta.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<SalesType>> saveSalesType(SalesType salesType) async {
    try {
      if (salesType.isDefault) {
        final existingTypes = await _localDataSource.getSalesTypes();
        for (final existing in existingTypes) {
          if (existing.id == salesType.id || !existing.isDefault) continue;
          final updated = SalesType(
            id: existing.id,
            code: existing.code,
            name: existing.name,
            displayOrder: existing.displayOrder,
            isDefault: false,
            isActive: existing.isActive,
          );
          await _pushOrQueue(
            entityType: 'sales_types',
            entityId: updated.id,
            payload: _salesTypePayload(updated),
          );
          await _localDataSource.saveSalesType(updated);
        }
      }
      await _pushOrQueue(
        entityType: 'sales_types',
        entityId: salesType.id,
        payload: _salesTypePayload(salesType),
      );
      return AppSuccess(await _localDataSource.saveSalesType(salesType));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sales_type_save_failed',
          message: 'No se pudo guardar el tipo de venta.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<PackagingItem>>> getPackagingItems() async {
    try {
      return AppSuccess(await _localDataSource.getPackagingItems());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_items_read_failed',
          message: 'No se pudieron leer los empaques.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<PackagingItem>> savePackagingItem(PackagingItem item) async {
    try {
      await _pushOrQueue(
        entityType: 'packaging_items',
        entityId: item.id,
        payload: _packagingItemPayload(item),
      );
      return AppSuccess(await _localDataSource.savePackagingItem(item));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_item_save_failed',
          message: 'No se pudo guardar el empaque.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<ProductPackagingRule>>> getRules() async {
    try {
      return AppSuccess(await _localDataSource.getRules());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_rules_read_failed',
          message: 'No se pudieron leer las reglas de empaque.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<ProductPackagingRule>> saveRule(
    ProductPackagingRule rule,
  ) async {
    try {
      if (rule.quantityPerUnit <= 0) {
        return const AppFailureResult(
          AppFailure(
            code: 'packaging_rule_quantity_invalid',
            message: 'La cantidad por unidad debe ser mayor que cero.',
          ),
        );
      }
      await _pushOrQueue(
        entityType: 'product_packaging_rules',
        entityId: rule.id,
        payload: _rulePayload(rule),
      );
      return AppSuccess(await _localDataSource.saveRule(rule));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_rule_save_failed',
          message: 'No se pudo guardar la regla de empaque.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<PackagingStockItem>>> getPackagingStock() async {
    try {
      return AppSuccess(await _localDataSource.getPackagingStock());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_stock_read_failed',
          message: 'No se pudo leer el stock de empaques.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> registerPackagingPurchase({
    required String packagingItemId,
    required int quantity,
    required String userId,
    String? notes,
  }) async {
    try {
      if (quantity <= 0) {
        return const AppFailureResult(
          AppFailure(
            code: 'packaging_purchase_quantity_invalid',
            message: 'La cantidad debe ser mayor que cero.',
          ),
        );
      }
      final item = (await _localDataSource.getPackagingItems()).firstWhere(
        (packaging) => packaging.id == packagingItemId,
      );
      final movement = _localDataSource.purchaseMovement(
        packagingItemId: packagingItemId,
        quantity: quantity,
        unitCostInCents: item.costInCents,
        userId: userId,
        notes: notes,
      );
      await _pushOrQueueMovement(movement);
      await _localDataSource.applyPurchaseMovement(movement);
      return const AppSuccess<void>(null);
    } on PackagingStockException catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_stock_invalid',
          message: error.toString(),
          cause: error,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'packaging_purchase_failed',
          message: 'No se pudo registrar la compra de empaque.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _pushOrQueue({
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    final item = _syncItem(
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    );
    final sender = _remoteSender;
    if (sender != null) {
      await sender.push(item);
      return;
    }
    await _syncQueueRepository?.enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.create,
      payload: payload,
    );
  }

  Future<void> _pushOrQueueMovement(PackagingMovement movement) async {
    final item = _syncItem(
      entityType: 'packaging_movements',
      entityId: movement.id,
      payload: movementPayload(movement),
    );
    final sender = _remoteSender;
    if (sender != null) {
      await sender.push(item);
      return;
    }
    await _syncQueueRepository?.enqueue(
      entityType: item.entityType,
      entityId: item.entityId,
      operation: item.operation,
      payload: item.payload,
    );
  }

  SyncQueueItem _syncItem({
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) {
    final now = DateTime.now();
    return SyncQueueItem(
      id: 'admin-direct-$entityType-$entityId',
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.create,
      payload: payload,
      status: SyncQueueStatus.pending,
      retryCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Converts a packaging movement to a synchronization payload.
  static Map<String, Object?> movementPayload(PackagingMovement movement) {
    return {
      'id': movement.id,
      'packagingItemId': movement.packagingItemId,
      'movementType': movement.typeValue,
      'quantityDelta': movement.quantityDelta,
      'unitCostInCents': movement.unitCostInCents,
      'referenceType': movement.referenceType,
      'referenceId': movement.referenceId,
      'userId': movement.userId,
      'notes': movement.notes,
      'createdAt': movement.createdAt.toIso8601String(),
    };
  }

  Map<String, Object?> _salesTypePayload(SalesType salesType) {
    return {
      'id': salesType.id,
      'code': salesType.code,
      'name': salesType.name,
      'displayOrder': salesType.displayOrder,
      'isDefault': salesType.isDefault,
      'isActive': salesType.isActive,
    };
  }

  Map<String, Object?> _packagingItemPayload(PackagingItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'costInCents': item.costInCents,
      'tracksStock': item.tracksStock,
      'isActive': item.isActive,
    };
  }

  Map<String, Object?> _rulePayload(ProductPackagingRule rule) {
    return {
      'id': rule.id,
      'productId': rule.productId,
      'salesTypeId': rule.salesTypeId,
      'packagingItemId': rule.packagingItemId,
      'quantityPerUnit': rule.quantityPerUnit,
      'isActive': rule.isActive,
    };
  }
}
