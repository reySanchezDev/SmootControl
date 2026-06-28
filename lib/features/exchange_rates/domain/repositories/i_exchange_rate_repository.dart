import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/exchange_rates/domain/entities/exchange_rate.dart';

/// Contract for exchange rate management.
abstract interface class IExchangeRateRepository {
  /// Returns all rates for one month.
  Future<AppResult<List<ExchangeRate>>> getRatesForMonth({
    required String currencyCode,
    required DateTime month,
  });

  /// Returns one rate for a business date.
  Future<AppResult<ExchangeRate?>> getRateForDate({
    required String currencyCode,
    required DateTime date,
  });

  /// Saves one rate.
  Future<AppResult<ExchangeRate>> saveRate(ExchangeRate rate);

  /// Fills every day in a month with the same rate.
  Future<AppResult<List<ExchangeRate>>> fillMonth({
    required String currencyCode,
    required DateTime month,
    required int rateInCents,
  });
}
