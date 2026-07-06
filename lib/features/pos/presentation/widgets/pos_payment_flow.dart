import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/exchange_rates/domain/repositories/i_exchange_rate_repository.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method_pos_display.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_amount_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Starts the shared POS payment flow for a final payment method.
Future<void> startPosPaymentFlow({
  required BuildContext context,
  required PaymentMethod method,
  required PosReady state,
  VoidCallback? onPaymentCompleted,
}) async {
  final bloc = context.read<PosBloc>();
  if (method.affectsCashRegister) {
    final exchangeRate = await _exchangeRateFor(context, method);
    if (exchangeRate == _missingExchangeRate || !context.mounted) return;
    final received = await showDialog<int>(
      context: context,
      builder: (_) => PosPaymentAmountDialog(
        exchangeRateInCents: exchangeRate,
        methodName: method.posOptionName,
        prefixText: _paymentPrefix(method),
        totalInCents: state.totalInCents,
      ),
    );
    if (received == null || !context.mounted) return;
    await _showChangeIfNeeded(context, state, received);
    if (!context.mounted) return;
    bloc
      ..add(PosPaymentMethodSelected(method.id))
      ..add(const PosCheckoutRequested());
    onPaymentCompleted?.call();
    return;
  }

  if (method.requiresReference) {
    final reference = await _requestReference(context, method);
    if (reference == null || reference.trim().isEmpty || !context.mounted) {
      return;
    }
    bloc
      ..add(PosPaymentMethodSelected(method.id))
      ..add(PosCheckoutRequested(paymentReference: reference));
    onPaymentCompleted?.call();
    return;
  }

  bloc
    ..add(PosPaymentMethodSelected(method.id))
    ..add(const PosCheckoutRequested());
  onPaymentCompleted?.call();
}

const _missingExchangeRate = -1;

Future<int?> _exchangeRateFor(
  BuildContext context,
  PaymentMethod method,
) async {
  final currency = method.currencyCode?.trim().toUpperCase();
  if (currency == null || currency.isEmpty || currency == 'NIO') {
    return null;
  }

  final result = await serviceLocator<IExchangeRateRepository>().getRateForDate(
    currencyCode: currency,
    date: DateTime.now(),
  );
  if (!context.mounted) return _missingExchangeRate;

  switch (result) {
    case AppSuccess(:final value) when value != null:
      return value.rateInCents;
    case AppSuccess():
      return _showMissingExchangeRate(context, currency);
    case AppFailureResult(:final error):
      return _showExchangeRateError(context, error.message);
  }
}

Future<int> _showMissingExchangeRate(
  BuildContext context,
  String currency,
) async {
  await showAppMessageDialog(
    context: context,
    message: AppLocalizations.of(context).exchangeRateMissingMessage(currency),
  );
  return _missingExchangeRate;
}

Future<int> _showExchangeRateError(
  BuildContext context,
  String message,
) async {
  await showAppMessageDialog(context: context, message: message);
  return _missingExchangeRate;
}

String? _paymentPrefix(PaymentMethod method) {
  final currency = method.currencyCode?.trim().toUpperCase();
  if (currency == null || currency.isEmpty || currency == 'NIO') {
    return null;
  }
  return '$currency ';
}

Future<void> _showChangeIfNeeded(
  BuildContext context,
  PosReady state,
  int receivedInCents,
) async {
  final change = receivedInCents - state.totalInCents;
  if (change <= 0) return;
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.posChangeDueLabel),
      content: Text(l10n.paymentChangeMessage(MoneyFormatter.format(change))),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.okAction),
        ),
      ],
    ),
  );
}

Future<String?> _requestReference(
  BuildContext context,
  PaymentMethod method,
) async {
  return showTouchTextKeyboardDialog(
    context: context,
    label: AppLocalizations.of(context).paymentReferenceField,
    title: method.posOptionName,
  );
}
