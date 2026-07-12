part of 'pos_state.dart';

/// Derived values and lookup helpers for a ready POS state.
extension PosReadyDerivedState on PosReady {
  /// Current ticket total in cents.
  int get totalInCents {
    return cartLines.fold(0, (total, line) => total + line.totalInCents);
  }

  /// Internal key used to store the active cart.
  String get activeCartKey => selectedTableId ?? '__no_table__';

  /// Selected sales type for the active order.
  SalesType? get selectedSalesType {
    final selectedId =
        selectedSalesTypeId ?? salesTypeIdByOrderKey[activeCartKey];
    for (final type in salesTypes) {
      if (type.id == selectedId) return type;
    }
    for (final type in salesTypes) {
      if (type.isDefault && type.isActive) return type;
    }
    for (final type in salesTypes) {
      if (type.isActive) return type;
    }
    return null;
  }

  /// Whether the current cart was separated into named accounts.
  bool get hasSplitAccounts => splitAccounts.isNotEmpty;

  /// Unit-level draft items used by the split-account flow.
  List<SaleItemDraft> get splitDraftItems {
    final items = <SaleItemDraft>[];
    for (final line in cartLines) {
      for (var index = 0; index < line.quantity; index += 1) {
        final itemId = '${line.lineKey}-$index';
        items.add(
          SaleItemDraft(
            id: itemId,
            productId: line.product.id,
            productName: line.product.name,
            selectedOptionsLabel: line.selectedOptionsLabel.isEmpty
                ? null
                : line.selectedOptionsLabel,
            quantity: 1,
            unitPriceInCents: line.product.priceInCents,
          ),
        );
      }
    }
    return items;
  }

  /// Current selected category.
  ProductCategory? get selectedCategory {
    for (final category in categories) {
      if (category.id == selectedCategoryId) {
        return category;
      }
    }
    return null;
  }

  /// Parent category identifier used by the POS back action.
  String? get parentCategoryId => selectedCategory?.parentId;

  /// Categories visible at the current navigation level.
  List<ProductCategory> get visibleCategories {
    final visible =
        categories
            .where(
              (category) =>
                  category.isActive && category.parentId == selectedCategoryId,
            )
            .toList()
          ..sort(
            (first, second) => first.sortOrder.compareTo(second.sortOrder),
          );
    return visible;
  }

  /// Products visible at the current navigation level.
  List<Product> get visibleProducts {
    final activeProducts = products.where((product) {
      return product.isActive && product.isAvailableInPos;
    });
    if (categories.isEmpty) {
      return activeProducts.toList();
    }
    if (selectedCategoryId == null) {
      return const [];
    }
    return activeProducts
        .where((product) => product.categoryId == selectedCategoryId)
        .toList();
  }

  /// Resolves reusable and legacy option groups for one product.
  List<ProductOptionGroup> optionGroupsFor(Product product) {
    return PosOptionGroupResolver.resolve(
      product: product,
      modifierCatalog: modifierCatalog,
    );
  }

  /// Returns selected payment method.
  PaymentMethod? get selectedPaymentMethod {
    for (final method in paymentMethods) {
      if (method.id == selectedPaymentMethodId) {
        return method;
      }
    }
    return null;
  }

  /// Returns selected table.
  RestaurantTable? get selectedTable {
    for (final table in tables) {
      if (table.id == selectedTableId) {
        return table;
      }
    }
    return null;
  }
}
