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
import 'package:smoo_control/features/payment_methods/domain/services/payment_method_tree_service.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_amount_dialog.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

const _legacyPrefix = 'legacy-group:';

/// Tactile hierarchical payment navigation for the POS.
class PosPaymentSection extends StatelessWidget {
  /// Creates the payment section.
  const PosPaymentSection({
    required this.onPaymentParentChanged,
    required this.paymentParentKey,
    required this.state,
    super.key,
  });

  /// Current parent node key. Legacy groups use an internal prefix.
  final String? paymentParentKey;

  /// Payment navigation change callback.
  final ValueChanged<String?> onPaymentParentChanged;

  /// Current POS state.
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    return PosTouchGrid(
      minTileHeight: 52,
      minTileWidth: 118,
      children: _buttons(context),
    );
  }

  List<Widget> _buttons(BuildContext context) {
    final key = paymentParentKey;
    if (key == null) return _rootButtons(context);
    if (key.startsWith(_legacyPrefix)) {
      return _legacyMethodButtons(context, key.substring(_legacyPrefix.length));
    }
    return _childButtons(context, key);
  }

  List<Widget> _rootButtons(BuildContext context) {
    final active = _activeMethods();
    final realRoots = PaymentMethodTreeService.childrenOf(active, null);
    final rootNames = realRoots.map((method) => method.name).toSet();
    final legacyGroups = _legacyGroups(active, rootNames);

    return [
      for (final method in realRoots) _methodButton(context, method),
      for (final group in legacyGroups)
        PosTouchButton(
          label: group,
          onPressed: () => onPaymentParentChanged('$_legacyPrefix$group'),
        ),
    ];
  }

  List<Widget> _childButtons(BuildContext context, String parentId) {
    final methods = PaymentMethodTreeService.childrenOf(
      _activeMethods(),
      parentId,
    );
    return [
      for (final method in methods) _methodButton(context, method),
      _backButton(parentId),
    ];
  }

  List<Widget> _legacyMethodButtons(BuildContext context, String group) {
    final methods = _activeMethods().where((method) {
      return method.parentId == null &&
          method.isPaymentTarget &&
          method.posGroupName == group;
    }).toList()..sort(_compareMethods);

    return [
      for (final method in methods) _finalPaymentButton(context, method),
      _backButton(null),
    ];
  }

  Widget _methodButton(BuildContext context, PaymentMethod method) {
    final hasChildren = _activeMethods().any((entry) {
      return entry.parentId == method.id;
    });
    if (hasChildren || !method.isPaymentTarget) {
      return PosTouchButton(
        label: method.name,
        onPressed: () => onPaymentParentChanged(method.id),
      );
    }
    return _finalPaymentButton(context, method);
  }

  Widget _finalPaymentButton(BuildContext context, PaymentMethod method) {
    return PosTouchButton(
      label: method.posOptionName,
      onPressed: state.cartLines.isEmpty
          ? null
          : () => _startPaymentFlow(context, method),
      selected: state.selectedPaymentMethodId == method.id,
    );
  }

  Widget _backButton(String? parentId) {
    return PosTouchButton(
      label: 'Regresar',
      onPressed: () => onPaymentParentChanged(_parentOf(parentId)),
      tone: PosButtonTone.neutral,
    );
  }

  String? _parentOf(String? parentId) {
    if (parentId == null) return null;
    for (final method in state.paymentMethods) {
      if (method.id == parentId) return method.parentId;
    }
    return null;
  }

  List<PaymentMethod> _activeMethods() {
    return state.paymentMethods.where((method) => method.isActive).toList();
  }

  List<String> _legacyGroups(
    List<PaymentMethod> methods,
    Set<String> realRootNames,
  ) {
    final groups = <String>{};
    for (final method in methods) {
      if (method.parentId != null || !method.isPaymentTarget) continue;
      final group = method.posGroupName;
      if (!realRootNames.contains(group)) groups.add(group);
    }
    return groups.toList()..sort();
  }

  Future<void> _startPaymentFlow(
    BuildContext context,
    PaymentMethod method,
  ) async {
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
      await _showChangeIfNeeded(context, received);
      if (!context.mounted) return;
      bloc
        ..add(PosPaymentMethodSelected(method.id))
        ..add(const PosCheckoutRequested());
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
      return;
    }

    bloc
      ..add(PosPaymentMethodSelected(method.id))
      ..add(const PosCheckoutRequested());
  }

  static const _missingExchangeRate = -1;

  Future<int?> _exchangeRateFor(
    BuildContext context,
    PaymentMethod method,
  ) async {
    final currency = method.currencyCode?.trim().toUpperCase();
    if (currency == null || currency.isEmpty || currency == 'NIO') {
      return null;
    }

    final result = await serviceLocator<IExchangeRateRepository>()
        .getRateForDate(currencyCode: currency, date: DateTime.now());
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
      message: AppLocalizations.of(context).exchangeRateMissingMessage(
        currency,
      ),
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

  int _compareMethods(PaymentMethod first, PaymentMethod second) {
    final order = first.displayOrder.compareTo(second.displayOrder);
    if (order != 0) return order;
    return first.posOptionName.compareTo(second.posOptionName);
  }
}
