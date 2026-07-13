part of 'create_expense_category_dialog.dart';

extension _CreateExpenseCategoryDialogSupport
    on _CreateExpenseCategoryDialogState {
  String? _coverageError(
    AppLocalizations l10n,
    List<int> dueDays,
    int? amountInCents,
  ) {
    if (_parentId == null || !_includeInGrossProfitCoverage) return null;
    if (_coverageType == null || _coverageFrequency == null) {
      return l10n.fieldRequiredError;
    }
    if (_coverageType == ExpenseCoverageType.fixed &&
        (amountInCents == null || amountInCents <= 0)) {
      return l10n.expenseCoverageAmountRequiredError;
    }
    if (amountInCents != null && amountInCents < 0) {
      return l10n.expenseCoverageAmountInvalidError;
    }
    if (dueDays.isEmpty) {
      return l10n.expenseCoverageDueDaysRequiredError;
    }
    if (dueDays.any((day) => day < 1 || day > 31)) {
      return l10n.expenseCoverageDueDaysInvalidError;
    }
    return null;
  }

  int? _parseAmountInCents() {
    final value = _amountController.text.trim();
    if (value.isEmpty) return null;
    return MoneyFormatter.parseToCents(value) ?? -1;
  }

  List<int> _parseDueDays() {
    return _dueDaysController.text
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
  }

  String _amountText(int? cents) {
    if (cents == null) return '';
    return (cents / 100).toStringAsFixed(2);
  }
}
