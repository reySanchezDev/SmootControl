import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/cash_register/presentation/widgets/close_cash_register_dialog.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_cash_transactions_page.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_register_expense_page.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Middle bottom POS section reserved for secondary actions.
class PosMoreOptionsPanel extends StatelessWidget {
  /// Creates the panel.
  const PosMoreOptionsPanel({required this.state, super.key});

  /// Current POS state.
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PosTouchGrid(
      minTileHeight: 52,
      minTileWidth: 130,
      children: [
        PosTouchButton(
          icon: Icons.more_horiz,
          label: l10n.moreOptionsAction,
          onPressed: () => _openMoreOptions(context),
          tone: PosButtonTone.neutral,
        ),
      ],
    );
  }

  Future<void> _openMoreOptions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final action = await showDialog<_MoreOptionAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.moreOptionsAction),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MoreOptionButton(
                label: l10n.posViewTransactionsAction,
                tone: _MoreOptionButtonTone.neutral,
                onPressed: () => Navigator.of(dialogContext).pop(
                  _MoreOptionAction.viewTransactions,
                ),
              ),
              const SizedBox(height: 12),
              _MoreOptionButton(
                label: l10n.posRegisterExpenseAction,
                tone: _MoreOptionButtonTone.neutral,
                onPressed: () => Navigator.of(dialogContext).pop(
                  _MoreOptionAction.registerExpense,
                ),
              ),
              const SizedBox(height: 12),
              _MoreOptionButton(
                label: l10n.posCloseCashRegisterAction,
                tone: _MoreOptionButtonTone.danger,
                onPressed: () => Navigator.of(dialogContext).pop(
                  _MoreOptionAction.closeCashRegister,
                ),
              ),
              const SizedBox(height: 12),
              _MoreOptionButton(
                label: l10n.posExitAction,
                tone: _MoreOptionButtonTone.neutral,
                onPressed: () => Navigator.of(dialogContext).pop(
                  _MoreOptionAction.exit,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == _MoreOptionAction.closeCashRegister && context.mounted) {
      await _closeCashRegister(context);
    }

    if (action == _MoreOptionAction.viewTransactions && context.mounted) {
      await _viewTransactions(context);
    }

    if (action == _MoreOptionAction.registerExpense && context.mounted) {
      await _registerExpense(context);
    }

    if (action == _MoreOptionAction.exit && context.mounted) {
      await _exitPos(context);
    }
  }

  Future<void> _closeCashRegister(BuildContext context) async {
    if (_hasPendingProducts) {
      await showAppMessageDialog(
        context: context,
        message: AppLocalizations.of(context).posCloseCashPendingCart,
      );
      return;
    }

    final draft = await showDialog<CloseCashRegisterDraft>(
      context: context,
      builder: (_) => const CloseCashRegisterDialog(),
    );

    if (draft != null && context.mounted) {
      context.read<PosBloc>().add(
        PosCashRegisterClosed(
          physicalClosingCashInCents: draft.physicalClosingCashInCents,
        ),
      );
    }
  }

  bool get _hasPendingProducts {
    return state.cartLines.isNotEmpty ||
        state.cartLinesByTable.values.any((lines) => lines.isNotEmpty);
  }

  Future<void> _viewTransactions(BuildContext context) async {
    final session = state.openCashRegisterSession;
    if (session == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PosCashTransactionsPage(
          cashRegisterSessionId: session.id,
        ),
      ),
    );
  }

  Future<void> _registerExpense(BuildContext context) async {
    final session = state.openCashRegisterSession;
    if (session == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PosRegisterExpensePage(
          cashRegisterSessionId: session.id,
        ),
      ),
    );
  }

  Future<void> _exitPos(BuildContext context) async {
    final isPosUser =
        serviceLocator<CurrentOperatorService>().session?.isPosUser ?? false;
    if (isPosUser) {
      context.read<AuthBloc>().add(const AuthSignOutRequested());
      return;
    }

    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (_) => false,
    );
  }
}

class _MoreOptionButton extends StatelessWidget {
  const _MoreOptionButton({
    required this.label,
    required this.onPressed,
    required this.tone,
  });

  final String label;
  final VoidCallback onPressed;
  final _MoreOptionButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = switch (tone) {
      _MoreOptionButtonTone.danger => (
        background: colorScheme.error,
        foreground: colorScheme.onError,
      ),
      _MoreOptionButtonTone.neutral => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurface,
      ),
    };

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onPressed,
        child: AppText(
          label,
          textAlign: TextAlign.center,
          variant: AppTextVariant.label,
        ),
      ),
    );
  }
}

enum _MoreOptionAction {
  closeCashRegister,
  exit,
  registerExpense,
  viewTransactions,
}

enum _MoreOptionButtonTone { danger, neutral }
