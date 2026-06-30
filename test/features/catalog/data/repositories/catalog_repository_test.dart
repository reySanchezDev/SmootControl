import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/catalog/data/datasources/local_catalog_datasource.dart';
import 'package:smoo_control/features/catalog/data/repositories/catalog_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/products/data/datasources/local_products_datasource.dart';
import 'package:smoo_control/features/products/data/models/product_model.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

void main() {
  group('CatalogRepository', () {
    late AppDatabase database;
    late CatalogRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = CatalogRepository(
        LocalCatalogDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and returns categories from local storage', () async {
      const category = ProductCategory(
        id: 'category-1',
        name: 'Cafe Caliente',
        sortOrder: 1,
        isActive: true,
      );

      final saveResult = await repository.saveCategory(category);
      final readResult = await repository.getCategories();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<ProductCategory>>());
      expect(readResult, isA<AppSuccess<List<ProductCategory>>>());
      expect(
        (readResult as AppSuccess<List<ProductCategory>>).value.single,
        category,
      );
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'product_categories');
      expect(syncItem.entityId, category.id);
      expect(syncItem.operation, SyncOperation.create);
    });

    test('does not save local category when remote-first push fails', () async {
      final remoteFirstRepository = CatalogRepository(
        LocalCatalogDataSource(database),
        syncQueueRepository: syncQueueRepository,
        remoteSender: const _FailingRemoteSender(),
      );
      const category = ProductCategory(
        id: 'category-remote',
        name: 'Remota',
        sortOrder: 1,
        isActive: true,
      );

      final saveResult = await remoteFirstRepository.saveCategory(category);
      final readResult = await repository.getCategories();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppFailureResult<ProductCategory>>());
      expect((readResult as AppSuccess<List<ProductCategory>>).value, isEmpty);
      expect((syncResult as AppSuccess<List<SyncQueueItem>>).value, isEmpty);
    });

    test(
      'removes a nested level and moves its content to the parent',
      () async {
        const root = ProductCategory(
          id: 'root',
          name: 'Bebidas Frias',
          sortOrder: 1,
          isActive: true,
        );
        const subcategory = ProductCategory(
          id: 'subcategory',
          name: 'Fresca',
          parentId: 'root',
          sortOrder: 1,
          isActive: true,
        );
        const extraLevel = ProductCategory(
          id: 'extra-level',
          name: '12 Oz',
          parentId: 'subcategory',
          sortOrder: 1,
          isActive: true,
        );
        const childLevel = ProductCategory(
          id: 'child-level',
          name: 'Sin hielo',
          parentId: 'extra-level',
          sortOrder: 1,
          isActive: true,
        );
        const product = ProductModel(
          id: 'product-1',
          categoryId: 'extra-level',
          name: 'Fresca 12 Oz',
          priceInCents: 3000,
          costInCents: 1000,
          isActive: true,
          isAvailableInPos: true,
          optionGroups: [],
          modifierGroupIds: [],
        );

        await repository.saveCategory(root);
        await repository.saveCategory(subcategory);
        await repository.saveCategory(extraLevel);
        await repository.saveCategory(childLevel);
        final productsDataSource = LocalProductsDataSource(database);
        await productsDataSource.saveProduct(product);

        final removeResult = await repository.removeCategoryLevel(extraLevel);
        final categoriesResult = await repository.getCategories();
        final products = await productsDataSource.getProducts();
        final syncResult = await syncQueueRepository.getPendingItems();

        expect(removeResult, isA<AppSuccess<ProductCategory>>());
        final categories =
            (categoriesResult as AppSuccess<List<ProductCategory>>).value;
        expect(
          categories.any((category) => category.id == 'extra-level'),
          false,
        );
        expect(
          categories
              .singleWhere((category) => category.id == 'child-level')
              .parentId,
          'subcategory',
        );
        expect(products.single.categoryId, 'subcategory');
        expect(
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.any(
            (item) => item.operation == SyncOperation.delete,
          ),
          true,
        );
      },
    );

    test('does not remove local category when remote delete fails', () async {
      const root = ProductCategory(
        id: 'root',
        name: 'Comidas',
        sortOrder: 1,
        isActive: true,
      );
      const child = ProductCategory(
        id: 'child',
        name: 'Asados',
        parentId: 'root',
        sortOrder: 1,
        isActive: true,
      );
      final remoteFirstRepository = CatalogRepository(
        LocalCatalogDataSource(database),
        syncQueueRepository: syncQueueRepository,
        remoteSender: const _FailingRemoteSender(),
      );

      await repository.saveCategory(root);
      await repository.saveCategory(child);

      final removeResult = await remoteFirstRepository.removeCategoryLevel(
        child,
      );
      final readResult = await repository.getCategories();

      expect(removeResult, isA<AppFailureResult<ProductCategory>>());
      final categories =
          (readResult as AppSuccess<List<ProductCategory>>).value;
      expect(categories.any((category) => category.id == 'child'), isTrue);
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
