part of 'products_page.dart';

/// Responsive real-product catalog using the shared selection toolbar.
class _BackofficeProductsCompactList extends StatelessWidget {
  const _BackofficeProductsCompactList({
    required this.products,
    required this.categories,
    required this.categoryPathFor,
    required this.onCreate,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Product> products;
  final List<ProductCategory> categories;
  final String Function(String, List<ProductCategory>) categoryPathFor;
  final VoidCallback onCreate;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String categoryFor(Product item) =>
        categoryPathFor(item.categoryId, categories);

    return BackofficeCollectionView<Product>(
      items: products,
      onCreate: onCreate,
      rowKey: (product) => product.id,
      rowLabel: (product) => product.name,
      selectionActions: [
        BackofficeSelectionAction(
          label: l10n.editAction,
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        BackofficeSelectionAction(
          label: l10n.deactivateAction,
          icon: Icons.toggle_off_outlined,
          enabledWhen: (product) => product.isActive,
          onPressed: onDeactivate,
          destructive: true,
        ),
      ],
      searchLabel: 'Buscar producto, categoría, precio o estado',
      searchTextFor: (product) => [
        product.name,
        categoryFor(product),
        MoneyFormatter.format(product.priceInCents),
        if (product.isActive) l10n.activeStatus else l10n.inactiveStatus,
        if (product.isAvailableInPos) 'POS' else 'Sin POS',
      ].join(' '),
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: (_, product) => _ProductTile(
        categoryPath: categoryFor(product),
        product: product,
        selectionMode: true,
        onEdit: () => onEdit(product),
        onDeactivate: () => onDeactivate(product),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Producto',
          width: 300,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, product) => Text(product.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Categoría',
          width: 285,
          compare: (a, b) => categoryFor(a).compareTo(categoryFor(b)),
          cell: (_, product) => Text(categoryFor(product), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Precio',
          width: 150,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.priceInCents.compareTo(b.priceInCents),
          cell: (_, product) =>
              Text(MoneyFormatter.format(product.priceInCents)),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 145,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
          cell: (_, product) =>
              Text(product.isActive ? l10n.activeStatus : l10n.inactiveStatus),
        ),
        BackofficeListColumn(
          label: 'POS',
          width: 135,
          alignment: Alignment.center,
          compare: (a, b) => (a.isAvailableInPos ? 1 : 0)
              .compareTo(b.isAvailableInPos ? 1 : 0),
          cell: (_, product) =>
              Text(product.isAvailableInPos ? 'Sí' : 'No'),
        ),
      ],
    );
  }
}
