import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_list_section.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_danger_confirmation.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_method_selector.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_account_payments.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_dialog_launcher.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_input_helpers.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Cart and checkout controls for the POS.
class PosCartPanel extends StatelessWidget {
  /// Creates the cart panel.
  const PosCartPanel({
    required this.referenceController,
    required this.state,
    super.key,
  });

  /// Payment reference input controller.
  final TextEditingController referenceController;

  /// Current POS ready state.
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedMethod = state.selectedPaymentMethod;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cartHeight =
              constraints.maxHeight * (state.hasSplitAccounts ? 0.28 : 0.46);

          return ListView(
            children: [
              AppText(l10n.cartTitle, variant: AppTextVariant.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: cartHeight.clamp(180, 360).toDouble(),
                child: _CartLines(lines: state.cartLines),
              ),
              const SizedBox(height: 12),
              _TableSelector(
                selectedTableId: state.selectedTableId,
                tables: state.tables,
              ),
              const SizedBox(height: 8),
              AppButton(
                icon: Icons.call_split,
                label: l10n.splitAccountsAction,
                onPressed:
                    state.selectedTableId == null || state.cartLines.isEmpty
                    ? null
                    : () => _openSplitDialog(context),
                primary: false,
              ),
              if (state.hasSplitAccounts) ...[
                const SizedBox(height: 8),
                AppText(
                  l10n.splitAccountsConfirmedMessage,
                  textAlign: TextAlign.center,
                  variant: AppTextVariant.label,
                ),
              ],
              const SizedBox(height: 12),
              if (state.hasSplitAccounts)
                PosSplitAccountPayments(state: state)
              else
                PosPaymentMethodSelector(
                  methods: state.paymentMethods,
                  selectedPaymentMethodId: state.selectedPaymentMethodId,
                ),
              if (!state.hasSplitAccounts &&
                  (selectedMethod?.requiresReference ?? false)) ...[
                const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              AppText(
                MoneyFormatter.format(state.totalInCents),
                textAlign: TextAlign.end,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: referenceController,
                builder: (context, reference, _) {
                  return AppButton(
                    icon: Icons.payments_outlined,
                    label: l10n.checkoutAction,
                    onPressed: _canCheckout(selectedMethod, reference.text)
                        ? () => _checkout(context, selectedMethod)
                        : null,
                  );
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                icon: Icons.delete_outline,
                label: l10n.clearCartAction,
                onPressed: state.cartLines.isEmpty
                    ? null
                    : () => unawaited(_clearCart(context)),
                primary: false,
              ),
              if (state.lastCompletedSale != null) ...[
                const SizedBox(height: 12),
                AppText(
                  l10n.checkoutSuccessTitle,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  bool _canCheckout(PaymentMethod? selectedMethod, String reference) {
    if (state.cartLines.isEmpty) return false;
    if (state.hasSplitAccounts) return _canCheckoutSplitAccounts();
    if (selectedMethod == null) return false;
    if (!selectedMethod.requiresReference) return true;

    return reference.trim().isNotEmpty;
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

class _CartLines extends StatelessWidget {
  const _CartLines({required this.lines});

  final List<PosCartLine> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (lines.isEmpty) {
      return AppEmptyState(
        icon: Icons.shopping_cart_outlined,
        message: l10n.cartEmptyMessage,
        title: l10n.cartTitle,
      );
    }

    return AppListSection(
      children: [
        for (final line in lines)
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => unawaited(_removeLine(context, line)),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  '${line.quantity} x '
                  '${MoneyFormatter.format(line.product.priceInCents)}',
                  variant: AppTextVariant.label,
                ),
                if (line.selectedOptionsLabel.isNotEmpty)
                  AppText(
                    line.selectedOptionsLabel,
                    maxLines: 2,
                    variant: AppTextVariant.label,
                  ),
              ],
            ),
            title: AppText(line.product.name),
            trailing: SizedBox(
              width: 80,
              child: AppText(
                MoneyFormatter.format(line.totalInCents),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                variant: AppTextVariant.label,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _removeLine(BuildContext context, PosCartLine line) async {
    final confirmed = await confirmRemovePosLine(context, line: line);
    if (!confirmed || !context.mounted) return;
    context.read<PosBloc>().add(PosProductRemoved(line.lineKey));
  }
}

class _TableSelector extends StatelessWidget {
  const _TableSelector({
    required this.selectedTableId,
    required this.tables,
  });

  final String? selectedTableId;
  final List<RestaurantTable> tables;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DropdownButtonFormField<String?>(
      decoration: InputDecoration(labelText: l10n.tableField),
      initialValue: selectedTableId,
      items: [
        DropdownMenuItem<String?>(
          child: AppText(l10n.noTableOption),
        ),
        for (final table in tables)
          DropdownMenuItem<String?>(
            value: table.id,
            child: AppText(table.name),
          ),
      ],
      onChanged: (value) {
        context.read<PosBloc>().add(PosTableSelected(value));
      },
    );
  }
}
