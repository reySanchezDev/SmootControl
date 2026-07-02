import 'package:equatable/equatable.dart';

/// Packaging consumed by a product under one sales type.
final class ProductPackagingRule extends Equatable {
  /// Creates a product packaging rule.
  const ProductPackagingRule({
    required this.id,
    required this.productId,
    required this.salesTypeId,
    required this.packagingItemId,
    required this.quantityPerUnit,
    required this.isActive,
  });

  /// Stable identifier.
  final String id;

  /// Product identifier.
  final String productId;

  /// Sales type identifier.
  final String salesTypeId;

  /// Packaging item identifier.
  final String packagingItemId;

  /// Quantity consumed per sold unit.
  final int quantityPerUnit;

  /// Whether this rule is applied.
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    productId,
    salesTypeId,
    packagingItemId,
    quantityPerUnit,
    isActive,
  ];
}
