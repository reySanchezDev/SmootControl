import 'package:equatable/equatable.dart';

/// Exchange rate for one business date.
final class ExchangeRate extends Equatable {
  /// Creates an exchange rate.
  const ExchangeRate({
    required this.currencyCode,
    required this.businessDate,
    required this.rateInCents,
  });

  /// ISO currency code, for example USD.
  final String currencyCode;

  /// Business date normalized to local midnight.
  final DateTime businessDate;

  /// Local currency cents per one foreign currency unit.
  final int rateInCents;

  /// Decimal rate shown to users.
  double get rate => rateInCents / 100;

  @override
  List<Object?> get props => [currencyCode, businessDate, rateInCents];
}
