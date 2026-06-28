import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';

/// POS-specific display helpers for payment methods.
extension PaymentMethodPosDisplay on PaymentMethod {
  /// Group label used by the first payment button level.
  String get posGroupName {
    if (parentId != null) return name;
    final configured = groupName.trim();
    if (configured.isNotEmpty && configured != 'Otros') return configured;

    final normalized = name.toLowerCase();
    if (normalized.contains('efectivo') || normalized.contains('cash')) {
      return 'Efectivo';
    }
    if (normalized.contains('tarjeta') || normalized.contains('card')) {
      return 'Tarjeta';
    }
    if (normalized.contains('transfer')) return 'Transferencia';
    return configured.isEmpty ? 'Otros' : configured;
  }

  /// Option label used after selecting a payment group.
  String get posOptionName {
    if (!isPaymentTarget) return name;
    final currency = currencyCode?.trim().toUpperCase();
    final normalized = name.toLowerCase();
    if (posGroupName == 'Efectivo' || groupName == 'Efectivo') {
      if (currency == 'NIO') return 'Cordoba';
      if (currency == 'USD') return 'Dolar';
      if (normalized.contains('dolar') || normalized.contains('usd')) {
        return 'Dolar';
      }
      if (normalized.contains('cordoba') || normalized.contains('nio')) {
        return 'Cordoba';
      }
    }

    return name;
  }
}
