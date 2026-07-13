import 'package:equatable/equatable.dart';

/// Expense category behavior for projected coverage reports.
enum ExpenseCoverageType {
  /// Amount is expected and normally stable.
  fixed,

  /// Amount may change and the estimate is optional.
  variable,
}

/// Recurrence used to project when an expense should be covered.
enum ExpenseCoverageFrequency {
  /// Expected every week.
  weekly,

  /// Expected twice per month.
  biweekly,

  /// Expected once per month.
  monthly,

  /// Custom schedule controlled by due days.
  custom,
}

/// Category used to classify operational expenses.
final class ExpenseCategory extends Equatable {
  /// Creates an expense category.
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.isActive,
    this.coverageDueDays = const [],
    this.coverageEstimatedAmountInCents,
    this.coverageFrequency,
    this.coverageIsActive = true,
    this.coverageNotes,
    this.coverageType,
    this.includeInGrossProfitCoverage = false,
    this.parentId,
  });

  /// Unique category identifier.
  final String id;

  /// Visible category name.
  final String name;

  /// Parent category identifier when this category belongs to one group.
  final String? parentId;

  /// Whether the category is available for new expenses.
  final bool isActive;

  /// Whether expenses under this category should reduce coverage reports.
  final bool includeInGrossProfitCoverage;

  /// Fixed or variable projected obligation behavior.
  final ExpenseCoverageType? coverageType;

  /// Estimated amount in minor currency units for projected coverage.
  final int? coverageEstimatedAmountInCents;

  /// Recurrence used by coverage reports to place due dates.
  final ExpenseCoverageFrequency? coverageFrequency;

  /// Days of month or cadence markers used by projected coverage.
  final List<int> coverageDueDays;

  /// Optional operational note for coverage planning.
  final String? coverageNotes;

  /// Whether this coverage configuration is currently usable.
  final bool coverageIsActive;

  /// True when this category is a child expense concept.
  bool get isSubcategory => parentId != null;

  @override
  List<Object?> get props => [
    id,
    name,
    parentId,
    isActive,
    includeInGrossProfitCoverage,
    coverageType,
    coverageEstimatedAmountInCents,
    coverageFrequency,
    coverageDueDays,
    coverageNotes,
    coverageIsActive,
  ];
}
