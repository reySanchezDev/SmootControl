import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';

/// Data model for expense categories.
final class ExpenseCategoryModel extends Equatable {
  /// Creates an expense category model.
  const ExpenseCategoryModel({
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

  /// Creates a model from a local Drift row.
  factory ExpenseCategoryModel.fromLocal(LocalExpenseCategory row) {
    return ExpenseCategoryModel(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      isActive: row.isActive,
      includeInGrossProfitCoverage: row.includeInGrossProfitCoverage,
      coverageType: _coverageType(row.coverageExpenseType),
      coverageEstimatedAmountInCents: row.coverageEstimatedAmountInCents,
      coverageFrequency: _coverageFrequency(row.coverageFrequency),
      coverageDueDays: _dueDays(row.coverageDueDaysJson),
      coverageNotes: row.coverageNotes,
      coverageIsActive: row.coverageIsActive,
    );
  }

  /// Creates a model from a domain entity.
  factory ExpenseCategoryModel.fromEntity(ExpenseCategory entity) {
    return ExpenseCategoryModel(
      id: entity.id,
      name: entity.name,
      parentId: entity.parentId,
      isActive: entity.isActive,
      includeInGrossProfitCoverage: entity.includeInGrossProfitCoverage,
      coverageType: entity.coverageType,
      coverageEstimatedAmountInCents: entity.coverageEstimatedAmountInCents,
      coverageFrequency: entity.coverageFrequency,
      coverageDueDays: entity.coverageDueDays,
      coverageNotes: entity.coverageNotes,
      coverageIsActive: entity.coverageIsActive,
    );
  }

  /// Unique category identifier.
  final String id;

  /// Visible category name.
  final String name;

  /// Parent category identifier.
  final String? parentId;

  /// Whether the category can be used.
  final bool isActive;

  /// Whether this category subtracts from gross profit coverage reports.
  final bool includeInGrossProfitCoverage;

  /// Fixed or variable projected obligation behavior.
  final ExpenseCoverageType? coverageType;

  /// Estimated amount in minor currency units.
  final int? coverageEstimatedAmountInCents;

  /// Recurrence for projected coverage reports.
  final ExpenseCoverageFrequency? coverageFrequency;

  /// Due days used to project obligations.
  final List<int> coverageDueDays;

  /// Optional planning note.
  final String? coverageNotes;

  /// Whether the projection configuration is active.
  final bool coverageIsActive;

  /// JSON representation for local persistence.
  String get coverageDueDaysJson => jsonEncode(coverageDueDays);

  /// Converts this model to a domain entity.
  ExpenseCategory toEntity() {
    return ExpenseCategory(
      id: id,
      name: name,
      parentId: parentId,
      isActive: isActive,
      includeInGrossProfitCoverage: includeInGrossProfitCoverage,
      coverageType: coverageType,
      coverageEstimatedAmountInCents: coverageEstimatedAmountInCents,
      coverageFrequency: coverageFrequency,
      coverageDueDays: coverageDueDays,
      coverageNotes: coverageNotes,
      coverageIsActive: coverageIsActive,
    );
  }

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

  static ExpenseCoverageType? _coverageType(String? value) {
    for (final type in ExpenseCoverageType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  static ExpenseCoverageFrequency? _coverageFrequency(String? value) {
    for (final frequency in ExpenseCoverageFrequency.values) {
      if (frequency.name == value) return frequency;
    }
    return null;
  }

  static List<int> _dueDays(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded.whereType<num>().map((day) => day.round()).toList();
  }
}
