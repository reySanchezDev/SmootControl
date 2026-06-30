import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/products/data/datasources/local_products_datasource.dart';
import 'package:smoo_control/features/products/data/repositories/products_repository.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

void main() {
  group('ProductsRepository', () {
    late AppDatabase database;
    late ProductsRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = ProductsRepository(
        LocalProductsDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and returns local products', () async {
      const product = Product(
        id: 'product-1',
        categoryId: 'category-1',
        name: 'Espresso',
        priceInCents: 350,
        costInCents: 100,
        isActive: true,
        isAvailableInPos: false,
      );

      final saveResult = await repository.saveProduct(product);
      final readResult = await repository.getProducts();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<Product>>());
      expect((readResult as AppSuccess<List<Product>>).value.single, product);
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'products');
      expect(syncItem.entityId, product.id);
      expect(syncItem.payload['isAvailableInPos'], isFalse);
    });

    test('does not save local product when remote-first push fails', () async {
      final remoteFirstRepository = ProductsRepository(
        LocalProductsDataSource(database),
        syncQueueRepository: syncQueueRepository,
        remoteSender: const _FailingRemoteSender(),
      );
      const product = Product(
        id: 'product-remote',
        categoryId: 'category-1',
        name: 'Remoto',
        priceInCents: 350,
        costInCents: 100,
        isActive: true,
      );

      final saveResult = await remoteFirstRepository.saveProduct(product);
      final readResult = await repository.getProducts();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppFailureResult<Product>>());
      expect((readResult as AppSuccess<List<Product>>).value, isEmpty);
      expect((syncResult as AppSuccess<List<SyncQueueItem>>).value, isEmpty);
    });
  });
}

final class _FailingRemoteSender implements ISyncRemoteSender {
  const _FailingRemoteSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('remote failed');
  }
}
