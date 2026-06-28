import 'package:equatable/equatable.dart';

/// Reusable POS modifier group.
final class ModifierGroup extends Equatable {
  /// Creates a modifier group.
  const ModifierGroup({
    required this.id,
    required this.name,
    this.isRequired = true,
    this.displayOrder = 0,
    this.isActive = true,
  });

  /// Unique identifier.
  final String id;

  /// Visible group name.
  final String name;

  /// Whether POS must receive one option.
  final bool isRequired;

  /// Visual order.
  final int displayOrder;

  /// Whether the group is usable.
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    name,
    isRequired,
    displayOrder,
    isActive,
  ];
}
