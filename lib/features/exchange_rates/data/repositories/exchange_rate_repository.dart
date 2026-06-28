import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/exchange_rates/data/datasources/local_exchange_rate_datasource.dart';
import 'package:smoo_control/features/exchange_rates/data/models/exchange_rate_model.dart';
import 'package:smoo_control/features/exchange_rates/domain/entities/exchange_rate.dart';
import 'package:smoo_control/features/exchange_rates/domain/repositories/i_exchange_rate_repository.dart';

/// Exchange rate repository backed by local database.
final class ExchangeRateRepository implements IExchangeRateRepository {
  /// Creates an exchange rate repository.
  const ExchangeRateRepository(this._localDataSource);

  final LocalExchangeRateDataSource _localDataSource;

  @override
  Future<AppResult<List<ExchangeRate>>> getRatesForMonth({
    required String currencyCode,
    required DateTime month,
  }) async {
    try {
      final rates = await _localDataSource.getRatesForMonth(
        currencyCode: currencyCode,
        month: month,
      );
      return AppSuccess(rates.map((rate) => rate.toEntity()).toList());
    } on Object catch (error) {
      return _failure(
        'exchange_rates_read_failed',
        'No se pudieron leer.',
        error,
      );
    }
  }

  @override
  Future<AppResult<ExchangeRate?>> getRateForDate({
    required String currencyCode,
    required DateTime date,
  }) async {
    try {
      final rate = await _localDataSource.getRateForDate(
        currencyCode: currencyCode,
        date: date,
      );
      return AppSuccess(rate?.toEntity());
    } on Object catch (error) {
      return _failure(
        'exchange_rate_read_failed',
        'No se pudo leer la tasa de cambio.',
        error,
      );
    }
  }

  @override
  Future<AppResult<ExchangeRate>> saveRate(ExchangeRate rate) async {
    try {
      final saved = await _localDataSource.saveRate(
        ExchangeRateModel.fromEntity(rate),
      );
      return AppSuccess(saved.toEntity());
    } on Object catch (error) {
      return _failure(
        'exchange_rate_save_failed',
        'No se pudo guardar la tasa de cambio.',
        error,
      );
    }
  }

  @override
  Future<AppResult<List<ExchangeRate>>> fillMonth({
    required String currencyCode,
    required DateTime month,
    required int rateInCents,
  }) async {
    try {
      final days = DateTime(month.year, month.month + 1, 0).day;
      final rates = [
        for (var day = 1; day <= days; day += 1)
          ExchangeRateModel(
            currencyCode: currencyCode.toUpperCase(),
            businessDate: DateTime(month.year, month.month, day),
            rateInCents: rateInCents,
          ),
      ];
      final saved = await _localDataSource.saveRates(rates);
      return AppSuccess(saved.map((rate) => rate.toEntity()).toList());
    } on Object catch (error) {
      return _failure(
        'exchange_rates_fill_failed',
        'No se pudo aplicar la tasa al mes.',
        error,
      );
    }
  }

  AppFailureResult<T> _failure<T>(
    String code,
    String message,
    Object error,
  ) {
    return AppFailureResult(
      AppFailure(code: code, message: message, cause: error),
    );
  }
}
