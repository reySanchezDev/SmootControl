import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_dialog.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Payment controls shown when a table has been split into accounts.
class PosSplitAccountPayments extends StatelessWidget {
  /// Creates split-account payment controls.
  const PosSplitAccountPayments({required this.state, super.key});

  /// Current POS ready state.
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          l10n.splitAccountPaymentsTitle,
          variant: AppTextVariant.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final account in state.splitAccounts) ...[
          _AccountPaymentFields(
            account: account,
            draftItems: state.splitDraftItems,
            methods: state.paymentMethods,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AccountPaymentFields extends StatelessWidget {
  const _AccountPaymentFields({
    required this.account,
    required this.draftItems,
    required this.methods,
  });

  final AccountSplitDraft account;
  final List<SaleItemDraft> draftItems;
  final List<PaymentMethod> methods;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final method = _methodById(account.paymentMethodId);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppText(
                  MoneyFormatter.format(_totalInCents),
                  variant: AppTextVariant.label,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l10n.paymentMethodField),
              initialValue: account.paymentMethodId,
              items: [
                for (final method in methods)
                  DropdownMenuItem(
                    value: method.id,
                    child: AppText(method.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                context.read<PosBloc>().add(
                  PosSplitAccountPaymentSelected(
                    accountId: account.id,
                    paymentMethodId: value,
                  ),
                );
              },
            ),
            if (method?.requiresReference ?? false) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: account.paymentReference,
                decoration: InputDecoration(
                  labelText: l10n.paymentReferenceField,
                ),
                onTap: () => _openReferenceKeyboard(context),
                readOnly: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  int get _totalInCents {
    final itemById = {for (final item in draftItems) item.id: item};
    return account.itemIds.fold(0, (total, itemId) {
      return total + (itemById[itemId]?.unitPriceInCents ?? 0);
    });
  }

  PaymentMethod? _methodById(String? methodId) {
    for (final method in methods) {
      if (method.id == methodId) return method;
    }

    return null;
  }

  Future<void> _openReferenceKeyboard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final value = await showTouchTextKeyboardDialog(
      context: context,
      initialValue: account.paymentReference ?? '',
      label: l10n.paymentReferenceField,
      title: l10n.paymentReferenceField,
    );
    if (value == null || !context.mounted) return;
    context.read<PosBloc>().add(
      PosSplitAccountReferenceChanged(
        accountId: account.id,
        reference: value,
      ),
    );
  }
}
