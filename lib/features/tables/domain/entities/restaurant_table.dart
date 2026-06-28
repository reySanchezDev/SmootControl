import 'package:equatable/equatable.dart';

/// Current lifecycle state of a restaurant table.
enum RestaurantTableStatus {
  /// Table has no open account.
  available,

  /// Table has products assigned directly or through split accounts.
  occupied,

  /// Table is temporarily unavailable.
  disabled,
}

/// Physical or logical restaurant table.
final class RestaurantTable extends Equatable {
  /// Creates a restaurant table.
  const RestaurantTable({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    this.displayName,
  });

  /// Unique table identifier.
  final String id;

  /// Internal table name used for reports and control.
  final String name;

  /// Temporary operational name shown to waiters and cashiers.
  final String? displayName;

  /// Name shown in the POS.
  String get operationalName {
    final value = displayName?.trim();
    if (value == null || value.isEmpty) return name;
    return value;
  }

  /// Current table state.
  final RestaurantTableStatus status;

  /// Whether the table can be used.
  final bool isActive;

  @override
  List<Object?> get props => [id, name, displayName, status, isActive];
}
