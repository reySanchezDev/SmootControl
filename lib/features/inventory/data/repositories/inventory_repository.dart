import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/inventory/data/datasources/inventory_stock_exception.dart';
import 'package:smoo_control/features/inventory/data/datasources/local_inventory_datasource.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_movement.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';
import 'package:smoo_control/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:uuid/uuid.dart';

/// Local inventory repository.
final class InventoryRepository implements IInventoryRepository {
  /// Creates the repository.
  const InventoryRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
    Uuid uuid = const Uuid(),
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender,
       _uuid = uuid;

  final LocalInventoryDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;
  final Uuid _uuid;

  @override
  Future<AppResult<List<InventoryStockItem>>> getTrackedStock() async {
    try {
      return AppSuccess(await _localDataSource.getTrackedStock());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'inventory_read_failed',
          message: 'No se pudo leer el inventario.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> registerPurchase({
    required String productId,
    required int quantity,
    required String userId,
    String? notes,
  }) async {
    try {
      if (quantity <= 0) {
        return const AppFailureResult(
          AppFailure(
            code: 'inventory_purchase_quantity_invalid',
            message: 'La cantidad debe ser mayor que cero.',
          ),
        );
      }
      final movement = InventoryMovement(
        id: _uuid.v4(),
        productId: productId,
        movementType: InventoryMovementType.purchase,
        quantityDelta: quantity,
        referenceType: 'purchase',
        userId: userId,
        notes: notes,
        createdAt: DateTime.now(),
      );
      final sender = _remoteSender;
      if (sender != null) {
        await sender.push(_syncItem(movement));
        await _localDataSource.applyPurchaseMovement(movement);
        return const AppSuccess<void>(null);
      }
      await _localDataSource.applyPurchaseMovement(movement);
      await _pushOrQueueMovement(movement);
      return const AppSuccess<void>(null);
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
          code: 'inventory_purchase_failed',
          message: 'No se pudo registrar la compra.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _pushOrQueueMovement(InventoryMovement movement) async {
    final item = _syncItem(movement);
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

  SyncQueueItem _syncItem(InventoryMovement movement) {
    final now = DateTime.now();
    return SyncQueueItem(
      id: 'inventory-${movement.id}',
      entityType: 'inventory_movements',
      entityId: movement.id,
      operation: SyncOperation.create,
      payload: _movementPayload(movement),
      status: SyncQueueStatus.pending,
      retryCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Converts an inventory movement to a synchronization payload.
  static Map<String, Object?> movementPayload(InventoryMovement movement) {
    return _movementPayload(movement);
  }

  static Map<String, Object?> _movementPayload(InventoryMovement movement) {
    return {
      'id': movement.id,
      'productId': movement.productId,
      'movementType': movement.typeValue,
      'quantityDelta': movement.quantityDelta,
      'referenceType': movement.referenceType,
      'referenceId': movement.referenceId,
      'userId': movement.userId,
      'notes': movement.notes,
      'createdAt': movement.createdAt.toIso8601String(),
    };
  }
}
