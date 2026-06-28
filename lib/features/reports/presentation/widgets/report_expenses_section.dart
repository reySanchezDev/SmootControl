import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Dedicated expense report list with category filtering.
class ReportExpensesSection extends StatefulWidget {
  /// Creates the expenses report section.
  const ReportExpensesSection({required this.expenses, super.key});

  /// Expenses in the selected report period.
  final List<ExpenseReportEntry> expenses;

  @override
  State<ReportExpensesSection> createState() => _ReportExpensesSectionState();
}

class _ReportExpensesSectionState extends State<ReportExpensesSection> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expenses = _filteredExpenses;

    if (widget.expenses.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        message: l10n.reportNoExpenses,
        title: l10n.reportExpensesDetail,
      );
    }

    return Column(
      children: [
        DropdownButtonFormField<String?>(
          decoration: InputDecoration(labelText: l10n.expenseCategoryFilter),
          initialValue: _categoryId,
          items: [
            DropdownMenuItem<String?>(
              child: AppText(l10n.allCategoriesOption),
            ),
            for (final category in _categories)
              DropdownMenuItem<String?>(
                value: category.id,
                child: AppText(category.name),
              ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        const SizedBox(height: 8),
        for (final expense in expenses) _ExpenseReportTile(expense: expense),
      ],
    );
  }

  List<ExpenseReportEntry> get _filteredExpenses {
    final categoryId = _categoryId;
    if (categoryId == null) return widget.expenses;
    return widget.expenses.where((expense) {
      return expense.categoryId == categoryId;
    }).toList();
  }

  List<_ExpenseCategoryOption> get _categories {
    final categories = <String, String>{};
    for (final expense in widget.expenses) {
      categories[expense.categoryId] = expense.categoryName;
    }
    return categories.entries
        .map((entry) => _ExpenseCategoryOption(entry.key, entry.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}

class _ExpenseReportTile extends StatelessWidget {
  const _ExpenseReportTile({required this.expense});

  final ExpenseReportEntry expense;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      subtitle: AppText(
        '${expense.categoryName} - ${expense.description}',
        maxLines: 2,
        variant: AppTextVariant.label,
      ),
      title: AppText(_timeLabel(expense.createdAt)),
      trailing: AppText(MoneyFormatter.format(expense.amountInCents)),
    );
  }

  String _timeLabel(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}

final class _ExpenseCategoryOption {
  const _ExpenseCategoryOption(this.id, this.name);

  final String id;
  final String name;
}
