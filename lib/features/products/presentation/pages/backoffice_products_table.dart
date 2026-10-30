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
      if (_category != null && !_isInCategory(product.categoryId, _category!)) return false;
      return [
        product.name,
        widget.categoryPathFor(product.categoryId, widget.categories),
      ].join(' ').toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();

    int compareProducts(Product a, Product b) {
      switch (_sortColumn) {
        case 1:
          return widget
              .categoryPathFor(a.categoryId, widget.categories)
              .compareTo(
                widget.categoryPathFor(b.categoryId, widget.categories),
              );
        case 2:
          return a.priceInCents.compareTo(b.priceInCents);
        case 3:
          return (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
        case 4:
          return (a.isAvailableInPos ? 1 : 0).compareTo(
            b.isAvailableInPos ? 1 : 0,
          );
        case 5:
          return (a.tracksInventory ? 1 : 0).compareTo(
            b.tracksInventory ? 1 : 0,
          );
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    filtered.sort((a, b) {
      final comparison = compareProducts(a, b);
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
              Expanded(
                child: Text(
                  'Productos',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo producto'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 380,
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() { _query = value; _page = 0; }),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                              _page = 0;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    isDense: true,
                  ),
                ),
              ),
              _selector('Tipo', _kind, const {
                'all': 'Todos',
                'raw': 'Materia prima',
                'finished': 'Producto terminado',
              }, (value) => setState(() { _kind = value; _page = 0; })),
              _selector('Estado', _status, const {
                'all': 'Todos',
                'active': 'Activos',
                'inactive': 'Inactivos',
              }, (value) => setState(() { _status = value; _page = 0; })),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(_category),
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      child: Text('Todas'),
                    ),
                    for (final category in categories)
                      DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(
                          category.parentId == null
                              ? category.name
                              : widget.categoryPathFor(category.id, widget.categories),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() { _category = value; _page = 0; }),
                ),
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                    _status = 'all';
                    _kind = 'all';
                    _page = 0;
                    _category = null;
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(MoneyFormatter.format(product.priceInCents)),
                          _statusLabel(
                            context,
                            product.isActive
                                ? l10n.activeStatus
                                : l10n.inactiveStatus,
                            product.isActive,
                          ),
                          _statusLabel(
                            context,
                            product.isAvailableInPos ? 'Sí' : 'No',
                            product.isAvailableInPos,
                          ),
                          _statusLabel(
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
              const Text('Filas'),
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

  Widget _selector(
    String label,
    String current,
    Map<String, String> choices,
    ValueChanged<String> changed,
  ) {
    return SizedBox(
      width: 148,
      child: DropdownButtonFormField<String>(
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          for (final option in choices.entries)
            DropdownMenuItem(
              value: option.key,
              child: Text(option.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) changed(value);
        },
      ),
    );
  }

  Widget _statusLabel(BuildContext context, String text, bool active) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F3E5) : const Color(0xFFF8E8E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF286837) : colors.error,
        ),
      ),
    );
  }
}
