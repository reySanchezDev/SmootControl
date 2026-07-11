part of 'pos_ready_view.dart';

class _MobileTablesLauncher extends StatelessWidget {
  const _MobileTablesLauncher({
    required this.catalogMode,
    required this.onCatalogModeToggled,
    required this.state,
  });

  static const double _sideButtonWidth = 66;
  static const double _horizontalGap = 8;

  final bool catalogMode;
  final VoidCallback onCatalogModeToggled;
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final options = _orderedTableOptions();
    final selected = _selectedTableOption(options);
    final selectedLabel = selected?.label ?? _selectedTableLabel();
    final selectedOccupied = selected?.isOccupied ?? false;
    final canSwipe = options.length > 1;
    final selectedBackground = selectedLabel == null
        ? colorScheme.surfaceContainerHighest
        : selectedOccupied
        ? AppPalette.tableOccupiedWine
        : AppPalette.tableAvailableSoft;
    final selectedForeground = selectedLabel == null || !selectedOccupied
        ? AppPalette.textPrimary
        : AppPalette.surface;
    final selectedSecondary = selectedLabel == null || !selectedOccupied
        ? AppPalette.textSecondary
        : AppPalette.surface.withValues(alpha: .86);
    final selectedBorder = selectedLabel == null
        ? colorScheme.outlineVariant
        : selectedOccupied
        ? AppPalette.tableOccupiedWine
        : AppPalette.success.withValues(alpha: .58);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: !canSwipe
          ? null
          : (details) => _handleHorizontalSwipe(context, options, details),
      child: Material(
        key: const ValueKey('pos-mobile-table-launcher-panel'),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _sideButtonWidth,
                child: _MobileCatalogModeButton(
                  active: catalogMode,
                  onPressed: onCatalogModeToggled,
                ),
              ),
              const SizedBox(width: _horizontalGap),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedBackground,
                    border: Border.all(color: selectedBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      reverseDuration: const Duration(milliseconds: 140),
                      transitionBuilder: (child, animation) {
                        final offsetAnimation =
                            Tween<Offset>(
                              begin: const Offset(.12, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            );
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: _MobileTableSelectionLabel(
                        key: ValueKey(selected?.id ?? selectedLabel ?? 'none'),
                        primaryColor: selectedForeground,
                        secondaryColor: selectedSecondary,
                        selectedLabel: selectedLabel,
                        totalLabel: MoneyFormatter.format(state.totalInCents),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _horizontalGap),
              SizedBox(
                width: _sideButtonWidth,
                child: _MobileTablesButton(
                  tooltip: l10n.moduleTables,
                  onPressed: state.tables.isEmpty
                      ? null
                      : () => _openTablesSheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleHorizontalSwipe(
    BuildContext context,
    List<_MobileTableOption> options,
    DragEndDetails details,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;

    final selectedIndex = _selectedTableIndex(options);
    final direction = velocity < 0 ? 1 : -1;
    final nextIndex = (selectedIndex + direction) % options.length;
    final normalizedIndex = nextIndex < 0 ? options.length - 1 : nextIndex;
    context.read<PosBloc>().add(PosTableSelected(options[normalizedIndex].id));
  }

  int _selectedTableIndex(List<_MobileTableOption> options) {
    final tableId = state.selectedTableId;
    if (tableId == null) return 0;

    final index = options.indexWhere((option) => option.id == tableId);
    if (index < 0) return 0;
    return index;
  }

  _MobileTableOption? _selectedTableOption(List<_MobileTableOption> options) {
    if (options.isEmpty) return null;
    return options[_selectedTableIndex(options)];
  }

  List<_MobileTableOption> _orderedTableOptions() {
    final orderedTables = orderMobilePosTables(
      cartLinesByTable: state.cartLinesByTable,
      splitAccountsByTable: state.splitAccountsByTable,
      tableOrderByTableId: state.tableOrderByTableId,
      tables: state.tables,
    );
    return [
      for (final table in orderedTables)
        _MobileTableOption(
          id: table.id,
          isOccupied: _isMobileTableOccupied(
            cartLinesByTable: state.cartLinesByTable,
            splitAccountsByTable: state.splitAccountsByTable,
            table: table,
          ),
          label: table.operationalName,
        ),
    ];
  }

  String? _selectedTableLabel() {
    final tableId = state.selectedTableId;
    if (tableId == null) return null;

    final splitAccountId = state.selectedSplitAccountId;
    if (splitAccountId != null) {
      final accounts = state.splitAccountsByTable[tableId] ?? const [];
      for (final account in accounts) {
        if (account.id == splitAccountId) return account.name;
      }
    }

    for (final table in state.tables) {
      if (table.id == tableId) return table.operationalName;
    }
    return null;
  }

  void _openTablesSheet(BuildContext context) {
    final bloc = _maybePosBloc(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          Widget sheet(PosReady ready) {
            return _MobileTablesSheet(
              onClose: () => Navigator.of(sheetContext).pop(),
              state: ready,
            );
          }

          if (bloc == null) return sheet(state);
          return BlocProvider.value(
            value: bloc,
            child: BlocBuilder<PosBloc, PosState>(
              buildWhen: (previous, current) => current is PosReady,
              builder: (context, blocState) {
                return sheet(blocState is PosReady ? blocState : state);
              },
            ),
          );
        },
      ),
    );
  }

  PosBloc? _maybePosBloc(BuildContext context) {
    try {
      return context.read<PosBloc>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
