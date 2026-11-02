import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/design_system/confirm_deactivate_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_bloc.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_event.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_state.dart';
import 'package:smoo_control/features/tables/presentation/widgets/create_table_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Restaurant tables management page.
class TablesPage extends StatelessWidget {
  /// Creates the tables page.
  const TablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<TablesBloc>()..add(const TablesLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          title: l10n.moduleTables,
          body: BlocBuilder<TablesBloc, TablesState>(
            builder: (context, state) {
              return switch (state) {
                TablesInitial() || TablesLoading() => const AppLoadingPage(),
                TablesFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleTables,
                ),
                TablesLoaded(:final tables) =>
                  BackofficeCollectionView<RestaurantTable>(
                    items: tables,
                    onCreate: () => _openCreateDialog(context),
                    rowKey: (table) => table.id,
                    rowLabel: (table) => table.name,
                    selectionActions: [
                      BackofficeSelectionAction(
                        label: l10n.editAction,
                        icon: Icons.edit_outlined,
                        onPressed: (table) =>
                            _openEditDialog(context, table),
                      ),
                      BackofficeSelectionAction(
                        label: l10n.deactivateAction,
                        icon: Icons.toggle_off_outlined,
                        enabledWhen: (table) => table.isActive,
                        onPressed: (table) =>
                            _deactivateTable(context, table),
                      ),
                    ],
                    searchLabel: 'Buscar mesa o estado',
                    searchTextFor: (table) =>
                        '${table.name} ${_statusLabel(l10n, table)}',
                    emptyTitle: l10n.emptySearchTitle,
                    emptyMessage: l10n.emptySearchMessage,
                    compactBuilder: (context, table) => _TableTile(
                      table: table,
                      onDeactivate: () => _deactivateTable(context, table),
                      onEdit: () => _openEditDialog(context, table),
                    ),
                    columns: [
                      BackofficeListColumn(
                        label: 'Mesa',
                        width: 420,
                        compare: (a, b) => a.name.compareTo(b.name),
                        cell: (_, table) => Text(table.name, softWrap: true),
                      ),
                      BackofficeListColumn(
                        label: 'Estado',
                        width: 240,
                        alignment: Alignment.center,
                        compare: (a, b) => _statusLabel(l10n, a)
                            .compareTo(_statusLabel(l10n, b)),
                        cell: (_, table) => Text(_statusLabel(l10n, table)),
                      ),
                    ],
                  ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final table = await showDialog<RestaurantTable>(
      context: context,
      builder: (_) => const CreateTableDialog(),
    );

    if (table != null && context.mounted) {
      context.read<TablesBloc>().add(TableSaved(table));
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    RestaurantTable table,
  ) async {
    final updated = await showDialog<RestaurantTable>(
      context: context,
      builder: (_) => CreateTableDialog(table: table),
    );

    if (updated != null && context.mounted) {
      context.read<TablesBloc>().add(TableSaved(updated));
    }
  }

  Future<void> _deactivateTable(
    BuildContext context,
    RestaurantTable table,
  ) async {
    final confirmed = await confirmDeactivateCatalogItem(
      context,
      name: table.name,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    context.read<TablesBloc>().add(
      TableSaved(
        RestaurantTable(
          id: table.id,
          name: table.name,
          status: RestaurantTableStatus.disabled,
          isActive: false,
        ),
      ),
    );
  }
}

String _statusLabel(
  AppLocalizations l10n,
  RestaurantTable table,
) {
  return switch (table.status) {
    RestaurantTableStatus.available => l10n.tableStatusAvailable,
    RestaurantTableStatus.occupied => l10n.tableStatusOccupied,
    RestaurantTableStatus.disabled => l10n.tableStatusDisabled,
  };
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.onDeactivate,
    required this.onEdit,
    required this.table,
  });

  final VoidCallback onDeactivate;
  final VoidCallback onEdit;
  final RestaurantTable table;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return ListTile(
          leading: const Icon(Icons.table_restaurant_outlined),
          subtitle: AppText(
            _statusLabel(l10n, table),
            variant: AppTextVariant.label,
          ),
          title: AppText(
            table.name,
          ),
          trailing: AppTileActions(
            compact: compact,
            actions: [
              if (table.isActive)
                AppTileAction(
                  color: Theme.of(context).colorScheme.error,
                  icon: Icons.delete_outline,
                  label: l10n.deactivateAction,
                  onPressed: onDeactivate,
                ),
              AppTileAction(
                icon: Icons.edit_outlined,
                label: l10n.editAction,
                onPressed: onEdit,
              ),
            ],
          ),
        );
      },
    );
  }
}
