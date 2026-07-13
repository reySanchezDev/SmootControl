part of 'supabase_admin_expenses_repository.dart';

extension _SupabaseAdminExpensesRepositorySupport
    on SupabaseAdminExpensesRepository {
  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value == null) return fallback;
    return value.toString().toLowerCase() == 'true';
  }

  ExpenseCategory _normalizedCategory(ExpenseCategory category) {
    if (category.parentId != null && category.includeInGrossProfitCoverage) {
      return category;
    }
    return ExpenseCategory(
      id: category.id,
      name: category.name,
      parentId: category.parentId,
      isActive: category.isActive,
    );
  }

  ExpenseCoverageType? _coverageType(Object? value) {
    final text = _nullableText(value);
    for (final type in ExpenseCoverageType.values) {
      if (type.name == text) return type;
    }
    return null;
  }

  ExpenseCoverageFrequency? _coverageFrequency(Object? value) {
    final text = _nullableText(value);
    for (final frequency in ExpenseCoverageFrequency.values) {
      if (frequency.name == text) return frequency;
    }
    return null;
  }

  List<int> _intList(Object? value) {
    if (value is List) {
      return value.whereType<num>().map((day) => day.round()).toList();
    }
    return const [];
  }

  int _moneyToCents(Object? value) {
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value?.toString() ?? '') ?? 0) * 100).round();
  }

  int? _nullableMoneyToCents(Object? value) {
    if (value == null) return null;
    return _moneyToCents(value);
  }

  num _money(int cents) => cents / 100;

  DateTime _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return DateTime.now();
    return DateTime.tryParse(text) ?? DateTime.now();
  }
}
