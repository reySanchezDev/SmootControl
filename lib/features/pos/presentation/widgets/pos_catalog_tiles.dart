import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/product_options_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

part 'pos_catalog_category_tiles_part.dart';
part 'pos_catalog_product_tiles_part.dart';

/// Returns a copy where the dragged product swaps position with the target.
@visibleForTesting
List<Product> swapPosProductsForDrop({
  required Product draggedProduct,
  required List<Product> products,
  required Product targetProduct,
}) {
  final fromIndex = products.indexWhere(
    (candidate) => candidate.id == draggedProduct.id,
  );
  final toIndex = products.indexWhere(
    (candidate) => candidate.id == targetProduct.id,
  );
  if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex) return products;

  final reordered = [...products];
  reordered[fromIndex] = products[toIndex];
  reordered[toIndex] = draggedProduct;
  return reordered;
}

/// Vertical or horizontal root category rail for the POS.
class PosCategoryRail extends StatelessWidget {
  /// Creates a category rail.
  const PosCategoryRail({
    required this.activeCategoryId,
    required this.categories,
    this.compact = false,
    super.key,
  });

  /// Selected category identifier.
  final String? activeCategoryId;

  /// Root categories shown in the rail.
  final List<ProductCategory> categories;

  /// Whether the rail should be horizontal.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        height: 84,
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) => SizedBox(
            width: 148,
            child: _CategoryRailButton(
              active: categories[index].id == activeCategoryId,
              category: categories[index],
            ),
          ),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemCount: categories.length,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) => _CategoryRailButton(
        active: categories[index].id == activeCategoryId,
        category: categories[index],
      ),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemCount: categories.length,
    );
  }
}

/// Grid with subcategories and products for the active POS category.
class PosMenuGrid extends StatelessWidget {
  /// Creates a POS menu grid.
  const PosMenuGrid({
    required this.canAddProducts,
    required this.categories,
    required this.categoryId,
    required this.productOrderByProductId,
    required this.products,
    super.key,
  });

  /// Whether product tiles can add items to the active table.
  final bool canAddProducts;

  /// Subcategories shown in the current menu.
  final List<ProductCategory> categories;

  /// Current category whose products are shown.
  final String? categoryId;

  /// Local-only product order preferences keyed by product id.
  final Map<String, int> productOrderByProductId;

  /// Products shown in the current menu.
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final columns = _columnsFor(constraints.maxWidth, compact: compact);
        final aspectRatio = _aspectRatioFor(
          constraints.maxWidth,
          columns: columns,
          compact: compact,
        );
        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            childAspectRatio: aspectRatio,
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index < categories.length) {
              return _CategoryTile(
                category: categories[index],
                compact: compact,
              );
            }
            final product = products[index - categories.length];
            if (categoryId == null || products.length < 2) {
              return _ProductTile(
                canAdd: canAddProducts,
                compact: compact,
                product: product,
              );
            }
            return _DraggableProductTile(
              canAdd: canAddProducts,
              categoryId: categoryId!,
              compact: compact,
              product: product,
              products: products,
            );
          },
          itemCount: categories.length + products.length,
        );
      },
    );
  }

  int _columnsFor(double maxWidth, {required bool compact}) {
    const horizontalPadding = 20.0;
    final targetTileWidth = compact ? 190.0 : 300.0;
    final availableWidth = (maxWidth - horizontalPadding).clamp(1.0, maxWidth);
    final minColumns = compact ? 2 : 1;
    return (availableWidth / targetTileWidth).floor().clamp(minColumns, 8);
  }

  double _aspectRatioFor(
    double maxWidth, {
    required int columns,
    required bool compact,
  }) {
    const horizontalPadding = 20.0;
    const spacing = 8.0;
    final availableWidth =
        (maxWidth - horizontalPadding - (columns - 1) * spacing).clamp(
          1.0,
          maxWidth,
        );
    final tileWidth = availableWidth / columns;
    if (!compact) return 2.85;
    final tileHeight = (tileWidth / 2.1).clamp(76.0, 92.0);
    return tileWidth / tileHeight;
  }
}
