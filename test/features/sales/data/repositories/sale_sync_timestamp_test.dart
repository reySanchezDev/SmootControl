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
  test('serializes sale and line timestamps as UTC instants', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final syncQueue = SyncQueueRepository(LocalSyncQueueDataSource(database));
    final repository = SalesRepository(
      LocalSalesDataSource(database),
      syncQueueRepository: syncQueue,
    );
    final localTime = DateTime(2026, 11, 20, 15, 11, 9);

    await repository.saveSale(
      sale: Sale(
        id: 'sale-time-test',
        invoiceNumber: 'F-1',
        paymentMethodId: 'cash',
        status: SaleStatus.completed,
        subtotalInCents: 18000,
        totalInCents: 18000,
        createdAt: localTime,
      ),
      items: [
        SaleItem(
          id: 'sale-line-time-test',
          saleId: 'sale-time-test',
          productId: 'item-1',
          productName: 'Pollo',
          categoryName: '',
          quantity: 1,
          unitPriceInCents: 18000,
          unitCostInCents: 0,
          createdAt: localTime,
        ),
      ],
    );

    final result = await syncQueue.getPendingItems();
    final queueItem = (result as AppSuccess<List<SyncQueueItem>>).value.single;
    final salePayload = queueItem.payload['sale']! as Map<String, Object?>;
    final linePayload =
        (queueItem.payload['items']! as List).single as Map<String, Object?>;
    final expectedUtc = localTime.toUtc().toIso8601String();

    expect(salePayload['createdAt'], expectedUtc);
    expect(salePayload['createdAt'], endsWith('Z'));
    expect(linePayload['createdAt'], expectedUtc);
  });
}
