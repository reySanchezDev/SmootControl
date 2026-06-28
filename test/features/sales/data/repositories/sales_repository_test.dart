import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
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
  });
}
