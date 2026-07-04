import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:smoo_control/features/tables/data/datasources/local_tables_datasource.dart';
import 'package:smoo_control/features/tables/data/models/restaurant_table_model.dart';
import 'package:smoo_control/features/tables/data/repositories/tables_repository.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';

void main() {
  group('TablesRepository', () {
    late AppDatabase database;
    late TablesRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = TablesRepository(
        LocalTablesDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and returns local restaurant tables', () async {
      const table = RestaurantTable(
        id: 'table-1',
        name: 'Mesa 1',
        status: RestaurantTableStatus.occupied,
        isActive: true,
      );

      final saveResult = await repository.saveTable(table);
      final readResult = await repository.getTables();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<RestaurantTable>>());
      expect(
        (readResult as AppSuccess<List<RestaurantTable>>).value.single,
        table,
      );
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'restaurant_tables');
      expect(syncItem.entityId, table.id);
      expect(syncItem.payload['status'], RestaurantTableStatus.occupied.name);
    });

    test('saves and returns local table accounts', () async {
      const account = TableAccount(
        id: 'account-1',
        tableId: 'table-1',
        name: 'Ana',
        status: TableAccountStatus.invoiced,
      );

      final saveResult = await repository.saveTableAccounts([account]);
      final readResult = await repository.getTableAccounts('table-1');
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<List<TableAccount>>>());
      expect(
        (readResult as AppSuccess<List<TableAccount>>).value.single,
        account,
      );
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'table_accounts');
      expect(syncItem.entityId, account.id);
    });

    test(
      'saves POS display name locally without remote sync',
      () async {
        const table = RestaurantTable(
          id: 'table-1',
          name: 'Mesa 1',
          status: RestaurantTableStatus.available,
          isActive: true,
        );
        final remoteFirstRepository = TablesRepository(
          LocalTablesDataSource(database),
          syncQueueRepository: syncQueueRepository,
          remoteSender: const _FailingRemoteSender(),
        );
        await LocalTablesDataSource(database).saveTable(
          RestaurantTableModel.fromEntity(table),
        );

        const renamed = RestaurantTable(
          id: 'table-1',
          name: 'Mesa 1',
          displayName: 'JOSE',
          status: RestaurantTableStatus.available,
          isActive: true,
        );
        final saveResult = await remoteFirstRepository.saveTableDisplayName(
          renamed,
        );
        final readResult = await remoteFirstRepository.getTables();
        final syncResult = await syncQueueRepository.getPendingItems();

        expect(saveResult, isA<AppSuccess<RestaurantTable>>());
        expect(
          (readResult as AppSuccess<List<RestaurantTable>>)
              .value
              .single
              .displayName,
          'JOSE',
        );
        expect((syncResult as AppSuccess<List<SyncQueueItem>>).value, isEmpty);
      },
    );
  });
}

final class _FailingRemoteSender implements ISyncRemoteSender {
  const _FailingRemoteSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('remote failed');
  }
}
