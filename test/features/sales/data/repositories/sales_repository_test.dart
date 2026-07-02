import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/inventory/data/datasources/local_inventory_datasource.dart';
import 'package:smoo_control/features/packaging/data/datasources/local_packaging_datasource.dart';
import 'package:smoo_control/features/sales/data/datasources/local_sales_datasource.dart';
import 'package:smoo_control/features/sales/data/repositories/sales_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('SalesRepository', () {
    late AppDatabase database;
    late SalesRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = SalesRepository(
        LocalSalesDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves sale with items and returns them by date', () async {
      final createdAt = DateTime(2026, 6, 23, 10);
      final sale = Sale(
        id: 'sale-1',
        invoiceNumber: 'F-0001',
        tableId: 'table-1',
        tableAccountId: 'account-1',
        paymentMethodId: 'cash',
        status: SaleStatus.completed,
        subtotalInCents: 850,
        totalInCents: 850,
        createdAt: createdAt,
      );
      final item = SaleItem(
        id: 'item-1',
        saleId: 'sale-1',
        tableId: 'table-1',
        tableAccountId: 'account-1',
        productId: 'product-1',
        productName: 'Espresso',
        categoryName: 'Cafe Caliente',
        quantity: 2,
        unitPriceInCents: 425,
        unitCostInCents: 100,
        createdAt: createdAt,
      );

      final saveResult = await repository.saveSale(
        sale: sale,
        items: [item],
      );
      final salesResult = await repository.getSales(
        from: DateTime(2026, 6, 23),
        to: DateTime(2026, 6, 24),
      );
      final itemsResult = await repository.getSaleItems('sale-1');
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<Sale>>());
      expect((salesResult as AppSuccess<List<Sale>>).value.single, sale);
      expect((itemsResult as AppSuccess<List<SaleItem>>).value.single, item);
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'sales');
      expect(syncItem.entityId, sale.id);
      expect(syncItem.operation, SyncOperation.create);
    });

    test(
      'returns sale synchronization status from the latest queue item',
      () async {
        final createdAt = DateTime(2026, 6, 23, 10);
        final sale = Sale(
          id: 'sale-1',
          invoiceNumber: 'F-0001',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 850,
          totalInCents: 850,
          createdAt: createdAt,
        );
        final item = SaleItem(
          id: 'item-1',
          saleId: 'sale-1',
          productId: 'product-1',
          productName: 'Espresso',
          categoryName: 'Cafe Caliente',
          quantity: 1,
          unitPriceInCents: 850,
          unitCostInCents: 100,
          createdAt: createdAt,
        );

        await repository.saveSale(sale: sale, items: [item]);
        var salesResult = await repository.getSalesByCashRegisterSession('');
        expect(
          (salesResult as AppSuccess<List<Sale>>).value,
          isEmpty,
        );

        final syncResult = await syncQueueRepository.getPendingItems();
        final syncItem =
            (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
        await syncQueueRepository.markSynced(syncItem.id);

        salesResult = await repository.getSales(
          from: DateTime(2026, 6, 23),
          to: DateTime(2026, 6, 24),
        );

        expect(
          (salesResult as AppSuccess<List<Sale>>).value.single.syncStatus,
          SaleSyncStatus.synced,
        );
      },
    );

    test('voids a sale and records audit data locally', () async {
      final createdAt = DateTime(2026, 6, 23, 10);
      final sale = Sale(
        id: 'sale-1',
        invoiceNumber: 'F-0001',
        paymentMethodId: 'cash',
        status: SaleStatus.completed,
        subtotalInCents: 500,
        totalInCents: 500,
        createdAt: createdAt,
      );
      final item = SaleItem(
        id: 'item-1',
        saleId: 'sale-1',
        productId: 'product-1',
        productName: 'Sopa',
        categoryName: 'Sopa',
        quantity: 1,
        unitPriceInCents: 500,
        unitCostInCents: 200,
        createdAt: createdAt,
      );

      await repository.saveSale(sale: sale, items: [item]);
      final voidResult = await repository.voidSale(
        saleId: 'sale-1',
        reason: 'Error de captura',
        voidedBy: 'admin-1',
      );
      final today = DateTime.now();
      final voidedFrom = DateTime(today.year, today.month, today.day);
      final voidsResult = await repository.getSaleVoids(
        from: voidedFrom,
        to: voidedFrom.add(const Duration(days: 1)),
      );
      final voidRows = await database.select(database.localSaleVoids).get();
      final syncResult = await syncQueueRepository.getPendingItems();

      final voidedSale = (voidResult as AppSuccess<Sale>).value;
      final syncItems = (syncResult as AppSuccess<List<SyncQueueItem>>).value;

      expect(voidedSale.status, SaleStatus.voided);
      expect(voidRows, hasLength(1));
      expect(voidRows.single.reason, 'Error de captura');
      expect(voidRows.single.voidedBy, 'admin-1');
      expect((voidsResult as AppSuccess).value, hasLength(1));
      expect(syncItems, hasLength(2));
      expect(syncItems.last.operation, SyncOperation.update);
      expect(syncItems.last.payload['void'], isA<Map<String, Object?>>());
    });

    test('decrements tracked stock when a sale is saved', () async {
      final inventory = LocalInventoryDataSource(database);
      repository = SalesRepository(
        LocalSalesDataSource(database, inventoryDataSource: inventory),
        syncQueueRepository: syncQueueRepository,
        inventoryDataSource: inventory,
      );
      await _insertProduct(database, tracksInventory: true);
      await inventory.registerPurchase(
        productId: 'product-1',
        quantity: 10,
        userId: 'admin-1',
      );

      final createdAt = DateTime(2026, 6, 23, 10);
      final result = await repository.saveSale(
        sale: Sale(
          id: 'sale-stock',
          invoiceNumber: 'F-100',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 200,
          totalInCents: 200,
          createdAt: createdAt,
        ),
        items: [
          SaleItem(
            id: 'item-stock',
            saleId: 'sale-stock',
            productId: 'product-1',
            productName: 'Pollo',
            categoryName: 'Comidas',
            quantity: 2,
            unitPriceInCents: 100,
            unitCostInCents: 50,
            createdAt: createdAt,
          ),
        ],
      );

      final stockRows = await database
          .select(database.localInventoryStock)
          .get();
      final movements = await database
          .select(database.localInventoryMovements)
          .get();
      final syncResult = await syncQueueRepository.getPendingItems();
      final saleSync =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.last;
      final inventoryPayload =
          saleSync.payload['inventoryMovements']! as List<Object?>;
      final inventoryMovement =
          inventoryPayload.single! as Map<String, Object?>;

      expect(result, isA<AppSuccess<Sale>>());
      expect(stockRows.single.quantityOnHand, 8);
      expect(movements.map((movement) => movement.movementType), [
        'purchase',
        'sale',
      ]);
      expect(inventoryPayload, hasLength(1));
      expect(inventoryMovement['quantityDelta'], -2);
    });

    test('blocks tracked product sale when stock is insufficient', () async {
      final inventory = LocalInventoryDataSource(database);
      repository = SalesRepository(
        LocalSalesDataSource(database, inventoryDataSource: inventory),
        syncQueueRepository: syncQueueRepository,
        inventoryDataSource: inventory,
      );
      await _insertProduct(database, tracksInventory: true);
      await inventory.registerPurchase(
        productId: 'product-1',
        quantity: 1,
        userId: 'admin-1',
      );

      final result = await repository.saveSale(
        sale: Sale(
          id: 'sale-blocked',
          invoiceNumber: 'F-101',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 200,
          totalInCents: 200,
          createdAt: DateTime(2026, 6, 23, 10),
        ),
        items: [
          SaleItem(
            id: 'item-blocked',
            saleId: 'sale-blocked',
            productId: 'product-1',
            productName: 'Pollo',
            categoryName: 'Comidas',
            quantity: 2,
            unitPriceInCents: 100,
            unitCostInCents: 50,
            createdAt: DateTime(2026, 6, 23, 10),
          ),
        ],
      );

      final sales = await database.select(database.localSales).get();
      final stockRows = await database
          .select(database.localInventoryStock)
          .get();

      expect(result, isA<AppFailureResult<Sale>>());
      expect(sales, isEmpty);
      expect(stockRows.single.quantityOnHand, 1);
    });

    test('reintegrates tracked stock when a sale is voided', () async {
      final inventory = LocalInventoryDataSource(database);
      repository = SalesRepository(
        LocalSalesDataSource(database, inventoryDataSource: inventory),
        syncQueueRepository: syncQueueRepository,
        inventoryDataSource: inventory,
      );
      await _insertProduct(database, tracksInventory: true);
      await inventory.registerPurchase(
        productId: 'product-1',
        quantity: 10,
        userId: 'admin-1',
      );
      final createdAt = DateTime(2026, 6, 23, 10);
      await repository.saveSale(
        sale: Sale(
          id: 'sale-void-stock',
          invoiceNumber: 'F-102',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 200,
          totalInCents: 200,
          createdAt: createdAt,
        ),
        items: [
          SaleItem(
            id: 'item-void-stock',
            saleId: 'sale-void-stock',
            productId: 'product-1',
            productName: 'Pollo',
            categoryName: 'Comidas',
            quantity: 2,
            unitPriceInCents: 100,
            unitCostInCents: 50,
            createdAt: createdAt,
          ),
        ],
      );

      await repository.voidSale(
        saleId: 'sale-void-stock',
        reason: 'Error',
        voidedBy: 'admin-1',
      );

      final stockRows = await database
          .select(database.localInventoryStock)
          .get();
      final movements = await database
          .select(database.localInventoryMovements)
          .get();

      expect(stockRows.single.quantityOnHand, 10);
      expect(movements.map((movement) => movement.movementType), [
        'purchase',
        'sale',
        'sale_void',
      ]);
    });

    test('decrements packaging stock for to-go sales', () async {
      final packaging = LocalPackagingDataSource(database);
      repository = SalesRepository(
        LocalSalesDataSource(database, packagingDataSource: packaging),
        syncQueueRepository: syncQueueRepository,
        packagingDataSource: packaging,
      );
      await _insertProduct(database, tracksInventory: false);
      await _insertPackagingSetup(database, packaging);

      final createdAt = DateTime(2026, 6, 23, 10);
      final result = await repository.saveSale(
        sale: Sale(
          id: 'sale-packaging',
          invoiceNumber: 'F-200',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 300,
          totalInCents: 300,
          salesTypeId: 'sales-type-to-go',
          salesTypeName: 'Para llevar',
          createdAt: createdAt,
        ),
        items: [
          SaleItem(
            id: 'item-packaging',
            saleId: 'sale-packaging',
            productId: 'product-1',
            productName: 'Pollo',
            categoryName: 'Comidas',
            quantity: 3,
            unitPriceInCents: 100,
            unitCostInCents: 50,
            createdAt: createdAt,
          ),
        ],
      );

      final stockRows = await database
          .select(database.localPackagingStock)
          .get();
      final movements = await database
          .select(database.localPackagingMovements)
          .get();
      final syncResult = await syncQueueRepository.getPendingItems();
      final saleSync =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.last;
      final packagingPayload =
          saleSync.payload['packagingMovements']! as List<Object?>;
      final packagingMovement =
          packagingPayload.single! as Map<String, Object?>;

      expect(result, isA<AppSuccess<Sale>>());
      expect(stockRows.single.quantityOnHand, 7);
      expect(movements.map((movement) => movement.movementType), [
        'packaging_purchase',
        'packaging_sale',
      ]);
      expect(packagingPayload, hasLength(1));
      expect(packagingMovement['quantityDelta'], -3);
      expect(saleSync.payload['sale'], isA<Map<String, Object?>>());
      expect(
        (saleSync.payload['sale']! as Map<String, Object?>)['salesTypeName'],
        'Para llevar',
      );
    });

    test('does not decrement packaging stock for dine-in sales', () async {
      final packaging = LocalPackagingDataSource(database);
      repository = SalesRepository(
        LocalSalesDataSource(database, packagingDataSource: packaging),
        syncQueueRepository: syncQueueRepository,
        packagingDataSource: packaging,
      );
      await _insertProduct(database, tracksInventory: false);
      await _insertPackagingSetup(database, packaging);
      await _insertDineInPackagingRule(database);

      final createdAt = DateTime(2026, 6, 23, 10);
      final result = await repository.saveSale(
        sale: Sale(
          id: 'sale-packaging-dine-in',
          invoiceNumber: 'F-203',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 300,
          totalInCents: 300,
          salesTypeId: 'sales-type-dine-in',
          salesTypeName: 'Comer aqui',
          createdAt: createdAt,
        ),
        items: [
          SaleItem(
            id: 'item-packaging-dine-in',
            saleId: 'sale-packaging-dine-in',
            productId: 'product-1',
            productName: 'Pollo',
            categoryName: 'Comidas',
            quantity: 3,
            unitPriceInCents: 100,
            unitCostInCents: 50,
            createdAt: createdAt,
          ),
        ],
      );

      final stockRows = await database
          .select(database.localPackagingStock)
          .get();
      final movements = await database
          .select(database.localPackagingMovements)
          .get();
      final syncResult = await syncQueueRepository.getPendingItems();
      final saleSync =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.last;
      final packagingPayload =
          saleSync.payload['packagingMovements']! as List<Object?>;

      expect(result, isA<AppSuccess<Sale>>());
      expect(stockRows.single.quantityOnHand, 10);
      expect(movements.map((movement) => movement.movementType), [
        'packaging_purchase',
      ]);
      expect(packagingPayload, isEmpty);
    });

    test('blocks to-go sale when packaging stock is insufficient', () async {
      final packaging = LocalPackagingDataSource(database);
      repository = SalesRepository(
        LocalSalesDataSource(database, packagingDataSource: packaging),
        syncQueueRepository: syncQueueRepository,
        packagingDataSource: packaging,
      );
      await _insertProduct(database, tracksInventory: false);
      await _insertPackagingSetup(database, packaging, quantity: 1);

      final result = await repository.saveSale(
        sale: Sale(
          id: 'sale-packaging-blocked',
          invoiceNumber: 'F-201',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 200,
          totalInCents: 200,
          salesTypeId: 'sales-type-to-go',
          salesTypeName: 'Para llevar',
          createdAt: DateTime(2026, 6, 23, 10),
        ),
        items: [
          SaleItem(
            id: 'item-packaging-blocked',
            saleId: 'sale-packaging-blocked',
            productId: 'product-1',
            productName: 'Pollo',
            categoryName: 'Comidas',
            quantity: 2,
            unitPriceInCents: 100,
            unitCostInCents: 50,
            createdAt: DateTime(2026, 6, 23, 10),
          ),
        ],
      );

      final sales = await database.select(database.localSales).get();
      final stockRows = await database
          .select(database.localPackagingStock)
          .get();

      expect(result, isA<AppFailureResult<Sale>>());
      expect(sales, isEmpty);
      expect(stockRows.single.quantityOnHand, 1);
    });

    test('reintegrates packaging stock when a to-go sale is voided', () async {
      final packaging = LocalPackagingDataSource(database);
      repository = SalesRepository(
        LocalSalesDataSource(database, packagingDataSource: packaging),
        syncQueueRepository: syncQueueRepository,
        packagingDataSource: packaging,
      );
      await _insertProduct(database, tracksInventory: false);
      await _insertPackagingSetup(database, packaging);
      final createdAt = DateTime(2026, 6, 23, 10);
      await repository.saveSale(
        sale: Sale(
          id: 'sale-packaging-void',
          invoiceNumber: 'F-202',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 200,
          totalInCents: 200,
          salesTypeId: 'sales-type-to-go',
          salesTypeName: 'Para llevar',
          createdAt: createdAt,
        ),
        items: [
          SaleItem(
            id: 'item-packaging-void',
            saleId: 'sale-packaging-void',
            productId: 'product-1',
            productName: 'Pollo',
            categoryName: 'Comidas',
            quantity: 2,
            unitPriceInCents: 100,
            unitCostInCents: 50,
            createdAt: createdAt,
          ),
        ],
      );

      await repository.voidSale(
        saleId: 'sale-packaging-void',
        reason: 'Error',
        voidedBy: 'admin-1',
      );

      final stockRows = await database
          .select(database.localPackagingStock)
          .get();
      final movements = await database
          .select(database.localPackagingMovements)
          .get();

      expect(stockRows.single.quantityOnHand, 10);
      expect(movements.map((movement) => movement.movementType), [
        'packaging_purchase',
        'packaging_sale',
        'packaging_sale_void',
      ]);
    });
  });
}

Future<void> _insertProduct(
  AppDatabase database, {
  required bool tracksInventory,
}) async {
  final now = DateTime(2026, 6, 23);
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
          tracksInventory: Value(tracksInventory),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _insertDineInPackagingRule(AppDatabase database) async {
  final now = DateTime(2026, 6, 23);
  await database
      .into(database.localSalesTypes)
      .insert(
        LocalSalesTypesCompanion.insert(
          id: 'sales-type-dine-in',
          code: 'dine_in',
          name: 'Comer aqui',
          displayOrder: const Value(0),
          isDefault: const Value(true),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localProductPackagingRules)
      .insert(
        LocalProductPackagingRulesCompanion.insert(
          id: 'rule-dine-in-should-not-consume',
          productId: 'product-1',
          salesTypeId: 'sales-type-dine-in',
          packagingItemId: 'packaging-1',
          quantityPerUnit: const Value(1),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _insertPackagingSetup(
  AppDatabase database,
  LocalPackagingDataSource packaging, {
  int quantity = 10,
}) async {
  final now = DateTime(2026, 6, 23);
  await database
      .into(database.localSalesTypes)
      .insert(
        LocalSalesTypesCompanion.insert(
          id: 'sales-type-to-go',
          code: 'to_go',
          name: 'Para llevar',
          displayOrder: const Value(1),
          isDefault: const Value(false),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localPackagingItems)
      .insert(
        LocalPackagingItemsCompanion.insert(
          id: 'packaging-1',
          name: 'Bandeja',
          costInCents: const Value(30),
          tracksStock: const Value(true),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localProductPackagingRules)
      .insert(
        LocalProductPackagingRulesCompanion.insert(
          id: 'rule-1',
          productId: 'product-1',
          salesTypeId: 'sales-type-to-go',
          packagingItemId: 'packaging-1',
          quantityPerUnit: const Value(1),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await packaging.applyPurchaseMovement(
    packaging.purchaseMovement(
      packagingItemId: 'packaging-1',
      quantity: quantity,
      unitCostInCents: 30,
      userId: 'admin-1',
    ),
  );
}
