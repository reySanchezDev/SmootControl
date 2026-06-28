import 'package:flutter/material.dart';
import 'package:smoo_control/core/responsive/responsive_breakpoints.dart';
import 'package:smoo_control/core/responsive/responsive_builder.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_actions_band.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_catalog_panel.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_category_band.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_tables_band.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ticket_panel.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';

/// Ready state content for the POS page.
class PosReadyView extends StatefulWidget {
  /// Creates the ready POS view.
  const PosReadyView({required this.state, super.key});

  /// Current POS ready state.
  final PosReady state;

  @override
  State<PosReadyView> createState() => _PosReadyViewState();
}

class _PosReadyViewState extends State<PosReadyView> {
  static const _actionsHeight = 78.0;
  static const _categoryHeight = 82.0;
  static const _tableHeight = 84.0;

  String? _paymentParentKey;
  bool _productsVisible = true;

  @override
  void didUpdateWidget(covariant PosReadyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final completedSaleChanged =
        oldWidget.state.lastCompletedSale?.id !=
        widget.state.lastCompletedSale?.id;
    if (completedSaleChanged && widget.state.lastCompletedSale != null) {
      _paymentParentKey = null;
    }
    final categoryChanged =
        oldWidget.state.selectedCategoryId != widget.state.selectedCategoryId;
    if (categoryChanged && !_productsVisible) {
      _productsVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size) {
        final isMobile = size == ResponsiveSize.mobile;
        final catalog = PosCatalogPanel(state: widget.state);
        final ticket = PosTicketPanel(
          lines: widget.state.cartLines,
          onProductsVisibilityToggled: () {
            setState(() => _productsVisible = !_productsVisible);
          },
          productsVisible: _productsVisible,
        );
        final categoryBand = PosCategoryBand(
          onCategorySelected: _showProducts,
          state: widget.state,
        );
        final tableBand = PosTablesBand(state: widget.state);
        final actionsBand = PosActionsBand(
          onPaymentParentChanged: (parentKey) {
            setState(() => _paymentParentKey = parentKey);
          },
          paymentParentKey: _paymentParentKey,
          state: widget.state,
        );

        if (isMobile) {
          return ListView(
            padding: const EdgeInsets.all(10),
            children: [
              SizedBox(height: _productsVisible ? 260 : 520, child: ticket),
              if (_productsVisible) ...[
                const SizedBox(height: 10),
                SizedBox(height: 420, child: catalog),
                const SizedBox(height: 10),
              ],
              SizedBox(height: 130, child: categoryBand),
              const SizedBox(height: 10),
              SizedBox(height: 96, child: tableBand),
              const SizedBox(height: 10),
              SizedBox(height: 360, child: actionsBand),
            ],
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final catalogHeight = _catalogHeight(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return Column(
              children: [
                Expanded(child: ticket),
                if (_productsVisible) ...[
                  const Divider(height: 1),
                  SizedBox(height: catalogHeight, child: catalog),
                ],
                const Divider(height: 1),
                SizedBox(height: _categoryHeight, child: categoryBand),
                const Divider(height: 1),
                SizedBox(height: _tableHeight, child: tableBand),
                const Divider(height: 1),
                SizedBox(height: _actionsHeight, child: actionsBand),
              ],
            );
          },
        );
      },
    );
  }

  void _showProducts() {
    if (_productsVisible) return;
    setState(() => _productsVisible = true);
  }

  double _catalogHeight(double width, double availableHeight) {
    final itemCount = _visibleCatalogItemCount();
    final rows = _catalogRows(width, itemCount);
    final spacingCount = rows > 1 ? rows - 1 : 0;
    final desiredHeight = 16 + rows * 112 + spacingCount * 8;
    final maximumHeight = (availableHeight * .32).clamp(132, 260).toDouble();
    return desiredHeight.clamp(124, maximumHeight).toDouble();
  }

  int _catalogRows(double width, int itemCount) {
    if (itemCount <= 0) return 1;
    final maxTileWidth = width < 520 ? 190 : 300;
    final columns = (width / maxTileWidth).floor().clamp(1, itemCount);
    return (itemCount / columns).ceil();
  }

  int _visibleCatalogItemCount() {
    final categoryId = _activeCategoryId();
    return _categoriesFor(categoryId).length + _productsFor(categoryId);
  }

  String? _activeCategoryId() {
    final selected = widget.state.selectedCategoryId;
    if (selected != null && _categoryById(selected) != null) return selected;

    final roots = widget.state.categories.where(_isRootCategory).toList()
      ..sort(_sortCategories);
    return roots.isEmpty ? null : roots.first.id;
  }

  List<ProductCategory> _categoriesFor(String? parentId) {
    if (parentId == null) return const [];
    return widget.state.categories.where((category) {
      return category.isActive && category.parentId == parentId;
    }).toList()..sort(_sortCategories);
  }

  int _productsFor(String? categoryId) {
    if (widget.state.categories.isEmpty) {
      return widget.state.products.where(_isVisibleProduct).length;
    }
    if (categoryId == null) return 0;
    return widget.state.products.where((product) {
      return _isVisibleProduct(product) && product.categoryId == categoryId;
    }).length;
  }

  ProductCategory? _categoryById(String id) {
    for (final category in widget.state.categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  bool _isRootCategory(ProductCategory category) {
    return category.isActive && category.parentId == null;
  }

  bool _isVisibleProduct(Product product) {
    return product.isActive && product.isAvailableInPos;
  }

  int _sortCategories(ProductCategory first, ProductCategory second) {
    return first.sortOrder.compareTo(second.sortOrder);
  }
}
