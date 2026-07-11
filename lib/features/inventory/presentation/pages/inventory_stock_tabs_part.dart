part of 'inventory_page.dart';

class _ProductStockTab extends StatelessWidget {
  const _ProductStockTab({
    required this.future,
    required this.formatDate,
  });

  final Future<AppResult<List<InventoryStockItem>>> future;
  final String Function(DateTime value) formatDate;

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
            message:
                'Activa "Controla inventario" en productos para gestionar '
                'stock.',
          ),
          AppSuccess(:final value) => _StockList(
            itemCount: value.length,
            itemBuilder: (context, index) {
              final item = value[index];
              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: AppText(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: AppText(
                  [
                    if ((item.categoryPath ?? '').isNotEmpty)
                      item.categoryPath!,
                    'Costo: ${_formatMoney(item.costInCents)}',
                    'Actualizado: ${formatDate(item.updatedAt)}',
                  ].join(' - '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  variant: AppTextVariant.label,
                ),
                trailing: AppText(
                  item.quantityOnHand.toString(),
                  variant: AppTextVariant.titleMedium,
                ),
              );
            },
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
  final String Function(DateTime value) formatDate;

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
          AppSuccess(:final value) => _StockList(
            itemCount: value.length,
            itemBuilder: (context, index) {
              final item = value[index];
              return ListTile(
                leading: const Icon(Icons.takeout_dining_outlined),
                title: AppText(
                  item.packagingName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: AppText(
                  [
                    'Costo: ${_formatMoney(item.costInCents)}',
                    'Actualizado: ${formatDate(item.updatedAt)}',
                  ].join(' - '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  variant: AppTextVariant.label,
                ),
                trailing: AppText(
                  item.quantityOnHand.toString(),
                  variant: AppTextVariant.titleMedium,
                ),
              );
            },
          ),
        };
      },
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({
    required this.itemBuilder,
    required this.itemCount,
  });

  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: itemBuilder,
    );
  }
}
