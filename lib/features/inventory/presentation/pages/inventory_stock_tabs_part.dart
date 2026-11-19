part of 'inventory_page.dart';

class _InventoryStockTab extends StatelessWidget {
  const _InventoryStockTab({
    required this.future,
    required this.formatDate,
  });

  final Future<AppResult<List<InventoryStockItem>>> future;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<AppResult<List<InventoryStockItem>>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const AppLoadingPage();
        return switch (snapshot.data!) {
          AppFailureResult(:final error) => AppEmptyState(
            icon: Icons.error_outline,
            title: 'Inventario',
            message: error.message,
          ),
          AppSuccess(:final value) when value.isEmpty => AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: l10n.inventoryNoTrackedItemsTitle,
            message: l10n.inventoryNoTrackedItemsMessage,
          ),
          AppSuccess(:final value) => _ProductStockTable(
            items: value,
            formatDate: formatDate,
          ),
        };
      },
    );
  }
}

String _formatStockQuantity(double value, String? unitName) {
  final text = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
  final unit = unitName == null || unitName.isEmpty ? '' : ' $unitName';
  return '$text$unit';
}
