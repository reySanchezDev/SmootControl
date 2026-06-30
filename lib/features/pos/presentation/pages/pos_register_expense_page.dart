import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/expenses/presentation/widgets/create_expense_dialog.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// POS flow for registering an operating expense from the open cash register.
class PosRegisterExpensePage extends StatefulWidget {
  /// Creates the POS expense page.
  const PosRegisterExpensePage({
    required this.cashRegisterSessionId,
    super.key,
  });

  /// Cash register session that owns the expense.
  final String cashRegisterSessionId;

  @override
  State<PosRegisterExpensePage> createState() => _PosRegisterExpensePageState();
}

class _PosRegisterExpensePageState extends State<PosRegisterExpensePage> {
  late Future<AppResult<List<ExpenseCategory>>> _future;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _future = serviceLocator<IExpensesRepository>().getCategories();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppPageScaffold(
      title: l10n.posRegisterExpenseAction,
      body: FutureBuilder<AppResult<List<ExpenseCategory>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AppLoadingPage();

          return switch (snapshot.requireData) {
            AppSuccess(:final value) => _content(value),
            AppFailureResult(:final error) => AppEmptyState(
              icon: Icons.error_outline,
              message: error.message,
              title: l10n.posRegisterExpenseAction,
            ),
          };
        },
      ),
    );
  }

  Widget _content(List<ExpenseCategory> categories) {
    final active = categories.where((category) => category.isActive).toList();
    if (active.isEmpty) {
      return AppEmptyState(
        icon: Icons.request_quote_outlined,
        message: AppLocalizations.of(context).emptyExpensesMessage,
        title: AppLocalizations.of(context).emptyExpensesTitle,
      );
    }

    final groups = _groups(active);
    final selectedGroupId = _selectedGroupId ?? groups.first.id;
    final selectedGroup = groups.firstWhere(
      (group) => group.id == selectedGroupId,
      orElse: () => groups.first,
    );
    final children = _children(active, selectedGroup.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final groupHeight = (constraints.maxHeight * .18).clamp(82.0, 140.0);
        return Column(
          children: [
            SizedBox(
              height: groupHeight,
              child: PosTouchGrid(
                children: [
                  for (final group in groups)
                    PosTouchButton(
                      icon: Icons.folder_outlined,
                      label: group.name,
                      onPressed: () {
                        setState(() => _selectedGroupId = group.id);
                      },
                      selected: group.id == selectedGroup.id,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  selectedGroup.name,
                  variant: AppTextVariant.titleMedium,
                ),
              ),
            ),
            Expanded(
              child: _ExpenseCategoryGrid(
                categories: children.isEmpty ? [selectedGroup] : children,
                onSelected: (category) =>
                    _registerExpense(categories, category),
              ),
            ),
          ],
        );
      },
    );
  }

  List<ExpenseCategory> _groups(List<ExpenseCategory> categories) {
    final childParentIds = categories
        .where((category) => category.parentId != null)
        .map((category) => category.parentId)
        .toSet();
    final groups = categories.where((category) {
      return category.parentId == null || childParentIds.contains(category.id);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return groups.isEmpty ? categories : groups;
  }

  List<ExpenseCategory> _children(
    List<ExpenseCategory> categories,
    String parentId,
  ) {
    return categories.where((category) {
      return category.parentId == parentId;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _registerExpense(
    List<ExpenseCategory> categories,
    ExpenseCategory category,
  ) async {
    final expense = await showDialog<OperatingExpense>(
      context: context,
      builder: (_) => CreateExpenseDialog(
        cashRegisterSessionId: widget.cashRegisterSessionId,
        categories: categories,
        initialCategoryId: category.id,
        lockCategory: true,
        useTouchInput: true,
      ),
    );
    if (expense == null || !mounted) return;

    final result = await serviceLocator<IExpensesRepository>().saveExpense(
      expense,
    );
    if (!mounted) return;

    switch (result) {
      case AppSuccess():
        await _writeAudit(expense);
        if (!mounted) return;
        await showAppMessageDialog(
          context: context,
          message: AppLocalizations.of(context).expenseSavedMessage,
        );
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }

  Future<void> _writeAudit(OperatingExpense expense) async {
    await serviceLocator<IAuditLogRepository>().saveEntry(
      AuditLogEntry(
        id: const Uuid().v4(),
        actorUserId: expense.createdBy,
        action: 'expenses.save',
        entityName: 'operating_expenses',
        entityId: expense.id,
        details: {
          'amountInCents': expense.amountInCents,
          'description': expense.description,
        },
        occurredAt: DateTime.now(),
      ),
    );
  }
}

class _ExpenseCategoryGrid extends StatelessWidget {
  const _ExpenseCategoryGrid({
    required this.categories,
    required this.onSelected,
  });

  final List<ExpenseCategory> categories;
  final ValueChanged<ExpenseCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxExtent = constraints.maxWidth < 700 ? 210.0 : 280.0;
        final tileHeight = (constraints.maxHeight * .24).clamp(
          88.0,
          constraints.maxWidth < 700 ? 104.0 : 124.0,
        );
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            crossAxisSpacing: 8,
            mainAxisExtent: tileHeight,
            mainAxisSpacing: 8,
            maxCrossAxisExtent: maxExtent,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _ExpenseCategoryTile(
              category: category,
              onTap: () => onSelected(category),
            );
          },
          itemCount: categories.length,
          padding: const EdgeInsets.all(12),
        );
      },
    );
  }
}

class _ExpenseCategoryTile extends StatelessWidget {
  const _ExpenseCategoryTile({
    required this.category,
    required this.onTap,
  });

  final ExpenseCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.success,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_card_outlined,
                color: AppPalette.surface,
                size: 24,
              ),
              const SizedBox(height: 8),
              AppText(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppPalette.surface),
                textAlign: TextAlign.center,
                variant: AppTextVariant.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
