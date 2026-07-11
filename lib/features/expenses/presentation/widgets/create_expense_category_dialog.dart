import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

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
  final _nameController = TextEditingController();
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
  }

  @override
  void dispose() {
    _nameController.dispose();
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
              onChanged: (value) => setState(() {
                _parentId = value;
                if (_parentId != null) {
                  _includeInGrossProfitCoverage = false;
                }
              }),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.activeField),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value ?? true),
            ),
            if (_parentId == null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: AppText(l10n.expenseCategoryCoverageField),
                subtitle: AppText(
                  l10n.expenseCategoryCoverageHelp,
                  maxLines: 3,
                  variant: AppTextVariant.label,
                ),
                value: _includeInGrossProfitCoverage,
                onChanged: (value) => setState(
                  () => _includeInGrossProfitCoverage = value ?? false,
                ),
              ),
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

    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    Navigator.of(context).pop(
      ExpenseCategory(
        id: widget.category?.id ?? const Uuid().v4(),
        name: name,
        parentId: _parentId,
        isActive: _isActive,
        includeInGrossProfitCoverage:
            _parentId == null && _includeInGrossProfitCoverage,
      ),
    );
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
