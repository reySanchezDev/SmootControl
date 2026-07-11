part of 'pos_cash_transactions_page.dart';

class _LocalSaleDetailDialog extends StatelessWidget {
  const _LocalSaleDetailDialog({
    required this.canRetry,
    required this.items,
    required this.onRetry,
    required this.sale,
  });

  final bool canRetry;
  final List<SaleItem> items;
  final Future<void> Function() onRetry;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Detalle ${sale.invoiceNumber}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(
                'Fecha',
                '${_dateText(sale.createdAt)} '
                    '${_timeText(sale.createdAt)}',
              ),
              _DetailRow('Total', MoneyFormatter.format(sale.totalInCents)),
              _DetailRow('Estado sync', _syncStatusText(sale.syncStatus)),
              if (sale.syncStatus == SaleSyncStatus.error) ...[
                const SizedBox(height: 8),
                const AppText(
                  'Esta factura esta guardada en la tablet y pendiente de '
                  'confirmarse en Supabase. El consecutivo remoto final se '
                  'actualiza al sincronizar correctamente.',
                  variant: AppTextVariant.label,
                ),
              ],
              if (sale.syncError?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                const AppText('Error de sincronizacion'),
                const SizedBox(height: 4),
                SelectableText(sale.syncError!),
              ],
              const SizedBox(height: 14),
              const AppText('Productos', variant: AppTextVariant.titleMedium),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const AppText('Esta venta no tiene detalle local registrado.')
              else
                for (final item in items) _DetailItemTile(item: item),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        if (canRetry)
          AppButton(
            icon: Icons.sync,
            label: 'Reintentar',
            onPressed: onRetry,
          ),
      ],
    );
  }

  String _syncStatusText(SaleSyncStatus status) {
    return switch (status) {
      SaleSyncStatus.pending => 'Pendiente',
      SaleSyncStatus.syncing => 'Sincronizando',
      SaleSyncStatus.synced => 'Sincronizado',
      SaleSyncStatus.error => 'Con error',
    };
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: AppText(label, variant: AppTextVariant.label)),
          AppText(value),
        ],
      ),
    );
  }
}

class _DetailItemTile extends StatelessWidget {
  const _DetailItemTile({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final options = item.selectedOptionsLabel?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(item.productName),
                if (options != null && options.isNotEmpty)
                  AppText(options, variant: AppTextVariant.label),
                AppText(
                  '${item.quantity} x '
                  '${MoneyFormatter.format(item.unitPriceInCents)}',
                  variant: AppTextVariant.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppText(
            MoneyFormatter.format(item.totalInCents),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}

String _dateText(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _timeText(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
