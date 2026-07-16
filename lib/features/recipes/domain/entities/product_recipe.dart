import 'package:equatable/equatable.dart';

/// Active recipe configured for one product.
final class ProductRecipe extends Equatable {
  /// Creates a product recipe.
  const ProductRecipe({
    required this.id,
    required this.productId,
    required this.version,
    required this.lines,
  });

  /// Recipe identifier.
  final String id;

  /// Product that owns this recipe.
  final String productId;

  /// Monotonic version for audit/history.
  final int version;

  /// Active ingredient lines.
  final List<ProductRecipeLine> lines;

  @override
  List<Object?> get props => [id, productId, version, lines];
}

/// One ingredient or preparation consumed by a recipe.
final class ProductRecipeLine extends Equatable {
  /// Creates a recipe line.
  const ProductRecipeLine({
    required this.componentProductId,
    required this.quantity,
    required this.unitId,
    this.componentName,
    this.displayOrder = 0,
    this.unitName,
    this.wastePercent = 0,
  });

  /// Product consumed by the recipe.
  final String componentProductId;

  /// Optional display name loaded from Supabase.
  final String? componentName;

  /// Quantity entered in [unitId].
  final double quantity;

  /// Unit used by the quantity.
  final String unitId;

  /// Optional display name loaded from Supabase.
  final String? unitName;

  /// Expected waste percentage.
  final double wastePercent;

  /// Visual line order.
  final int displayOrder;

  @override
  List<Object?> get props => [
    componentProductId,
    componentName,
    quantity,
    unitId,
    unitName,
    wastePercent,
    displayOrder,
  ];
}
