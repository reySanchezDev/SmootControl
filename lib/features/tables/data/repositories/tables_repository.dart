import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/tables/data/datasources/local_tables_datasource.dart';
import 'package:smoo_control/features/tables/data/models/restaurant_table_model.dart';
import 'package:smoo_control/features/tables/data/models/table_account_model.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';

/// Tables repository backed by the local offline database.
final class TablesRepository implements ITablesRepository {
  /// Creates a tables repository.
  const TablesRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalTablesDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

  @override
  Future<AppResult<List<RestaurantTable>>> getTables() async {
    try {
      final tables = await _localDataSource.getTables();
      return AppSuccess(tables.map((table) => table.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'tables_read_failed',
          message: 'No se pudieron leer las mesas locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<RestaurantTable>> saveTable(RestaurantTable table) async {
    try {
      final model = RestaurantTableModel.fromEntity(table);
      final saved = await _localDataSource.saveTable(model);
      final entity = saved.toEntity();
      await _enqueueTable(entity);

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'table_save_failed',
          message: 'No se pudo guardar la mesa local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<TableAccount>>> getTableAccounts(String tableId) async {
    try {
      final accounts = await _localDataSource.getTableAccounts(tableId);
      return AppSuccess(
        accounts.map((account) => account.toEntity()).toList(),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'table_accounts_read_failed',
          message: 'No se pudieron leer las cuentas de la mesa.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<TableAccount>>> saveTableAccounts(
    List<TableAccount> accounts,
  ) async {
    try {
      final models = accounts.map(TableAccountModel.fromEntity).toList();
      final saved = await _localDataSource.saveTableAccounts(models);
      final entities = saved.map((account) => account.toEntity()).toList();
      await _enqueueTableAccounts(entities);

      return AppSuccess(entities);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'table_accounts_save_failed',
          message: 'No se pudieron guardar las cuentas de la mesa.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueueTable(RestaurantTable table) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'restaurant_tables',
      entityId: table.id,
      operation: SyncOperation.create,
      payload: {
        'id': table.id,
        'name': table.name,
        'display_name': table.displayName,
        'status': table.status.name,
        'is_active': table.isActive,
      },
    );
  }

  Future<void> _enqueueTableAccounts(List<TableAccount> accounts) async {
    for (final account in accounts) {
      await _syncQueueRepository?.enqueue(
        entityType: 'table_accounts',
        entityId: account.id,
        operation: SyncOperation.create,
        payload: {
          'id': account.id,
          'table_id': account.tableId,
          'name': account.name,
          'status': account.status.name,
        },
      );
    }
  }
}
