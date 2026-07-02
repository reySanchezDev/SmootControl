import 'package:equatable/equatable.dart';

/// Packaging consumed by sales, not directly sold.
final class PackagingItem extends Equatable {
  /// Creates a packaging item.
  const PackagingItem({
    required this.id,
    required this.name,
    required this.costInCents,
    required this.tracksStock,
    required this.isActive,
  });

  /// Stable identifier.
  final String id;

  /// Visible name.
  final String name;

  /// Historical unit cost in minor currency units.
  final int costInCents;

  /// Whether stock is validated and updated.
  final bool tracksStock;

  /// Whether the packaging item can be used.
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    name,
    costInCents,
    tracksStock,
    isActive,
  ];
}
