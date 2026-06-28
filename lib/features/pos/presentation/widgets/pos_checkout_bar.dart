import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_danger_confirmation.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_method_selector.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_account_payments.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_dialog_launcher.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_table_selector.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_input_helpers.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Fast checkout controls displayed at the bottom of the POS.
class PosCheckoutBar extends StatelessWidget {
  /// Creates checkout controls.
  const PosCheckoutBar({
    required this.amountReceivedController,
    required this.referenceController,
    required this.state,
    super.key,
  });

  /// Amount received input controller.
  final TextEditingController amountReceivedController;

  /// Payment reference input controller.
  final TextEditingController referenceController;

  /// Current POS ready state.
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final selectedMethod = state.selectedPaymentMethod;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 820) {
            return ListView(
              children: _content(context, selectedMethod),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: _leftControls(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  children: _paymentControls(context, selectedMethod),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: Column(children: _totalControls(context)),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    PaymentMethod? selectedMethod,
  ) {
    return [
      ..._leftControls(context),
      const SizedBox(height: 8),
      ..._paymentControls(context, selectedMethod),
      const SizedBox(height: 8),
      ..._totalControls(context),
    ];
  }

  List<Widget> _leftControls(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      PosTableSelector(
        selectedTableId: state.selectedTableId,
        tables: state.tables,
      ),
      const SizedBox(height: 8),
      AppButton(
        icon: Icons.call_split,
        label: l10n.splitAccountsAction,
        onPressed: state.selectedTableId == null || state.cartLines.isEmpty
            ? null
            : () => _openSplitDialog(context),
        primary: false,
      ),
    ];
  }

  List<Widget> _paymentControls(
    BuildContext context,
    PaymentMethod? selectedMethod,
  ) {
    final l10n = AppLocalizations.of(context);
    if (state.hasSplitAccounts) {
      return [PosSplitAccountPayments(state: state)];
    }

    return [
      PosPaymentMethodSelector(
        methods: state.paymentMethods,
        selectedPaymentMethodId: state.selectedPaymentMethodId,
      ),
      if (selectedMethod?.requiresReference ?? false) ...[
        const SizedBox(height: 8),
        AppInput(
          label: l10n.paymentReferenceField,
          controller: referenceController,
          onTap: () => openPosTextInput(
            context: context,
            controller: referenceController,
            label: l10n.paymentReferenceField,
          ),
          readOnly: true,
        ),
      ],
      if (selectedMethod?.affectsCashRegister ?? false) ...[
        const SizedBox(height: 8),
        AppInput(
          label: l10n.posAmountReceivedField,
          controller: amountReceivedController,
          onTap: () => openPosMoneyInput(
            context: context,
            controller: amountReceivedController,
            label: l10n.posAmountReceivedField,
          ),
          readOnly: true,
        ),
      ],
    ];
  }

  List<Widget> _totalControls(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedMethod = state.selectedPaymentMethod;
    return [
      AppText(
        MoneyFormatter.format(state.totalInCents),
        textAlign: TextAlign.end,
        variant: AppTextVariant.titleMedium,
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: amountReceivedController,
        builder: (context, value, _) {
          if (!(selectedMethod?.affectsCashRegister ?? false)) {
            return const SizedBox.shrink();
          }
          final change = _changeInCents(value.text);
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppText(
              '${l10n.posChangeDueLabel}: ${MoneyFormatter.format(change)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              variant: AppTextVariant.label,
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: referenceController,
        builder: (context, reference, _) {
          return ValueListenableBuilder<TextEditingValue>(
            valueListenable: amountReceivedController,
            builder: (context, amount, _) {
              return AppButton(
                icon: Icons.payments_outlined,
                label: l10n.checkoutAction,
                onPressed:
                    _canCheckout(
                      selectedMethod,
                      reference.text,
                      amount.text,
                    )
                    ? () => _checkout(context, selectedMethod)
                    : null,
              );
            },
          );
        },
      ),
      const SizedBox(height: 6),
      AppButton(
        icon: Icons.delete_outline,
        label: l10n.clearCartAction,
        onPressed: state.cartLines.isEmpty
            ? null
            : () => unawaited(_clearCart(context)),
        primary: false,
      ),
      if (state.lastCompletedSale != null) ...[
        const SizedBox(height: 6),
        AppText(l10n.checkoutSuccessTitle, textAlign: TextAlign.center),
      ],
    ];
  }

  bool _canCheckout(
    PaymentMethod? selectedMethod,
    String reference,
    String amountReceived,
  ) {
    if (state.cartLines.isEmpty) return false;
    if (state.hasSplitAccounts) return _canCheckoutSplitAccounts();
    if (selectedMethod == null) return false;
    if (selectedMethod.requiresReference && reference.trim().isEmpty) {
      return false;
    }
    if (selectedMethod.affectsCashRegister) {
      return _parseMoneyToCents(amountReceived) >= state.totalInCents;
    }
    return true;
  }

  bool _canCheckoutSplitAccounts() {
    for (final account in state.splitAccounts) {
      final method = _methodById(account.paymentMethodId);
      if (method == null) return false;
      if (method.requiresReference &&
          (account.paymentReference?.trim().isEmpty ?? true)) {
        return false;
      }
    }
    return true;
  }

  int _changeInCents(String amountReceived) {
    final change = _parseMoneyToCents(amountReceived) - state.totalInCents;
    return change < 0 ? 0 : change;
  }

  int _parseMoneyToCents(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    final amount = double.tryParse(normalized);
    if (amount == null) return 0;
    return (amount * 100).round();
  }

  void _checkout(BuildContext context, PaymentMethod? selectedMethod) {
    final needsReference =
        !state.hasSplitAccounts && (selectedMethod?.requiresReference ?? false);
    context.read<PosBloc>().add(
      PosCheckoutRequested(
        paymentReference: needsReference ? referenceController.text : null,
      ),
    );
  }

  Future<void> _clearCart(BuildContext context) async {
    final confirmed = await confirmClearPosTicket(context);
    if (!confirmed || !context.mounted) return;
    referenceController.clear();
    amountReceivedController.clear();
    context.read<PosBloc>().add(const PosCartCleared());
  }

  PaymentMethod? _methodById(String? methodId) {
    for (final method in state.paymentMethods) {
      if (method.id == methodId) return method;
    }
    return null;
  }

  void _openSplitDialog(BuildContext context) {
    unawaited(
      showPosSplitAccountsDialog(
        context: context,
        state: state,
      ),
    );
  }
}
