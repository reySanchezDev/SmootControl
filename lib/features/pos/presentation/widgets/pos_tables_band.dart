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

part 'pos_tables_band_button_part.dart';
part 'pos_tables_band_entry_part.dart';

/// Returns a copy where the dragged table swaps position with the target.
@visibleForTesting
List<String> swapPosTablesForDrop({
  required String draggedTableId,
  required List<String> tableIds,
  required String targetTableId,
}) {
  final fromIndex = tableIds.indexOf(draggedTableId);
  final toIndex = tableIds.indexOf(targetTableId);
  if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex) return tableIds;

  final reordered = [...tableIds];
  reordered[fromIndex] = tableIds[toIndex];
  reordered[toIndex] = draggedTableId;
  return reordered;
}

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
    final physicalTableIds = _orderedPhysicalTables()
        .map((table) => table.id)
        .toList();

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
                physicalTableIds: physicalTableIds,
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
                physicalTableIds: physicalTableIds,
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
    final entries = <_TableBandEntry>[];
    for (final table in _orderedPhysicalTables()) {
      entries.add(
        _TableBandEntry.table(table, occupied: _isOccupied(table.id)),
      );
      final accounts =
          state.splitAccountsByTable[table.id] ?? const <AccountSplitDraft>[];
      for (final account in accounts) {
        entries.add(_TableBandEntry.account(table.id, account));
      }
    }
    return entries;
  }

  List<RestaurantTable> _orderedPhysicalTables() {
    return [...state.tables]..sort((first, second) {
      final firstOrder = state.tableOrderByTableId[first.id];
      final secondOrder = state.tableOrderByTableId[second.id];
      if (firstOrder != null && secondOrder != null) {
        final order = firstOrder.compareTo(secondOrder);
        if (order != 0) return order;
      }
      if (firstOrder != null) return -1;
      if (secondOrder != null) return 1;
      return _compareTableNames(first, second);
    });
  }

  bool _isOccupied(String tableId) {
    final hasCart = state.cartLinesByTable[tableId]?.isNotEmpty ?? false;
    final hasSplitAccounts =
        state.splitAccountsByTable[tableId]?.isNotEmpty ?? false;
    final tableStatus = _tableById(tableId)?.status;
    return hasCart ||
        hasSplitAccounts ||
        tableStatus == RestaurantTableStatus.occupied;
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
