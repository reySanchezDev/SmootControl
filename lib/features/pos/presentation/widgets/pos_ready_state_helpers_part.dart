part of 'pos_ready_view.dart';

extension _PosReadyViewStateHelpers on _PosReadyViewState {
  Widget _buildCompactScrollContent({
    required Widget actionsBand,
    required Widget catalog,
    required Widget categoryBand,
    required bool includeActions,
    required bool includeCategories,
    required bool includeTables,
    required PosResponsiveLayout layout,
    required bool phoneLayout,
    required Widget tableBand,
    required Widget ticket,
    required double contentHeight,
  }) {
    final ticketHeight = layout.ticketHeight(
      lineCount: widget.state.cartLines.length,
      productsVisible: _productsVisible,
    );
    final catalogHeight = _productsVisible
        ? layout.catalogHeight(_visibleCatalogItemCount())
        : 0.0;
    final categoryHeight = layout.categoryBandHeight(
      _visibleRootCategoryCount(),
    );
    final tableHeight = phoneLayout
        ? 68.0
        : layout.tableBandHeight(_visibleTableEntryCount());
    final renderedCategoryHeight = includeCategories ? categoryHeight : 0.0;
    final renderedTableHeight = includeTables ? tableHeight : 0.0;
    final actionsHeight = includeActions ? layout.actionsHeight() : 0.0;
    final gapCount =
        (_productsVisible ? 2 : 0) +
        (includeCategories ? 1 : 0) +
        (includeTables ? 1 : 0) +
        (includeActions ? 1 : 0);
    final gapHeight = gapCount * 10.0;
    final naturalHeight =
        ticketHeight +
        catalogHeight +
        renderedCategoryHeight +
        renderedTableHeight +
        actionsHeight +
        gapHeight;
    final verticalPadding = phoneLayout ? 10.0 : 20.0;
    final availableContentHeight = (contentHeight - verticalPadding).clamp(
      0.0,
      double.infinity,
    );
    final expandedTicketHeight = naturalHeight < availableContentHeight
        ? ticketHeight + (availableContentHeight - naturalHeight)
        : ticketHeight;

    return ListView(
      key: const ValueKey('pos-compact-scroll'),
      padding: EdgeInsets.fromLTRB(10, 10, 10, phoneLayout ? 0 : 10),
      children: [
        SizedBox(height: expandedTicketHeight, child: ticket),
        if (_productsVisible) ...[
          const SizedBox(height: 10),
          SizedBox(height: catalogHeight, child: catalog),
          const SizedBox(height: 10),
        ],
        if (includeCategories)
          SizedBox(height: categoryHeight, child: categoryBand),
        if (includeTables) ...[
          const SizedBox(height: 10),
          SizedBox(height: tableHeight, child: tableBand),
        ],
        if (includeActions) ...[
          const SizedBox(height: 10),
          SizedBox(height: actionsHeight, child: actionsBand),
        ],
      ],
    );
  }

  int _visibleCatalogItemCount() {
    final categoryId = _activeCategoryId();
    return _categoriesFor(categoryId).length + _productsFor(categoryId);
  }

  int _visibleTableEntryCount() {
    final splitAccountCount = widget.state.splitAccountsByTable.values.fold(
      0,
      (sum, accounts) => sum + accounts.length,
    );
    return widget.state.tables.length + splitAccountCount;
  }

  int _visibleRootCategoryCount() {
    return widget.state.categories.where(_isRootCategory).length;
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
