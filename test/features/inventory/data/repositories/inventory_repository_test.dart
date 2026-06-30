import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/inventory/data/datasources/local_inventory_datasource.dart';
import 'package:smoo_control/features/inventory/data/repositories/inventory_repository.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

void main() {
  group('InventoryRepository', () {
    late AppDatabase database;
    late LocalInventoryDataSource dataSource;
    late SyncQueueRepository syncQueueRepository;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      dataSource = LocalInventoryDataSource(database);
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      await _insertProduct(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('registers purchase and queues the same movement', () async {
      final repository = InventoryRepository(
        dataSource,
        syncQueueRepository: syncQueueRepository,
      );

      final result = await repository.registerPurchase(
        productId: 'product-1',
        quantity: 10,
        userId: 'admin-1',
      );

      final stockResult = await repository.getTrackedStock();
      final queueResult = await syncQueueRepository.getPendingItems();

      expect(result, isA<AppSuccess<void>>());
      expect(
        (stockResult as AppSuccess<List<InventoryStockItem>>)
            .value
            .single
            .quantityOnHand,
        10,
      );
      final queueItem =
          (queueResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(queueItem.entityType, 'inventory_movements');
      expect(queueItem.payload['quantityDelta'], 10);
    });

    test(
      'does not apply local purchase when remote-first push fails',
      () async {
        final repository = InventoryRepository(
          dataSource,
          remoteSender: _FailingRemoteSender(),
        );

        final result = await repository.registerPurchase(
          productId: 'product-1',
          quantity: 10,
          userId: 'admin-1',
        );

        final stockResult = await repository.getTrackedStock();

        expect(result, isA<AppFailureResult<void>>());
        expect(
          (stockResult as AppSuccess<List<InventoryStockItem>>)
              .value
              .single
              .quantityOnHand,
          0,
        );
      },
    );
  });
}

Future<void> _insertProduct(AppDatabase database) async {
  final now = DateTime(2026, 6, 30);
  await database
      .into(database.localProducts)
      .insert(
        LocalProductsCompanion(
          id: const Value('product-1'),
          categoryId: const Value('category-1'),
          name: const Value('Pollo'),
          priceInCents: const Value(100),
          costInCents: const Value(50),
          isActive: const Value(true),
          isAvailableInPos: const Value(true),
          tracksInventory: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

final class _FailingRemoteSender implements ISyncRemoteSender {
  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('remote failed');
  }
}
