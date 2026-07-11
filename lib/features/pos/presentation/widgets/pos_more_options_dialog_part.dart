part of 'pos_more_options_panel.dart';

mixin _PosMoreOptionsDialogMixin on StatelessWidget {
  PosReady get state;
  bool get compactOperationalMode;
  String? get paymentParentKey;
  ValueChanged<String?>? get onPaymentParentChanged;
  List<SalesType> get activeSalesTypes;
  Future<void> handleMoreOptionAction(
    BuildContext context,
    _MoreOptionAction? action,
  );
  PosBloc? maybePosBloc(BuildContext context);

  Future<void> _openMoreOptions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    var dialogPaymentParentKey = paymentParentKey;
    var selectedSalesTypeId = state.selectedSalesType?.id;
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
                          if (activeSalesTypes.isNotEmpty) ...[
                            const _CompactSectionTitle(label: 'Tipo de venta'),
                            SizedBox(
                              height: 58,
                              child: _CompactSalesTypeSelector(
                                selectedSalesTypeId: selectedSalesTypeId,
                                state: state,
                                onSelected: (salesTypeId) {
                                  setDialogState(() {
                                    selectedSalesTypeId = salesTypeId;
                                  });
                                  context.read<PosBloc>().add(
                                    PosSalesTypeSelected(salesTypeId),
                                  );
                                },
                              ),
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
                          label: 'Consumo personal',
                          tone: _MoreOptionButtonTone.neutral,
                          onPressed: () => Navigator.of(dialogContext).pop(
                            _MoreOptionAction.staffConsumption,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _MoreOptionButton(
                          label: 'Adelanto salario',
                          tone: _MoreOptionButtonTone.neutral,
                          onPressed: () => Navigator.of(dialogContext).pop(
                            _MoreOptionAction.salaryAdvance,
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
        final posBloc = maybePosBloc(context);
        if (posBloc == null) return dialog;
        return BlocProvider.value(
          value: posBloc,
          child: dialog,
        );
      },
    );

    if (!context.mounted) return;
    await handleMoreOptionAction(context, action);
  }
}
