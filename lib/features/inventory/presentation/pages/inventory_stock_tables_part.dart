part of 'inventory_page.dart';

/// Inventory products presented consistently with other Backoffice modules.
class _ProductStockTable extends StatelessWidget {
  const _ProductStockTable({
    required this.items,
    required this.formatDate,
  });

  final List<InventoryStockItem> items;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BackofficeCollectionView<InventoryStockItem>(
      items: items,
      searchLabel: 'Buscar producto, categoría o inventario',
      searchTextFor: (item) => [
        item.productName,
        item.categoryPath ?? '',
        _formatStockQuantity(item.displayQuantity, item.displayUnitName),
        _formatMoney(item.costInCents),
      ].join(' '),
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: (_, item) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                item.productName,
                variant: AppTextVariant.titleMedium,
              ),
              if ((item.categoryPath ?? '').isNotEmpty)
                AppText(item.categoryPath!, variant: AppTextVariant.label),
              AppText(
                'Existencia: ${_formatStockQuantity(
                  item.displayQuantity,
                  item.displayUnitName,
                )}',
              ),
              AppText('Costo: ${_formatMoney(item.costInCents)}'),
              AppText(
                'Actualizado: ${formatDate(item.updatedAt)}',
                variant: AppTextVariant.label,
              ),
            ],
          ),
        ),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Producto',
          width: 310,
          compare: (a, b) => a.productName.compareTo(b.productName),
          cell: (_, item) => Text(item.productName, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Categoría',
          width: 280,
          compare: (a, b) =>
              (a.categoryPath ?? '').compareTo(b.categoryPath ?? ''),
          cell: (_, item) => Text(item.categoryPath ?? '—'),
        ),
        BackofficeListColumn(
          label: 'Existencia',
          width: 175,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.displayQuantity.compareTo(b.displayQuantity),
          cell: (_, item) => Text(
            _formatStockQuantity(item.displayQuantity, item.displayUnitName),
          ),
        ),
        BackofficeListColumn(
          label: 'Costo',
          width: 150,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.costInCents.compareTo(b.costInCents),
          cell: (_, item) => Text(_formatMoney(item.costInCents)),
        ),
        BackofficeListColumn(
          label: 'Actualizado',
          width: 185,
          alignment: Alignment.center,
          compare: (a, b) => a.updatedAt.compareTo(b.updatedAt),
          cell: (_, item) => Text(formatDate(item.updatedAt)),
        ),
      ],
    );
  }
}

/// Packaging stock with the same search, sort and pagination contract.
class _PackagingStockTable extends StatelessWidget {
  const _PackagingStockTable({
    required this.items,
    required this.formatDate,
  });

  final List<PackagingStockItem> items;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BackofficeCollectionView<PackagingStockItem>(
      items: items,
      searchLabel: 'Buscar empaque',
      searchTextFor: (item) =>
          '${item.packagingName} ${item.quantityOnHand} '
          '${_formatMoney(item.costInCents)}',
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: (_, item) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(item.packagingName, variant: AppTextVariant.titleMedium),
              AppText('Existencia: ${item.quantityOnHand}'),
              AppText('Costo: ${_formatMoney(item.costInCents)}'),
              AppText(
                'Actualizado: ${formatDate(item.updatedAt)}',
                variant: AppTextVariant.label,
              ),
            ],
          ),
        ),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Empaque',
          width: 430,
          compare: (a, b) => a.packagingName.compareTo(b.packagingName),
          cell: (_, item) => Text(item.packagingName, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Existencia',
          width: 185,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.quantityOnHand.compareTo(b.quantityOnHand),
          cell: (_, item) => Text('${item.quantityOnHand}'),
        ),
        BackofficeListColumn(
          label: 'Costo',
          width: 175,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.costInCents.compareTo(b.costInCents),
          cell: (_, item) => Text(_formatMoney(item.costInCents)),
        ),
        BackofficeListColumn(
          label: 'Actualizado',
          width: 195,
          alignment: Alignment.center,
          compare: (a, b) => a.updatedAt.compareTo(b.updatedAt),
          cell: (_, item) => Text(formatDate(item.updatedAt)),
        ),
      ],
    );
  }
}
