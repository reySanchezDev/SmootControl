import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local exchange rates by business date.
class LocalExchangeRates extends Table with SyncColumns {
  /// ISO currency code, for example USD.
  TextColumn get currencyCode => text()();

  /// Business date normalized to local midnight.
  DateTimeColumn get businessDate => dateTime()();

  /// Local currency cents per one foreign currency unit.
  IntColumn get rateInCents => integer()();

  @override
  Set<Column<Object>> get primaryKey => {currencyCode, businessDate};
}
