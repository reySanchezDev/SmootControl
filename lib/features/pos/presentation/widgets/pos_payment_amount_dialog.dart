import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/touch_numeric_keyboard_dialog.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Touch-first amount dialog for POS cash payments.
class PosPaymentAmountDialog extends StatelessWidget {
  /// Creates an amount dialog.
  const PosPaymentAmountDialog({
    required this.methodName,
    required this.totalInCents,
    this.exchangeRateInCents,
    this.prefixText,
    super.key,
  });

  /// Selected payment method name.
  final String methodName;

  /// Current ticket total.
  final int totalInCents;

  /// Local currency cents per one foreign currency unit.
  final int? exchangeRateInCents;

  /// Visible input prefix.
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TouchNumericKeyboardDialog<int>(
      initialValue: _initialValue,
      prefixText: prefixText ?? '${MoneyFormatter.symbol} ',
      resultBuilder: _parseToLocalCents,
      title: l10n.paymentAmountTitle(methodName),
      validator: (value) {
        final amount = _parseToLocalCents(value);
        if (amount == null || amount < totalInCents) {
          return l10n.paymentAmountInsufficient;
        }
        return null;
      },
    );
  }

  String get _initialValue {
    final rate = exchangeRateInCents;
    if (rate == null) return (totalInCents / 100).toStringAsFixed(2);

    final foreignCents = (totalInCents * 100 / rate).ceil();
    return (foreignCents / 100).toStringAsFixed(2);
  }

  int? _parseToLocalCents(String value) {
    final amount = MoneyFormatter.parseToCents(value);
    final rate = exchangeRateInCents;
    if (amount == null) return null;
    if (rate == null) return amount;

    return (amount * rate / 100).round();
  }
}
