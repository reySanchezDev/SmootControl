part of 'pos_more_options_panel.dart';

mixin _PosMoreOptionsActionsMixin on StatelessWidget {
  PosReady get state;
  Future<void> registerSalaryAdvance(BuildContext context);
  Future<void> registerStaffConsumption(BuildContext context);

  Future<void> handleMoreOptionAction(
    BuildContext context,
    _MoreOptionAction? action,
  ) async {
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

    if (action == _MoreOptionAction.staffConsumption && context.mounted) {
      await registerStaffConsumption(context);
    }

    if (action == _MoreOptionAction.salaryAdvance && context.mounted) {
      await registerSalaryAdvance(context);
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

  PosBloc? maybePosBloc(BuildContext context) {
    try {
      return context.read<PosBloc>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<SalesType> get activeSalesTypes {
    return state.salesTypes.where((type) => type.isActive).toList()..sort(
      (first, second) => first.displayOrder.compareTo(second.displayOrder),
    );
  }
}
