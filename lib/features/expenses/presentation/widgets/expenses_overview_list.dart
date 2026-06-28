import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_list_section.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/utils/search_text.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Searchable list for expense category groups.
class ExpensesOverviewList extends StatefulWidget {
  /// Creates the expenses overview list.
  const ExpensesOverviewList({
    required this.categories,
    required this.onCategoryDelete,
    required this.onCategoryEdit,
    super.key,
  });

  /// Expense categories to render.
  final List<ExpenseCategory> categories;

  /// Deletes a category.
  final ValueChanged<ExpenseCategory> onCategoryDelete;

  /// Opens category edition.
  final ValueChanged<ExpenseCategory> onCategoryEdit;

  @override
  State<ExpensesOverviewList> createState() => _ExpensesOverviewListState();
}

class _ExpensesOverviewListState extends State<ExpensesOverviewList> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _filteredCategories(l10n);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AppSearchField(
            controller: _controller,
            label: l10n.searchField,
            onChanged: (value) => setState(() => _query = value),
            onClear: _clearSearch,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: categories.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.manage_search_outlined,
                    message: l10n.emptySearchMessage,
                    title: l10n.emptySearchTitle,
                  ),
                )
              : AppListSection(
                  children: [
                    _SectionTitle(l10n.expenseCategoriesSection),
                    for (final category in categories)
                      _ExpenseCategoryTile(
                        category: category,
                        level: _levelOf(category),
                        onDelete: () {
                          widget.onCategoryDelete(category);
                        },
                        onEdit: () {
                          widget.onCategoryEdit(category);
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  List<ExpenseCategory> _filteredCategories(AppLocalizations l10n) {
    return widget.categories.where((category) {
      final text = [
        category.name,
        _parentName(category),
        if (category.isActive) l10n.activeStatus else l10n.inactiveStatus,
      ].join(' ');
      return containsNormalizedSearch(text, _query);
    }).toList()..sort(_sortCategories);
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _query = '');
  }

  String _parentName(ExpenseCategory category) {
    final parentId = category.parentId;
    if (parentId == null) return '';
    for (final category in widget.categories) {
      if (category.id == parentId) return category.name;
    }
    return '';
  }

  int _levelOf(ExpenseCategory category) {
    return category.parentId == null ? 0 : 1;
  }

  int _sortCategories(ExpenseCategory first, ExpenseCategory second) {
    final firstRoot = first.parentId == null ? first.id : first.parentId!;
    final secondRoot = second.parentId == null ? second.id : second.parentId!;
    final rootComparison = _categoryName(firstRoot).compareTo(
      _categoryName(secondRoot),
    );
    if (rootComparison != 0) return rootComparison;
    if (first.parentId == null && second.parentId != null) return -1;
    if (first.parentId != null && second.parentId == null) return 1;
    return first.name.compareTo(second.name);
  }

  String _categoryName(String id) {
    for (final category in widget.categories) {
      if (category.id == id) return category.name;
    }
    return '';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: AppText(title, variant: AppTextVariant.titleMedium),
    );
  }
}

class _ExpenseCategoryTile extends StatelessWidget {
  const _ExpenseCategoryTile({
    required this.category,
    required this.level,
    required this.onDelete,
    required this.onEdit,
  });

  final ExpenseCategory category;
  final int level;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isGroup = level == 0;

    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + level * 28, right: 8),
      leading: Icon(
        isGroup ? Icons.folder_outlined : Icons.receipt_long_outlined,
        color: isGroup ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      subtitle: AppText(
        category.isActive ? l10n.activeStatus : l10n.inactiveStatus,
        variant: AppTextVariant.label,
      ),
      title: AppText(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
            tooltip: l10n.deleteAction,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
            tooltip: l10n.editAction,
          ),
        ],
      ),
    );
  }
}
