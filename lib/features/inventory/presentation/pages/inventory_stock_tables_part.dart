part of 'inventory_page.dart';

/// All tracked canonical items presented in one inventory collection.
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
      searchLabel: l10n.inventoryItemsSearchLabel,
      searchTextFor: (item) => [
        item.productName,
        _itemClassLabel(l10n, item.itemClass),
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
              AppText(
                _itemClassLabel(l10n, item.itemClass),
                variant: AppTextVariant.label,
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
          label: l10n.inventoryItemColumn,
          width: 310,
          compare: (a, b) => a.productName.compareTo(b.productName),
          cell: (_, item) => Text(item.productName, softWrap: true),
        ),
        BackofficeListColumn(
          label: l10n.inventoryItemClassColumn,
          width: 170,
          compare: (a, b) => a.itemClass.compareTo(b.itemClass),
          cell: (_, item) => Text(_itemClassLabel(l10n, item.itemClass)),
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

String _itemClassLabel(AppLocalizations l10n, String itemClass) =>
    switch (itemClass) {
      'raw_material' => l10n.inventoryItemClassRawMaterial,
      'packaging' => l10n.inventoryItemClassPackaging,
      'service' => l10n.inventoryItemClassService,
      _ => l10n.inventoryItemClassSaleProduct,
    };
