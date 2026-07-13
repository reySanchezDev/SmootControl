import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

part 'create_expense_category_dialog_support.dart';

/// Dialog used to create an expense category.
class CreateExpenseCategoryDialog extends StatefulWidget {
  /// Creates the expense category dialog.
  const CreateExpenseCategoryDialog({
    this.categories = const [],
    this.category,
    super.key,
  });

  /// Existing categories available as parents.
  final List<ExpenseCategory> categories;

  /// Expense category being edited.
  final ExpenseCategory? category;

  @override
  State<CreateExpenseCategoryDialog> createState() =>
      _CreateExpenseCategoryDialogState();
}

class _CreateExpenseCategoryDialogState
    extends State<CreateExpenseCategoryDialog> {
  final _amountController = TextEditingController();
  final _dueDaysController = TextEditingController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  ExpenseCoverageFrequency? _coverageFrequency;
  ExpenseCoverageType? _coverageType;
  bool _isActive = true;
  bool _includeInGrossProfitCoverage = false;
  String? _error;
  String? _parentId;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category == null) {
      return;
    }

    _nameController.text = category.name;
    _isActive = category.isActive;
    _includeInGrossProfitCoverage = category.includeInGrossProfitCoverage;
    _parentId = category.parentId;
    _coverageType = category.coverageType;
    _coverageFrequency = category.coverageFrequency;
    _amountController.text = _amountText(
      category.coverageEstimatedAmountInCents,
    );
    _dueDaysController.text = category.coverageDueDays.join(', ');
    _notesController.text = category.coverageNotes ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dueDaysController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: AppText(
        widget.category == null
            ? l10n.createExpenseCategoryTitle
            : l10n.editExpenseCategoryTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(label: l10n.nameField, controller: _nameController),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              decoration: InputDecoration(labelText: l10n.categoryInsideOf),
              initialValue: _parentId,
              items: [
                DropdownMenuItem<String?>(
                  child: AppText(l10n.rootCategoryOption),
                ),
                for (final category in _parentOptions)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: AppText(category.name),
                  ),
              ],
              onChanged: _changeParent,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.activeField),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value ?? true),
            ),
            if (_parentId != null) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: AppText(l10n.expenseCategoryCoverageField),
                subtitle: AppText(
                  l10n.expenseCategoryCoverageSubcategoryHelp,
                  maxLines: 3,
                  variant: AppTextVariant.label,
                ),
                value: _includeInGrossProfitCoverage,
                onChanged: _changeCoverageEnabled,
              ),
              if (_includeInGrossProfitCoverage) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<ExpenseCoverageType>(
                  decoration: InputDecoration(
                    labelText: l10n.expenseCoverageTypeField,
                  ),
                  initialValue: _coverageType,
                  items: [
                    DropdownMenuItem(
                      value: ExpenseCoverageType.fixed,
                      child: AppText(l10n.expenseCoverageTypeFixed),
                    ),
                    DropdownMenuItem(
                      value: ExpenseCoverageType.variable,
                      child: AppText(l10n.expenseCoverageTypeVariable),
                    ),
                  ],
                  onChanged: (value) => setState(() => _coverageType = value),
                ),
                const SizedBox(height: 8),
                AppInput(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  label: l10n.expenseCoverageAmountField,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ExpenseCoverageFrequency>(
                  decoration: InputDecoration(
                    labelText: l10n.expenseCoverageFrequencyField,
                  ),
                  initialValue: _coverageFrequency,
                  items: [
                    DropdownMenuItem(
                      value: ExpenseCoverageFrequency.weekly,
                      child: AppText(l10n.expenseCoverageFrequencyWeekly),
                    ),
                    DropdownMenuItem(
                      value: ExpenseCoverageFrequency.biweekly,
                      child: AppText(l10n.expenseCoverageFrequencyBiweekly),
                    ),
                    DropdownMenuItem(
                      value: ExpenseCoverageFrequency.monthly,
                      child: AppText(l10n.expenseCoverageFrequencyMonthly),
                    ),
                    DropdownMenuItem(
                      value: ExpenseCoverageFrequency.custom,
                      child: AppText(l10n.expenseCoverageFrequencyCustom),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _coverageFrequency = value),
                ),
                const SizedBox(height: 8),
                AppInput(
                  controller: _dueDaysController,
                  keyboardType: TextInputType.number,
                  label: l10n.expenseCoverageDueDaysField,
                ),
                const SizedBox(height: 8),
                AppInput(
                  controller: _notesController,
                  label: l10n.expenseCoverageNotesField,
                  maxLines: 2,
                ),
              ],
            ],
            if (_error != null) AppText(_error!, maxLines: 2),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancelAction,
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(label: l10n.saveAction, onPressed: _submit),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final dueDays = _parseDueDays();
    final amountInCents = _parseAmountInCents();

    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }
    final coverageError = _coverageError(l10n, dueDays, amountInCents);
    if (coverageError != null) {
      setState(() => _error = coverageError);
      return;
    }

    final includeCoverage =
        _parentId != null && _includeInGrossProfitCoverage;

    Navigator.of(context).pop(
      ExpenseCategory(
        id: widget.category?.id ?? const Uuid().v4(),
        name: name,
        parentId: _parentId,
        isActive: _isActive,
        includeInGrossProfitCoverage: includeCoverage,
        coverageDueDays: includeCoverage ? dueDays : const [],
        coverageEstimatedAmountInCents: includeCoverage
            ? amountInCents
            : null,
        coverageFrequency: includeCoverage ? _coverageFrequency : null,
        coverageNotes: includeCoverage ? _notesController.text.trim() : null,
        coverageType: includeCoverage ? _coverageType : null,
      ),
    );
  }

  void _changeCoverageEnabled(bool? value) {
    setState(() {
      _includeInGrossProfitCoverage = value ?? false;
      if (_includeInGrossProfitCoverage) {
        _coverageType ??= ExpenseCoverageType.fixed;
        _coverageFrequency ??= ExpenseCoverageFrequency.monthly;
      }
    });
  }

  void _changeParent(String? value) {
    setState(() {
      _parentId = value;
      if (_parentId == null) {
        _includeInGrossProfitCoverage = false;
      }
    });
  }

  List<ExpenseCategory> get _parentOptions {
    final editedId = widget.category?.id;
    return widget.categories.where((category) {
      return category.isActive &&
          category.id != editedId &&
          category.parentId == null;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}
