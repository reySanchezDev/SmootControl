import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';

/// Contract for restaurant table persistence.
abstract interface class ITablesRepository {
  /// Returns restaurant tables.
  Future<AppResult<List<RestaurantTable>>> getTables();

  /// Saves a restaurant table.
  Future<AppResult<RestaurantTable>> saveTable(RestaurantTable table);

  /// Returns named accounts for a table.
  Future<AppResult<List<TableAccount>>> getTableAccounts(String tableId);

  /// Saves named accounts for a table.
  Future<AppResult<List<TableAccount>>> saveTableAccounts(
    List<TableAccount> accounts,
  );
}
