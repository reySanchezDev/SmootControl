import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_dialog.dart';
import 'package:smoo_control/core/theme/app_semantic_colors.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Dynamic table selector band for tablet POS.
class PosTablesBand extends StatelessWidget {
  /// Creates the table band.
  const PosTablesBand({
    required this.state,
    this.onEntrySelected,
    super.key,
  });

  /// Current POS state.
  final PosReady state;

  /// Called after the operator selects a table or split account.
  final VoidCallback? onEntrySelected;

  @override
  Widget build(BuildContext context) {
    if (state.tables.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: AppText(
          l10n.emptyTablesMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          variant: AppTextVariant.label,
        ),
      );
    }

    final entries = _orderedEntries();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          final maxColumns =
              (constraints.maxWidth /
                      (constraints.maxWidth < 420 ? 132.0 : 150.0))
                  .floor()
                  .clamp(1, entries.length);
          final rows = (entries.length / maxColumns).ceil();
          const padding = 4.0;
          const spacing = 4.0;
          final tileWidth =
              (constraints.maxWidth -
                  padding * 2 -
                  spacing * (maxColumns - 1)) /
              maxColumns;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight - padding * 2 - spacing * (rows - 1)
              : rows * 76.0;
          final tileHeight = (availableHeight / rows).clamp(70.0, 170.0);
          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              childAspectRatio: tileWidth / tileHeight,
              crossAxisCount: maxColumns,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              return _TableEntryButton(
                entry: entries[index],
                onEntrySelected: onEntrySelected,
                state: state,
                onRename: _renameTable,
              );
            },
            itemCount: entries.length,
            physics: const NeverScrollableScrollPhysics(),
          );
        }

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 150,
              child: _TableEntryButton(
                entry: entries[index],
                onEntrySelected: onEntrySelected,
                state: state,
                onRename: _renameTable,
              ),
            );
          },
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
        );
      },
    );
  }

  List<_TableBandEntry> _orderedEntries() {
    final byId = {
      for (final table in state.tables) table.id: table,
    };
    final entries = <_TableBandEntry>[];
    final tableIds = {
      ...state.cartLinesByTable.keys,
      ...state.splitAccountsByTable.keys,
    };
    for (final tableId in tableIds) {
      if (!_isOccupied(tableId)) continue;
      final table = byId[tableId];
      if (table == null) continue;
      entries.add(_TableBandEntry.table(table, occupied: true));
      final accounts =
          state.splitAccountsByTable[table.id] ?? const <AccountSplitDraft>[];
      for (final account in accounts) {
        entries.add(_TableBandEntry.account(table.id, account));
      }
    }

    final occupiedIds = entries.map((entry) => entry.tableId).toSet();
    final free =
        state.tables.where((table) => !occupiedIds.contains(table.id)).toList()
          ..sort(_compareTableNames);

    return [
      ...entries,
      for (final table in free) _TableBandEntry.table(table),
    ];
  }

  bool _isOccupied(String tableId) {
    final hasCart = state.cartLinesByTable[tableId]?.isNotEmpty ?? false;
    final hasSplitAccounts =
        state.splitAccountsByTable[tableId]?.isNotEmpty ?? false;
    return hasCart || hasSplitAccounts;
  }

  int _compareTableNames(RestaurantTable first, RestaurantTable second) {
    final firstNumber = _firstNumber(first.name);
    final secondNumber = _firstNumber(second.name);
    if (firstNumber != null && secondNumber != null) {
      final numberOrder = firstNumber.compareTo(secondNumber);
      if (numberOrder != 0) return numberOrder;
    }
    return first.name.compareTo(second.name);
  }

  int? _firstNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  Future<void> _renameTable(BuildContext context, String tableId) async {
    final l10n = AppLocalizations.of(context);
    final table = _tableById(tableId);
    if (table == null) return;

    final value = await showTouchTextKeyboardDialog(
      context: context,
      hintText: table.name,
      initialValue: table.displayName ?? '',
      label: l10n.tableDisplayNameField,
      title: l10n.renameTableTitle,
    );
    if (value == null || !context.mounted) return;

    context.read<PosBloc>().add(
      PosTableDisplayNameChanged(
        tableId: tableId,
        displayName: value,
      ),
    );
  }

  RestaurantTable? _tableById(String tableId) {
    for (final table in state.tables) {
      if (table.id == tableId) return table;
    }
    return null;
  }
}

class _TableEntryButton extends StatelessWidget {
  const _TableEntryButton({
    required this.entry,
    required this.onRename,
    required this.state,
    this.onEntrySelected,
  });

  final _TableBandEntry entry;
  final VoidCallback? onEntrySelected;
  final Future<void> Function(BuildContext context, String tableId) onRename;
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    return _TableButton(
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

class _TableButton extends StatelessWidget {
  const _TableButton({
    required this.indicator,
    required this.isOccupied,
    required this.isSelected,
    required this.label,
    required this.onRename,
    required this.onPressed,
  });

  final String? indicator;
  final bool isOccupied;
  final bool isSelected;
  final String label;
  final VoidCallback? onRename;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;
    final background = _backgroundColor(colorScheme, semanticColors);
    final foreground = isSelected || isOccupied
        ? semanticColors.tableOnStatus
        : colorScheme.onSurface;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onLongPress: onRename,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        variant: AppTextVariant.label,
                      ),
                      if (isOccupied) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: semanticColors.tableBadgeBackground,
                          ),
                          child: AppText(
                            indicator ?? l10n.tableOccupiedLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: semanticColors.tableOnStatus,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            variant: AppTextVariant.label,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onRename != null && isSelected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      iconSize: 16,
                      onPressed: onRename,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        height: 28,
                        width: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _backgroundColor(
    ColorScheme colorScheme,
    AppSemanticColors semanticColors,
  ) {
    if (isSelected) return semanticColors.tableSelectedBackground;
    if (isOccupied) return semanticColors.tableOccupiedBackground;
    return colorScheme.surface;
  }
}
