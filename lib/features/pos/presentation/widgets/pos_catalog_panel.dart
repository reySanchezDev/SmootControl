import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_catalog_tiles.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Product/subcategory band for the selected POS category.
class PosCatalogPanel extends StatelessWidget {
  /// Creates the POS catalog panel.
  const PosCatalogPanel({required this.state, super.key});

  /// Current POS state.
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final activeCategoryId = _activeCategoryId;
    final categories = _categoriesFor(activeCategoryId);
    final products = _productsFor(activeCategoryId);

    if (categories.isEmpty && products.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return AppEmptyState(
        icon: Icons.restaurant_menu_outlined,
        message: l10n.emptyProductsMessage,
        title: l10n.emptyProductsTitle,
      );
    }

    return PosMenuGrid(
      canAddProducts: state.selectedTableId != null,
      categories: categories,
      products: products,
    );
  }

  String? get _activeCategoryId {
    final selected = state.selectedCategoryId;
    if (selected != null && _categoryById(selected) != null) return selected;
    final roots =
        state.categories
            .where((category) => category.isActive && category.parentId == null)
            .toList()
          ..sort(
            (first, second) => first.sortOrder.compareTo(second.sortOrder),
          );
    return roots.isEmpty ? null : roots.first.id;
  }

  List<ProductCategory> _categoriesFor(String? parentId) {
    if (parentId == null) return const [];
    return state.categories.where((category) {
        return category.isActive && category.parentId == parentId;
      }).toList()
      ..sort((first, second) => first.sortOrder.compareTo(second.sortOrder));
  }

  List<Product> _productsFor(String? categoryId) {
    final visibleProducts = state.products.where(_isVisibleProduct).toList();
    if (state.categories.isEmpty) return visibleProducts;
    if (categoryId == null) return const [];
    return visibleProducts
        .where((product) => product.categoryId == categoryId)
        .toList();
  }

  bool _isVisibleProduct(Product product) {
    return product.isActive && product.isAvailableInPos;
  }

  ProductCategory? _categoryById(String id) {
    for (final category in state.categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}
