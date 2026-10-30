part of 'products_page.dart';

/// Desktop product management, using the existing product BLoC and actions.
class _BackofficeProductsTable extends StatefulWidget {
  const _BackofficeProductsTable({
    required this.products,
    required this.categories,
    required this.onEdit,
    required this.onDeactivate,
    required this.categoryPathFor,
    required this.onCreate,
  });

  final List<Product> products;
  final List<ProductCategory> categories;
  final String Function(String, List<ProductCategory>) categoryPathFor;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDeactivate;
  final VoidCallback onCreate;

  @override
  State<_BackofficeProductsTable> createState() =>
      _BackofficeProductsTableState();
}

class _BackofficeProductsTableState extends State<_BackofficeProductsTable>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String _query = '';
  String _status = 'all';
  String _kind = 'all';
  String? _category;
  int _page = 0;
  int _pageSize = 15;
  int _sortColumn = 0;
  bool _sortAscending = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final filtered = widget.products.where((product) {
      if (_status == 'active' && !product.isActive) return false;
      if (_status == 'inactive' && product.isActive) return false;
      if (_kind == 'raw' && !product.isRawMaterial) return false;
      if (_kind == 'finished' && product.isRawMaterial) return false;
      if (_category != null && !_isInCategory(product.categoryId, _category!)) {
        return false;
      }
      return [
        product.name,
        widget.categoryPathFor(product.categoryId, widget.categories),
        MoneyFormatter.format(product.priceInCents),
        product.isRawMaterial ? 'materia prima' : 'producto terminado',
        product.isActive ? 'activo' : 'inactivo',
        product.isAvailableInPos ? 'pos sí' : 'pos no',
        product.tracksInventory ? 'inventario sí' : 'inventario no',
      ].join(' ').toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final comparison = _compareProducts(
        a, b, _sortColumn, widget.categoryPathFor, widget.categories,
      );
      return _sortAscending ? comparison : -comparison;
    });

    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList();
    final hasFilters =
        _query.isNotEmpty ||
        _status != 'all' ||
        _kind != 'all' ||
        _category != null;
    final categories = widget.categories.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [

              FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProductsFilterBar(
            searchController: _search,
            query: _query,
            status: _status,
            kind: _kind,
            category: _category,
            categories: categories,
            categoryPathFor: widget.categoryPathFor,
            onQueryChanged: (v) => setState(() { _query = v; _page = 0; }),
            onKindChanged: (v) => setState(() { _kind = v; _page = 0; }),
            onStatusChanged: (v) => setState(() { _status = v; _page = 0; }),
            onCategoryChanged: (v) =>
                setState(() { _category = v; _page = 0; }),
            onClear: () => setState(() {
              _search.clear();
              _query = '';
              _status = 'all';
              _kind = 'all';
              _category = null;
              _page = 0;
            }),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(l10n.emptySearchMessage))
                : BackofficeDataTable(
                    columns: const [
                      'Producto',
                      'Categoría',
                      'Precio',
                      'Estado',
                      'POS',
                      'Inventario',
                      'Acciones',
                    ],
                    columnWidths: const [280, 230, 120, 110, 95, 125, 112],
                    columnAlignments: const [
                      Alignment.centerLeft,
                      Alignment.centerLeft,
                      Alignment.centerRight,
                      Alignment.center,
                      Alignment.center,
                      Alignment.center,
                      Alignment.center,
                    ],
                    sortColumnIndex: _sortColumn,
                    sortAscending: _sortAscending,
                    onSort: (index) {
                      if (index == 6) return;
                      setState(() {
                        if (_sortColumn == index) {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortColumn = index;
                          _sortAscending = true;
                        }
                        _page = 0;
                      });
                    },
                    rows: [
                      for (final product in visible)
                        [
                          Text(
                            product.name,
                            softWrap: true,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Tooltip(
                            message: widget.categoryPathFor(
                              product.categoryId,
                              widget.categories,
                            ),
                            child: Text(
                              widget.categoryPathFor(
                                product.categoryId,
                                widget.categories,
                              ),
                              softWrap: true,
                            ),
                          ),
                          Text(MoneyFormatter.format(product.priceInCents)),
                          _productStatusLabel(
                            context,
                            product.isActive
                                ? l10n.activeStatus
                                : l10n.inactiveStatus,
                            product.isActive,
                          ),
                          _productStatusLabel(
                            context,
                            product.isAvailableInPos ? 'Sí' : 'No',
                            product.isAvailableInPos,
                          ),
                          _productStatusLabel(
                            context,
                            product.tracksInventory ? 'Sí' : 'No',
                            product.tracksInventory,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.editAction,
                                onPressed: () => widget.onEdit(product),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                              ),
                              if (product.isActive)
                                IconButton(
                                  tooltip: l10n.deactivateAction,
                                  onPressed: () => widget.onDeactivate(product),
                                  icon: Icon(
                                    Icons.block_outlined,
                                    size: 19,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ],
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Registros por página'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _pageSize,
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 15, child: Text('15')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _pageSize = value;
                      _page = 0;
                    });
                  }
                },
              ),
              const Spacer(),
              Text(
                '${filtered.isEmpty ? 0 : start + 1}–'
                '${start + visible.length} de ${filtered.length}',
              ),
              IconButton(
                tooltip: 'Página anterior',
                onPressed: page > 0
                    ? () => setState(() => _page = page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page + 1} / $pageCount'),
              IconButton(
                tooltip: 'Página siguiente',
                onPressed: page + 1 < pageCount
                    ? () => setState(() => _page = page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isInCategory(String productCategoryId, String selectedId) {
    final categoriesById = <String, ProductCategory>{
      for (final category in widget.categories) category.id: category,
    };
    String? current = productCategoryId;
    final visited = <String>{};
    while (current != null && visited.add(current)) {
      if (current == selectedId) return true;
      current = categoriesById[current]?.parentId;
    }
    return false;
  }

}
