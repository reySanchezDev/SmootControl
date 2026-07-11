import 'package:equatable/equatable.dart';

/// Catalog entry for an employee job position.
final class EmployeePosition extends Equatable {
  /// Creates an employee position.
  const EmployeePosition({
    required this.id,
    required this.name,
    this.displayOrder = 0,
    this.isActive = true,
  });

  /// Remote identifier assigned by Supabase.
  final String id;

  /// Visible position name.
  final String name;

  /// Sorting order in admin selectors.
  final int displayOrder;

  /// Whether the position can be selected.
  final bool isActive;

  @override
  List<Object?> get props => [id, name, displayOrder, isActive];
}
