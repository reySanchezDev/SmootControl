import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/exchange_rates/domain/entities/exchange_rate.dart';

/// Data model for a local exchange rate.
final class ExchangeRateModel extends Equatable {
  /// Creates an exchange rate model.
  const ExchangeRateModel({
    required this.currencyCode,
    required this.businessDate,
    required this.rateInCents,
  });

  /// Creates a model from Drift row.
  factory ExchangeRateModel.fromLocal(LocalExchangeRate row) {
    return ExchangeRateModel(
      currencyCode: row.currencyCode,
      businessDate: row.businessDate,
      rateInCents: row.rateInCents,
    );
  }

  /// Creates a model from entity.
  factory ExchangeRateModel.fromEntity(ExchangeRate entity) {
    return ExchangeRateModel(
      currencyCode: entity.currencyCode,
      businessDate: entity.businessDate,
      rateInCents: entity.rateInCents,
    );
  }

  /// ISO currency code.
  final String currencyCode;

  /// Business date.
  final DateTime businessDate;

  /// Local cents per one foreign unit.
  final int rateInCents;

  /// Converts to entity.
  ExchangeRate toEntity() {
    return ExchangeRate(
      currencyCode: currencyCode,
      businessDate: businessDate,
      rateInCents: rateInCents,
    );
  }

  @override
  List<Object?> get props => [currencyCode, businessDate, rateInCents];
}
