import 'package:equatable/equatable.dart';

/// Exchange rate for one business date.
final class ExchangeRate extends Equatable {
  /// Creates an exchange rate.
  const ExchangeRate({
    required this.currencyCode,
    required this.businessDate,
    required this.rateInCents,
    this.rateInTenThousandths,
  });

  /// ISO currency code, for example USD.
  final String currencyCode;

  /// Business date normalized to local midnight.
  final DateTime businessDate;

  /// Local currency cents per one foreign currency unit.
  final int rateInCents;

  /// Exact 4-decimal remote rate; optional for legacy POS/local records.
  final int? rateInTenThousandths;

  /// Decimal rate shown to users.
  double get rate => (rateInTenThousandths ?? rateInCents * 100) / 10000;

  @override
  List<Object?> get props => [
    currencyCode,
    businessDate,
    rateInCents,
    rateInTenThousandths,
  ];
}
