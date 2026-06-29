import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/exchange_rates/data/datasources/local_exchange_rate_datasource.dart';
import 'package:smoo_control/features/exchange_rates/data/models/exchange_rate_model.dart';
import 'package:smoo_control/features/exchange_rates/domain/entities/exchange_rate.dart';
import 'package:smoo_control/features/exchange_rates/domain/repositories/i_exchange_rate_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// Exchange rate repository backed by local database.
final class ExchangeRateRepository implements IExchangeRateRepository {
  /// Creates an exchange rate repository.
  const ExchangeRateRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalExchangeRateDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

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
      final entity = saved.toEntity();
      await _enqueueRate(entity);
      return AppSuccess(entity);
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
      final entities = saved.map((rate) => rate.toEntity()).toList();
      for (final rate in entities) {
        await _enqueueRate(rate);
      }
      return AppSuccess(entities);
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

  Future<void> _enqueueRate(ExchangeRate rate) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'exchange_rates',
      entityId: '${rate.currencyCode}-${rate.businessDate.toIso8601String()}',
      operation: SyncOperation.update,
      payload: {
        'currencyCode': rate.currencyCode,
        'businessDate': rate.businessDate.toIso8601String(),
        'rateInCents': rate.rateInCents,
      },
    );
  }
}
