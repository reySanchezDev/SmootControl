part of 'products_page.dart';

/// Desktop-first products grid; existing dialogs and BLoC remain authoritative.
class _BackofficeProductsTable extends StatefulWidget {
  const _BackofficeProductsTable({
    required this.products,
    required this.categories,
    required this.onEdit,
    required this.onDeactivate,
    required this.categoryPathFor,
  });

  final List<Product> products;
  final List<ProductCategory> categories;
  final String Function(String, List<ProductCategory>) categoryPathFor;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDeactivate;

  @override
  State<_BackofficeProductsTable> createState() =>
      _BackofficeProductsTableState();
}

class _BackofficeProductsTableState extends State<_BackofficeProductsTable> {
  String _query = '';
  bool _activeOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = widget.products.where((product) {
      if (_activeOnly && !product.isActive) return false;
      final haystack = [
        product.name,
        widget.categoryPathFor(product.categoryId, widget.categories),
      ].join(' ').toLowerCase();
      return haystack.contains(_query.trim().toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: l10n.searchField,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              FilterChip(
                label: Text(l10n.activeStatus),
                selected: _activeOnly,
                onSelected: (value) => setState(() => _activeOnly = value),
              ),
              Text(
                '${filtered.length} / ${widget.products.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(l10n.emptySearchMessage))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    BackofficeDataTable(
                      columns: const [
                        'Producto', 'Categoría', 'Precio',
                        'Estado', 'POS', 'Inventario', 'Acciones',
                      ],
                      rows: [
                        for (final product in filtered)
                          [
                            Text(product.name,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                widget.categoryPathFor(
                                  product.categoryId, widget.categories),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(MoneyFormatter.format(product.priceInCents)),
                            Text(product.isActive
                                ? l10n.activeStatus : l10n.inactiveStatus),
                            Icon(
                              product.isAvailableInPos
                                  ? Icons.check_circle_outline
                                  : Icons.remove_circle_outline,
                              color: product.isAvailableInPos
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            Icon(product.tracksInventory
                                ? Icons.inventory_2_outlined
                                : Icons.horizontal_rule_rounded),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: l10n.editAction,
                                  onPressed: () => widget.onEdit(product),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                if (product.isActive)
                                  IconButton(
                                    tooltip: l10n.deactivateAction,
                                    onPressed: () => widget.onDeactivate(product),
                                    icon: Icon(Icons.block_outlined,
                                      color: Theme.of(context).colorScheme.error),
                                  ),
                              ],
                            ),
                          ],
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
