import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/responsive_touch_dialog_frame.dart';
import 'package:smoo_control/core/design_system/touch_numeric_keyboard_dialog.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to register an operational expense.
class CreateExpenseDialog extends StatefulWidget {
  /// Creates the expense dialog.
  const CreateExpenseDialog({
    required this.categories,
    this.cashRegisterSessionId,
    this.initialCategoryId,
    this.lockCategory = false,
    this.useTouchInput = false,
    super.key,
  });

  /// Expense categories available for selection.
  final List<ExpenseCategory> categories;

  /// Open cash register session used internally for this expense.
  final String? cashRegisterSessionId;

  /// Category selected before opening the dialog.
  final String? initialCategoryId;

  /// Whether the category selector should stay locked.
  final bool lockCategory;

  /// Whether amount and description use touch-first keyboards.
  final bool useTouchInput;

  @override
  State<CreateExpenseDialog> createState() => _CreateExpenseDialogState();
}

class _CreateExpenseDialogState extends State<CreateExpenseDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _error;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ResponsiveTouchDialogFrame(
      maxWidth: 560,
      title: AppText(
        l10n.createExpenseTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: l10n.parentCategoryField,
            ),
            initialValue: _selectedCategoryId,
            items: [
              for (final category in _activeCategories)
                DropdownMenuItem(
                  value: category.id,
                  child: AppText(category.name),
                ),
            ],
            onChanged: widget.lockCategory
                ? null
                : (value) {
                    setState(() {
                      _selectedCategoryId = value;
                      _error = null;
                    });
                  },
          ),
          const SizedBox(height: 12),
          AppInput(
            label: l10n.amountInCentsField,
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onTap: widget.useTouchInput ? _openAmountKeyboard : null,
            readOnly: widget.useTouchInput,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: l10n.descriptionField,
            controller: _descriptionController,
            maxLines: widget.useTouchInput ? 2 : 1,
            onTap: widget.useTouchInput ? _openDescriptionKeyboard : null,
            readOnly: widget.useTouchInput,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            AppText(_error!, maxLines: 2),
          ],
        ],
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

  Future<void> _openAmountKeyboard() async {
    final value = await showTouchNumericKeyboardDialog<String>(
      context: context,
      initialValue: _amountController.text,
      prefixText: '${MoneyFormatter.symbol} ',
      resultBuilder: (value) => value,
      title: AppLocalizations.of(context).amountInCentsField,
      validator: (value) {
        return MoneyFormatter.parseToCents(value) == null
            ? AppLocalizations.of(context).numericFieldError
            : null;
      },
    );
    if (value == null || !mounted) return;
    setState(() {
      _amountController.text = value;
      _error = null;
    });
  }

  Future<void> _openDescriptionKeyboard() async {
    final value = await showTouchTextKeyboardDialog(
      context: context,
      initialValue: _descriptionController.text,
      label: AppLocalizations.of(context).descriptionField,
      title: AppLocalizations.of(context).descriptionField,
    );
    if (value == null || !mounted) return;
    setState(() {
      _descriptionController.text = value;
      _error = null;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final amount = MoneyFormatter.parseToCents(_amountController.text);
    final description = _descriptionController.text.trim();

    if (_selectedCategoryId == null || description.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    if (amount == null) {
      setState(() => _error = l10n.numericFieldError);
      return;
    }

    Navigator.of(context).pop(
      OperatingExpense(
        id: const Uuid().v4(),
        categoryId: _selectedCategoryId!,
        cashRegisterSessionId: widget.cashRegisterSessionId,
        amountInCents: amount,
        description: description,
        createdAt: DateTime.now(),
        createdBy: serviceLocator<CurrentOperatorService>().userId,
      ),
    );
  }

  List<ExpenseCategory> get _activeCategories {
    final parentIds = widget.categories
        .where((category) => category.parentId != null)
        .map((category) => category.parentId)
        .toSet();
    return widget.categories.where((category) {
      return category.isActive && !parentIds.contains(category.id);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}
