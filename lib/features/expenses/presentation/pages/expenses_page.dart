import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/backoffice_action_feedback.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
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
          title: l10n.moduleExpenses,
          body: BlocConsumer<ExpensesBloc, ExpensesState>(
            listenWhen: (_, current) =>
                current is ExpensesActionSucceeded ||
                current is ExpensesActionFailed,
            listener: (context, state) {
              switch (state) {
                case ExpensesActionSucceeded(:final message):
                  BackofficeActionFeedback.show(
                    context,
                    outcome: BackofficeActionOutcome.success,
                    message: message,
                  );
                case ExpensesActionFailed(:final failure):
                  BackofficeActionFeedback.show(
                    context,
                    outcome: BackofficeActionOutcome.error,
                    message: 'No se completó la operación: ${failure.message}',
                  );
                default:
                  break;
              }
            },
            builder: (context, state) {
              return switch (state) {
                ExpensesInitial() ||
                ExpensesLoading() ||
                ExpensesActionSucceeded() => const AppLoadingPage(),
                ExpensesFailure(:final failure) ||
                ExpensesActionFailed(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleExpenses,
                ),
                ExpensesOverviewLoaded(:final categories) =>
                  ExpensesOverviewList(
                    categories: categories,
                    onCreate: () => unawaited(
                      _openCategoryDialog(context, categories: categories),
                    ),
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
    final confirmed = await showAppConfirmationDialog(
      context,
      title: l10n.deleteExpenseCategoryTitle,
      message: l10n.deleteExpenseCategoryMessage(category.name),
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    context.read<ExpensesBloc>().add(ExpenseCategoryDeleted(category));
  }
}
