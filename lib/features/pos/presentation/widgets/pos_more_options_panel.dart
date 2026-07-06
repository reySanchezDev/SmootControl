import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/responsive_touch_dialog_frame.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/cash_register/presentation/widgets/close_cash_register_dialog.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_cash_transactions_page.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_modifier_availability_page.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_register_expense_page.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_danger_confirmation.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_section.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_dialog_launcher.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';
import 'package:smoo_control/features/sync/domain/services/i_catalog_pull_service.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Middle bottom POS section reserved for secondary actions.
class PosMoreOptionsPanel extends StatelessWidget {
  /// Creates the panel.
  const PosMoreOptionsPanel({
    required this.state,
    this.buttonOnly = false,
    this.compactOperationalMode = false,
    this.onPaymentParentChanged,
    this.paymentParentKey,
    super.key,
  });

  /// Current POS state.
  final PosReady state;

  /// Whether to render only the tactile button without the grid wrapper.
  final bool buttonOnly;

  /// Whether phone layouts should move POS actions and payments inside.
  final bool compactOperationalMode;

  /// Current selected payment parent for compact phone payment navigation.
  final String? paymentParentKey;

  /// Payment navigation change callback for compact phone payment navigation.
  final ValueChanged<String?>? onPaymentParentChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final button = PosTouchButton(
      icon: Icons.more_horiz,
      label: l10n.moreOptionsAction,
      onPressed: () => _openMoreOptions(context),
      tone: PosButtonTone.neutral,
    );

    if (buttonOnly) return button;

    return PosTouchGrid(
      minTileHeight: 52,
      minTileWidth: 130,
      children: [button],
    );
  }

  Future<void> _openMoreOptions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    var dialogPaymentParentKey = paymentParentKey;
    final action = await showDialog<_MoreOptionAction>(
      context: context,
      builder: (dialogContext) {
        final dialog = StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Stack(
              children: [
                ResponsiveTouchDialogFrame(
                  maxWidth: compactOperationalMode ? 540 : 420,
                  title: AppText(
                    l10n.moreOptionsAction,
                    variant: AppTextVariant.titleMedium,
                  ),
                  content: Padding(
                    padding: EdgeInsets.only(
                      bottom: compactOperationalMode ? 74 : 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (compactOperationalMode) ...[
                          if (_activeSalesTypes.isNotEmpty) ...[
                            const _CompactSectionTitle(label: 'Tipo de venta'),
                            SizedBox(
                              height: 58,
                              child: _CompactSalesTypeSelector(state: state),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _CompactSectionTitle(label: l10n.paymentMethodField),
                          SizedBox(
                            height: 168,
                            child: PosPaymentSection(
                              onPaymentCompleted: () {
                                Navigator.of(dialogContext).pop();
                              },
                              onPaymentParentChanged: (parentKey) {
                                setDialogState(() {
                                  dialogPaymentParentKey = parentKey;
                                });
                                onPaymentParentChanged?.call(parentKey);
                              },
                              paymentParentKey: dialogPaymentParentKey,
                              state: state,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _CompactSectionTitle(label: l10n.splitAccountsAction),
                          _MoreOptionButton(
                            label: l10n.splitAccountsAction,
                            tone: _MoreOptionButtonTone.neutral,
                            onPressed: () => Navigator.of(dialogContext).pop(
                              _MoreOptionAction.splitAccounts,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MoreOptionButton(
                            label: l10n.clearCartAction,
                            tone: _MoreOptionButtonTone.danger,
                            onPressed: () => Navigator.of(dialogContext).pop(
                              _MoreOptionAction.clearCart,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _CompactSectionTitle(label: l10n.moreOptionsAction),
                        ],
                        _MoreOptionButton(
                          label: 'Modificadores Disponibles',
                          tone: _MoreOptionButtonTone.neutral,
                          onPressed: () => Navigator.of(dialogContext).pop(
                            _MoreOptionAction.modifierAvailability,
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
                          label: 'Sincronizar datos',
                          tone: _MoreOptionButtonTone.neutral,
                          onPressed: () => Navigator.of(dialogContext).pop(
                            _MoreOptionAction.syncData,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _MoreOptionButton(
                          label: l10n.posViewTransactionsAction,
                          tone: _MoreOptionButtonTone.neutral,
                          onPressed: () => Navigator.of(dialogContext).pop(
                            _MoreOptionAction.viewTransactions,
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
                if (compactOperationalMode)
                  Positioned(
                    right: 24,
                    bottom: 24,
                    child: _FloatingMoreOptionsCloseButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
              ],
            );
          },
        );
        if (!compactOperationalMode) return dialog;
        final posBloc = _maybePosBloc(context);
        if (posBloc == null) return dialog;
        return BlocProvider.value(
          value: posBloc,
          child: dialog,
        );
      },
    );

    if (action == _MoreOptionAction.splitAccounts && context.mounted) {
      _validateAndOpenSplitDialog(context);
    }

    if (action == _MoreOptionAction.clearCart && context.mounted) {
      await _clearCart(context);
    }

    if (action == _MoreOptionAction.closeCashRegister && context.mounted) {
      await _closeCashRegister(context);
    }

    if (action == _MoreOptionAction.viewTransactions && context.mounted) {
      await _viewTransactions(context);
    }

    if (action == _MoreOptionAction.registerExpense && context.mounted) {
      await _registerExpense(context);
    }

    if (action == _MoreOptionAction.modifierAvailability && context.mounted) {
      await _modifierAvailability(context);
    }

    if (action == _MoreOptionAction.syncData && context.mounted) {
      await _syncData(context);
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

  Future<void> _clearCart(BuildContext context) async {
    if (state.cartLines.isEmpty) return;
    final confirmed = await confirmClearPosTicket(context);
    if (!confirmed || !context.mounted) return;
    context.read<PosBloc>().add(const PosCartCleared());
  }

  void _validateAndOpenSplitDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.selectedTableId == null || state.cartLines.isEmpty) return;
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

    unawaited(
      showPosSplitAccountsDialog(
        context: context,
        state: state,
      ),
    );
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

  Future<void> _modifierAvailability(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PosModifierAvailabilityPage(),
      ),
    );

    if (!context.mounted) return;

    final result = await serviceLocator<IModifiersRepository>().getCatalog();
    if (!context.mounted) return;

    switch (result) {
      case AppSuccess(:final value):
        context.read<PosBloc>().add(PosModifierCatalogRefreshed(value));
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }

  Future<void> _syncData(BuildContext context) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SyncDataProgressDialog(),
      ),
    );

    try {
      final pushResult = await serviceLocator<SyncSchedulerService>().runNow();
      if (pushResult case AppFailureResult(:final error)) {
        throw StateError(error.message);
      }

      final summary = await serviceLocator<ICatalogPullService>()
          .pullOperationalCatalog();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      context.read<PosBloc>().add(const PosStarted());

      final readinessMessage = summary.isReadyForPos
          ? 'El POS quedo listo para vender.'
          : 'Atencion: el POS aun no esta listo para vender. '
                'Falta: ${summary.missingPosRequirements.join(', ')}.';
      await showAppMessageDialog(
        context: context,
        message:
            'Datos sincronizados correctamente. '
            'Registros actualizados: ${summary.total}. '
            '$readinessMessage',
        title: 'Sincronizar datos',
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showAppMessageDialog(
        context: context,
        message: 'No se pudieron sincronizar los datos. $error',
        title: 'Sincronizar datos',
      );
    }
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

  PosBloc? _maybePosBloc(BuildContext context) {
    try {
      return context.read<PosBloc>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<SalesType> get _activeSalesTypes {
    return state.salesTypes.where((type) => type.isActive).toList()..sort(
      (first, second) => first.displayOrder.compareTo(second.displayOrder),
    );
  }
}

class _CompactSalesTypeSelector extends StatelessWidget {
  const _CompactSalesTypeSelector({required this.state});

  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final activeTypes = state.salesTypes.where((type) => type.isActive).toList()
      ..sort(
        (first, second) => first.displayOrder.compareTo(second.displayOrder),
      );
    if (activeTypes.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (final type in activeTypes) ...[
          Expanded(
            child: _CompactSalesTypeButton(
              label: _mobileSalesTypeLabel(type),
              selected: type.id == state.selectedSalesType?.id,
              onPressed: () {
                context.read<PosBloc>().add(PosSalesTypeSelected(type.id));
              },
            ),
          ),
          if (type != activeTypes.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _CompactSalesTypeButton extends StatelessWidget {
  const _CompactSalesTypeButton({
    required this.label,
    required this.onPressed,
    required this.selected,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        foregroundColor: selected
            ? colorScheme.onPrimary
            : colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: selected ? null : onPressed,
      child: AppText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        variant: AppTextVariant.label,
      ),
    );
  }
}

String _mobileSalesTypeLabel(SalesType type) {
  final normalized = type.code.trim().toLowerCase();
  if (normalized == 'dine_in' || normalized == 'eat_here') return 'Aqui';
  if (normalized == 'to_go' || normalized == 'takeout') return 'GO';

  final name = type.name.trim().toLowerCase();
  if (name == 'comer aqui' || name == 'aqui') return 'Aqui';
  if (name == 'para llevar' || name == 'llevar') return 'GO';
  return type.name;
}

class _CompactSectionTitle extends StatelessWidget {
  const _CompactSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          variant: AppTextVariant.label,
        ),
      ),
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
          style: TextStyle(color: colors.foreground),
          textAlign: TextAlign.center,
          variant: AppTextVariant.label,
        ),
      ),
    );
  }
}

class _FloatingMoreOptionsCloseButton extends StatelessWidget {
  const _FloatingMoreOptionsCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      elevation: 6,
      shadowColor: colorScheme.error.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          width: 56,
          child: Icon(Icons.close, color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _SyncDataProgressDialog extends StatelessWidget {
  const _SyncDataProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveTouchDialogFrame(
      maxWidth: 360,
      title: AppText(
        'Sincronizar datos',
        variant: AppTextVariant.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          CircularProgressIndicator(),
          SizedBox(height: 18),
          AppText(
            'Actualizando catalogos del POS...',
            textAlign: TextAlign.center,
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}

enum _MoreOptionAction {
  clearCart,
  closeCashRegister,
  exit,
  modifierAvailability,
  registerExpense,
  splitAccounts,
  syncData,
  viewTransactions,
}

enum _MoreOptionButtonTone { danger, neutral }
