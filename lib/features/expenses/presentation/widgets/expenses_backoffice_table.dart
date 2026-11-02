import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Desktop category browser; editing and deletion remain in the parent BLoC.
class ExpensesBackofficeTable extends StatelessWidget {
  /// Creates the expense category grid.
  const ExpensesBackofficeTable({
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    required this.onCreate,
    super.key,
  });

  /// Existing categories.
  final List<ExpenseCategory> categories;

  /// Opens editing for one record.
  final ValueChanged<ExpenseCategory> onEdit;

  /// Requests deletion via the existing confirmation path.
  final ValueChanged<ExpenseCategory> onDelete;

  /// Create a new expense category.
  final VoidCallback onCreate;

  String _parent(ExpenseCategory item) {
    for (final candidate in categories) {
      if (candidate.id == item.parentId) return candidate.name;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BackofficeCollectionView<ExpenseCategory>(
      items: categories,
      onCreate: onCreate,
      rowKey: (item) => item.id,
      rowLabel: (item) => item.name,
      selectionActions: [
        BackofficeSelectionAction(
          label: l10n.editAction,
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        BackofficeSelectionAction(
          label: l10n.deleteAction,
          icon: Icons.delete_outline,
          destructive: true,
          onPressed: onDelete,
        ),
      ],
      compactBuilder: (_, item) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.name, softWrap: true),
              Text(
                '${item.parentId == null ? 'Categoría' : 'Subcategoría'} · '
                '${_parent(item)}',
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
      searchLabel: 'Buscar categoría, subcategoría o estado',
      searchTextFor: (item) =>
          '${item.name} ${_parent(item)} '
          '${item.isActive ? l10n.activeStatus : l10n.inactiveStatus}',
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      columns: [
        BackofficeListColumn(
          label: 'Categoría',
          width: 300,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, item) => Text(item.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Tipo',
          width: 150,
          compare: (a, b) =>
              (a.parentId == null ? 0 : 1).compareTo(
                b.parentId == null ? 0 : 1,
              ),
          cell: (_, item) =>
              Text(item.parentId == null ? 'Categoría' : 'Subcategoría'),
        ),
        BackofficeListColumn(
          label: 'Categoría superior',
          width: 260,
          compare: (a, b) => _parent(a).compareTo(_parent(b)),
          cell: (_, item) => Text(_parent(item), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Cobertura',
          width: 170,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.includeInGrossProfitCoverage ? 1 : 0).compareTo(
                b.includeInGrossProfitCoverage ? 1 : 0,
              ),
          cell: (_, item) => Text(
            item.includeInGrossProfitCoverage
                ? l10n.expenseCategoryCoverageIncluded
                : l10n.expenseCategoryCoverageExcluded,
          ),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 120,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
          cell: (_, item) =>
              Text(item.isActive ? l10n.activeStatus : l10n.inactiveStatus),
        ),
      ],
    );
  }
}
