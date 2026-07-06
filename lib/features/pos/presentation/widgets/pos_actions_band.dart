import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_danger_confirmation.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_more_options_panel.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_flow.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_section.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_dialog_launcher.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Bottom POS band split into actions, options and payment methods.
class PosActionsBand extends StatelessWidget {
  /// Creates the bottom actions band.
  const PosActionsBand({
    required this.onPaymentParentChanged,
    required this.paymentParentKey,
    required this.state,
    super.key,
  });

  /// Current selected payment parent.
  final String? paymentParentKey;

  /// Current POS state.
  final PosReady state;

  /// Payment navigation change callback.
  final ValueChanged<String?> onPaymentParentChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paymentSection = PosPaymentSection(
          onPaymentParentChanged: onPaymentParentChanged,
          paymentParentKey: paymentParentKey,
          state: state,
        );
        if (constraints.maxWidth < 560) {
          return _MobilePaymentShortcutsBand(
            moreOptionsPanel: PosMoreOptionsPanel(
              buttonOnly: true,
              compactOperationalMode: true,
              onPaymentParentChanged: onPaymentParentChanged,
              paymentParentKey: paymentParentKey,
              state: state,
            ),
            state: state,
          );
        }

        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              Expanded(
                child: _ImportantActions(state: state),
              ),
              const Divider(height: 1),
              Expanded(
                child: PosMoreOptionsPanel(state: state),
              ),
              const Divider(height: 1),
              Expanded(child: paymentSection),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 4, child: _ImportantActions(state: state)),
            const VerticalDivider(width: 1),
            Expanded(flex: 4, child: PosMoreOptionsPanel(state: state)),
            const VerticalDivider(width: 1),
            Expanded(flex: 4, child: paymentSection),
          ],
        );
      },
    );
  }
}

class _MobilePaymentShortcutsBand extends StatelessWidget {
  const _MobilePaymentShortcutsBand({
    required this.moreOptionsPanel,
    required this.state,
  });

  final Widget moreOptionsPanel;
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final dollarMethod = _cashMethodForCurrency('USD');
    final cordobaMethod = _cashMethodForCurrency('NIO');

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _quickPaymentButton(context, dollarMethod)),
          const SizedBox(width: 4),
          Expanded(child: moreOptionsPanel),
          const SizedBox(width: 4),
          Expanded(child: _quickPaymentButton(context, cordobaMethod)),
        ],
      ),
    );
  }

  Widget _quickPaymentButton(BuildContext context, PaymentMethod? method) {
    return PosTouchButton(
      label: method?.name ?? '',
      onPressed: method == null || state.cartLines.isEmpty
          ? null
          : () => unawaited(
              startPosPaymentFlow(
                context: context,
                method: method,
                state: state,
              ),
            ),
      selected: method != null && state.selectedPaymentMethodId == method.id,
      tone: PosButtonTone.success,
    );
  }

  PaymentMethod? _cashMethodForCurrency(String currencyCode) {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final matches = state.paymentMethods.where((method) {
      final currency = method.currencyCode?.trim().toUpperCase();
      return method.isActive &&
          method.isPaymentTarget &&
          method.affectsCashRegister &&
          currency == normalizedCurrency;
    }).toList()..sort(_compareMethods);

    return matches.isEmpty ? null : matches.first;
  }

  int _compareMethods(PaymentMethod first, PaymentMethod second) {
    final order = first.displayOrder.compareTo(second.displayOrder);
    if (order != 0) return order;
    return first.name.compareTo(second.name);
  }
}

class _ImportantActions extends StatelessWidget {
  const _ImportantActions({required this.state});

  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PosTouchGrid(
      minTileHeight: 52,
      minTileWidth: 130,
      children: [
        PosTouchButton(
          icon: Icons.call_split,
          label: l10n.splitAccountsAction,
          onPressed: state.selectedTableId == null || state.cartLines.isEmpty
              ? null
              : () => _validateAndOpenSplitDialog(context),
          tone: PosButtonTone.neutral,
        ),
        PosTouchButton(
          label: l10n.clearCartAction,
          onPressed: state.cartLines.isEmpty
              ? null
              : () => unawaited(_clearCart(context)),
          tone: PosButtonTone.danger,
        ),
      ],
    );
  }

  Future<void> _clearCart(BuildContext context) async {
    final confirmed = await confirmClearPosTicket(context);
    if (!confirmed || !context.mounted) return;
    context.read<PosBloc>().add(const PosCartCleared());
  }

  void _validateAndOpenSplitDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.splitDraftItems.length <= 1) {
      unawaited(
        showAppMessageDialog(
          context: context,
          message: l10n.splitAccountsMinimumItemsError,
          title: l10n.splitAccountsAction,
        ),
      );
      return;
    }

    _openSplitDialog(context);
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
