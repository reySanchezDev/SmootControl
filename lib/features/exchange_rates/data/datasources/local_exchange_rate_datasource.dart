import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/exchange_rates/data/models/exchange_rate_model.dart';

/// Local datasource for exchange rates.
final class LocalExchangeRateDataSource {
  /// Creates a local exchange rate datasource.
  const LocalExchangeRateDataSource(this._database);

  final AppDatabase _database;

  /// Reads all rates for one month.
  Future<List<ExchangeRateModel>> getRatesForMonth({
    required String currencyCode,
    required DateTime month,
  }) async {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    final query = _database.select(_database.localExchangeRates)
      ..where((rate) {
        return rate.currencyCode.equals(currencyCode.toUpperCase()) &
            rate.businessDate.isBetweenValues(from, to);
      })
      ..orderBy([(rate) => OrderingTerm.asc(rate.businessDate)]);
    final rows = await query.get();

    return rows.map(ExchangeRateModel.fromLocal).toList();
  }

  /// Reads one rate for one business date.
  Future<ExchangeRateModel?> getRateForDate({
    required String currencyCode,
    required DateTime date,
  }) async {
    final businessDate = DateTime(date.year, date.month, date.day);
    final query = _database.select(_database.localExchangeRates)
      ..where((rate) {
        return rate.currencyCode.equals(currencyCode.toUpperCase()) &
            rate.businessDate.equals(businessDate);
      })
      ..limit(1);
    final row = await query.getSingleOrNull();

    return row == null ? null : ExchangeRateModel.fromLocal(row);
  }

  /// Saves one rate.
  Future<ExchangeRateModel> saveRate(ExchangeRateModel rate) async {
    final now = DateTime.now();
    await _database
        .into(_database.localExchangeRates)
        .insertOnConflictUpdate(
          LocalExchangeRatesCompanion(
            currencyCode: Value(rate.currencyCode.toUpperCase()),
            businessDate: Value(
              DateTime(
                rate.businessDate.year,
                rate.businessDate.month,
                rate.businessDate.day,
              ),
            ),
            rateInCents: Value(rate.rateInCents),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return rate;
  }

  /// Saves many rates.
  Future<List<ExchangeRateModel>> saveRates(List<ExchangeRateModel> rates) {
    return _database.transaction(() async {
      final saved = <ExchangeRateModel>[];
      for (final rate in rates) {
        saved.add(await saveRate(rate));
      }
      return saved;
    });
  }
}
