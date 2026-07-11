part of 'pos_tables_band.dart';

class _TableEntryButton extends StatelessWidget {
  const _TableEntryButton({
    required this.entry,
    required this.onRename,
    required this.physicalTableIds,
    required this.state,
    this.onEntrySelected,
  });

  final _TableBandEntry entry;
  final VoidCallback? onEntrySelected;
  final List<String> physicalTableIds;
  final Future<void> Function(BuildContext context, String tableId) onRename;
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final button = _TableButton(
      indicator: entry.indicator,
      isOccupied: entry.isOccupied,
      isSelected: entry.isSelected(
        tableId: state.selectedTableId,
        splitAccountId: state.selectedSplitAccountId,
      ),
      label: entry.label,
      onRename: entry.isAccount ? null : () => onRename(context, entry.tableId),
      onPressed: () {
        final bloc = context.read<PosBloc>();
        if (entry.accountId == null) {
          bloc.add(PosTableSelected(entry.tableId));
        } else {
          bloc.add(
            PosSplitAccountSelected(
              tableId: entry.tableId,
              accountId: entry.accountId!,
            ),
          );
        }
        onEntrySelected?.call();
      },
    );
    if (entry.isAccount || physicalTableIds.length < 2) return button;

    return DragTarget<String>(
      onAcceptWithDetails: (details) => _moveTable(context, details.data),
      onWillAcceptWithDetails: (details) => details.data != entry.tableId,
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return LongPressDraggable<String>(
          data: entry.tableId,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _TableDragFeedback(label: entry.label),
          maxSimultaneousDrags: 1,
          childWhenDragging: Opacity(opacity: .42, child: button),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: highlighted
                ? BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: button,
          ),
        );
      },
    );
  }

  void _moveTable(BuildContext context, String draggedTableId) {
    final reordered = swapPosTablesForDrop(
      draggedTableId: draggedTableId,
      tableIds: physicalTableIds,
      targetTableId: entry.tableId,
    );
    if (identical(reordered, physicalTableIds)) return;
    context.read<PosBloc>().add(PosTablesReordered(tableIds: reordered));
  }
}

class _TableBandEntry {
  const _TableBandEntry({
    required this.tableId,
    required this.accountId,
    required this.label,
    required this.isOccupied,
    required this.isAccount,
  });

  factory _TableBandEntry.table(
    RestaurantTable table, {
    bool occupied = false,
  }) {
    return _TableBandEntry(
      tableId: table.id,
      accountId: null,
      label: table.operationalName,
      isOccupied: occupied,
      isAccount: false,
    );
  }

  factory _TableBandEntry.account(
    String tableId,
    AccountSplitDraft account,
  ) {
    return _TableBandEntry(
      tableId: tableId,
      accountId: account.id,
      label: account.name,
      isOccupied: true,
      isAccount: true,
    );
  }

  final String tableId;
  final String? accountId;
  final String label;
  final bool isOccupied;
  final bool isAccount;

  String? get indicator => isAccount ? 'Cuenta' : null;

  bool isSelected({
    required String? tableId,
    required String? splitAccountId,
  }) {
    if (isAccount) return splitAccountId == accountId;
    return splitAccountId == null && tableId == this.tableId;
  }
}
