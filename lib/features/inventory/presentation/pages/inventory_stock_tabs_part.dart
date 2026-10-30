part of 'inventory_page.dart';

class _ProductStockTab extends StatelessWidget {
  const _ProductStockTab({
    required this.future,
    required this.formatDate,
  });

  final Future<AppResult<List<InventoryStockItem>>> future;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
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
          AppSuccess(:final value) when value.isEmpty => const AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Sin productos con inventario',
            message: 'Activa «Controla inventario» para gestionar stock.',
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

class _PackagingStockTab extends StatelessWidget {
  const _PackagingStockTab({
    required this.future,
    required this.formatDate,
  });

  final Future<AppResult<List<PackagingStockItem>>> future;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppResult<List<PackagingStockItem>>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const AppLoadingPage();
        return switch (snapshot.data!) {
          AppFailureResult(:final error) => AppEmptyState(
            icon: Icons.error_outline,
            title: 'Empaques',
            message: error.message,
          ),
          AppSuccess(:final value) when value.isEmpty => const AppEmptyState(
            icon: Icons.takeout_dining_outlined,
            title: 'Sin empaques',
            message: 'Crea empaques activos para gestionar su stock.',
          ),
          AppSuccess(:final value) => _PackagingStockTable(
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
