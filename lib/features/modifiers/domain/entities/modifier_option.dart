import 'package:equatable/equatable.dart';

/// Option inside a reusable POS modifier group.
final class ModifierOption extends Equatable {
  /// Creates a modifier option.
  const ModifierOption({
    required this.id,
    required this.groupId,
    required this.name,
    this.priceDeltaInCents = 0,
    this.displayOrder = 0,
    this.isActive = true,
    this.isAvailableInPos = true,
  });

  /// Unique identifier.
  final String id;

  /// Parent group identifier.
  final String groupId;

  /// Visible option name.
  final String name;

  /// Optional price delta.
  final int priceDeltaInCents;

  /// Visual order.
  final int displayOrder;

  /// Whether this option exists in the catalog.
  final bool isActive;

  /// Whether this option is available for today's POS.
  final bool isAvailableInPos;

  @override
  List<Object?> get props => [
    id,
    groupId,
    name,
    priceDeltaInCents,
    displayOrder,
    isActive,
    isAvailableInPos,
  ];
}
