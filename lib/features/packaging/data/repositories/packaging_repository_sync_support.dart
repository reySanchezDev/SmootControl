part of 'packaging_repository.dart';

extension _PackagingRepositorySyncSupport on PackagingRepository {
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
      payload: PackagingRepository.movementPayload(movement),
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
