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
  State<_BackofficeProductsTable> createState() => _BackofficeProductsTableState();
}

class _BackofficeProductsTableState extends State<_BackofficeProductsTable>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String _query = '';
  String _status = 'all';
  String _pos = 'all';
  String _inventory = 'all';
  String? _category;

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
      if (_pos == 'yes' && !product.isAvailableInPos) return false;
      if (_pos == 'no' && product.isAvailableInPos) return false;
      if (_inventory == 'yes' && !product.tracksInventory) return false;
      if (_inventory == 'no' && product.tracksInventory) return false;
      if (_category != null && product.categoryId != _category) return false;
      return [
        product.name,
        widget.categoryPathFor(product.categoryId, widget.categories),
      ].join(' ').toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();

    final active = widget.products.where((p) => p.isActive).length;
    final available = widget.products.where((p) => p.isAvailableInPos).length;
    final tracked = widget.products.where((p) => p.tracksInventory).length;
    final hasFilters = _query.isNotEmpty || _status != 'all' ||
        _pos != 'all' || _inventory != 'all' || _category != null;
    final categories = widget.categories.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Productos', style: theme.textTheme.headlineSmall),
              ),
              FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo producto'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric(context, 'Total', widget.products.length),
              _metric(context, 'Activos', active),
              _metric(context, 'En POS', available),
              _metric(context, 'Con inventario', tracked),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty ? null : IconButton(
                      tooltip: 'Borrar búsqueda',
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              _selector('Estado', _status, const {
                'all': 'Todos', 'active': 'Activos', 'inactive': 'Inactivos',
              }, (value) => setState(() => _status = value)),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría', isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null, child: Text('Todas'),
                    ),
                    for (final category in categories)
                      DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
              ),
              _selector('POS', _pos, const {
                'all': 'Todos', 'yes': 'Disponible', 'no': 'No disponible',
              }, (value) => setState(() => _pos = value)),
              _selector('Inventario', _inventory, const {
                'all': 'Todos', 'yes': 'Controla', 'no': 'No controla',
              }, (value) => setState(() => _inventory = value)),
              if (hasFilters)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                    _status = 'all';
                    _pos = 'all';
                    _inventory = 'all';
                    _category = null;
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${filtered.length} de ${widget.products.length} productos',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(l10n.emptySearchMessage))
                : BackofficeDataTable(
                    columns: const [
                      'Producto', 'Categoría', 'Precio',
                      'Estado', 'POS', 'Inventario', 'Acciones',
                    ],
                    columnWidths: const [240, 200, 110, 110, 130, 135, 125],
                    rows: [
                      for (final product in filtered)
                        [
                          Text(product.name,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                          Tooltip(
                            message: widget.categoryPathFor(
                              product.categoryId, widget.categories),
                            child: Text(widget.categoryPathFor(
                              product.categoryId, widget.categories),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          Text(MoneyFormatter.format(product.priceInCents)),
                          _statusLabel(context, product.isActive
                              ? l10n.activeStatus : l10n.inactiveStatus,
                              product.isActive),
                          Text(product.isAvailableInPos ? 'Sí' : 'No'),
                          Text(product.tracksInventory ? 'Sí' : 'No'),
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
                                  icon: Icon(Icons.block_outlined, size: 19,
                                    color: theme.colorScheme.error),
                                ),
                            ],
                          ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, int value) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 126),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: 2),
          Text('$value', style: textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _selector(String label, String current,
      Map<String, String> choices, ValueChanged<String> changed) {
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
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: active ? colors.primary : colors.onSurfaceVariant,
      ),
    );
  }
}
