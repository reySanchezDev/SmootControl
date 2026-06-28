import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_state.dart';
import 'package:smoo_control/features/expenses/presentation/widgets/create_expense_category_dialog.dart';
import 'package:smoo_control/features/expenses/presentation/widgets/expenses_overview_list.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Operational expenses page.
class ExpensesPage extends StatelessWidget {
  /// Creates the expenses page.
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<ExpensesBloc>()
            ..add(const ExpenseCategoriesLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final state = context.read<ExpensesBloc>().state;
                final categories = state is ExpensesOverviewLoaded
                    ? state.categories
                    : const <ExpenseCategory>[];
                unawaited(
                  _openCategoryDialog(context, categories: categories),
                );
              },
              tooltip: l10n.createExpenseCategoryTitle,
            ),
          ],
          title: l10n.moduleExpenses,
          body: BlocBuilder<ExpensesBloc, ExpensesState>(
            builder: (context, state) {
              return switch (state) {
                ExpensesInitial() ||
                ExpensesLoading() => const AppLoadingPage(),
                ExpensesFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleExpenses,
                ),
                ExpensesOverviewLoaded(:final categories)
                    when categories.isEmpty =>
                  AppEmptyState(
                    icon: Icons.request_quote_outlined,
                    message: l10n.emptyExpensesMessage,
                    title: l10n.emptyExpensesTitle,
                  ),
                ExpensesOverviewLoaded(:final categories) =>
                  ExpensesOverviewList(
                    categories: categories,
                    onCategoryDelete: (category) {
                      unawaited(_deleteCategory(context, category));
                    },
                    onCategoryEdit: (category) {
                      unawaited(
                        _openCategoryDialog(
                          context,
                          categories: categories,
                          category: category,
                        ),
                      );
                    },
                  ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCategoryDialog(
    BuildContext context, {
    List<ExpenseCategory> categories = const [],
    ExpenseCategory? category,
  }) async {
    final updated = await showDialog<ExpenseCategory>(
      context: context,
      builder: (_) => CreateExpenseCategoryDialog(
        categories: categories,
        category: category,
      ),
    );

    if (updated != null && context.mounted) {
      context.read<ExpensesBloc>().add(ExpenseCategorySaved(updated));
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    ExpenseCategory category,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteExpenseCategoryTitle),
        content: Text(l10n.deleteExpenseCategoryMessage(category.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    context.read<ExpensesBloc>().add(ExpenseCategoryDeleted(category));
  }
}
