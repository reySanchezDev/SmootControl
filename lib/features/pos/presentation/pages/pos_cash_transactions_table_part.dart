part of 'pos_cash_transactions_page.dart';

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({
    required this.canRunManualSync,
    required this.onOpenDetails,
    required this.onRetry,
    required this.sales,
    required this.paymentMethods,
  });

  final bool canRunManualSync;
  final ValueChanged<Sale> onOpenDetails;
  final Future<void> Function() onRetry;
  final List<Sale> sales;
  final Map<String, String> paymentMethods;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return ListView.separated(
            itemBuilder: (context, index) {
              final sale = sales[index];
              return _TransactionCard(
                canRetry: canRunManualSync,
                methodName: paymentMethods[sale.paymentMethodId] ?? '',
                onOpenDetails: () => onOpenDetails(sale),
                onRetry: onRetry,
                sale: sale,
              );
            },
            itemCount: sales.length,
            padding: const EdgeInsets.all(10),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SizedBox(
              width: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
              child: Column(
                children: [
                  _TransactionsHeader(background: colorScheme.primaryContainer),
                  Expanded(
                    child: ListView.builder(
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        return _TransactionRow(
                          canRetry: canRunManualSync,
                          methodName:
                              paymentMethods[sale.paymentMethodId] ?? '',
                          onOpenDetails: () => onOpenDetails(sale),
                          onRetry: onRetry,
                          sale: sale,
                        );
                      },
                      itemCount: sales.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransactionsHeader extends StatelessWidget {
  const _TransactionsHeader({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
        child: const Row(
          children: [
            _HeaderCell('Factura', flex: 18),
            _HeaderCell('Fecha', flex: 14),
            _HeaderCell('Hora', flex: 10),
            _HeaderCell('Metodo', flex: 18),
            _HeaderCell('Estado', flex: 18),
            _HeaderCell('Monto', flex: 14, textAlign: TextAlign.right),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.canRetry,
    required this.methodName,
    required this.onOpenDetails,
    required this.onRetry,
    required this.sale,
  });

  final bool canRetry;
  final String methodName;
  final VoidCallback onOpenDetails;
  final Future<void> Function() onRetry;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      sale.invoiceNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      variant: AppTextVariant.titleMedium,
                    ),
                  ),
                  AppText(
                    MoneyFormatter.format(sale.totalInCents),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    variant: AppTextVariant.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                spacing: 12,
                children: [
                  AppText(
                    '${_dateText(sale.createdAt)} '
                    '${_timeText(sale.createdAt)}',
                    variant: AppTextVariant.label,
                  ),
                  AppText(methodName, variant: AppTextVariant.label),
                  _SyncStatusChip(status: sale.syncStatus),
                ],
              ),
              if (sale.syncStatus == SaleSyncStatus.error &&
                  (sale.syncError?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 8),
                AppText(
                  sale.syncError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  variant: AppTextVariant.label,
                ),
              ],
              if (canRetry && sale.syncStatus == SaleSyncStatus.error) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    icon: Icons.sync,
                    label: 'Reintentar',
                    onPressed: onRetry,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.canRetry,
    required this.methodName,
    required this.onOpenDetails,
    required this.onRetry,
    required this.sale,
  });

  final bool canRetry;
  final String methodName;
  final VoidCallback onOpenDetails;
  final Future<void> Function() onRetry;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onOpenDetails,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _BodyCell(sale.invoiceNumber, flex: 18),
              _BodyCell(_dateText(sale.createdAt), flex: 14),
              _BodyCell(_timeText(sale.createdAt), flex: 10),
              _BodyCell(methodName, flex: 18),
              Expanded(
                flex: 18,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SyncStatusChip(status: sale.syncStatus),
                ),
              ),
              _BodyCell(
                MoneyFormatter.format(sale.totalInCents),
                flex: 14,
                textAlign: TextAlign.right,
              ),
              if (canRetry && sale.syncStatus == SaleSyncStatus.error)
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Reintentar',
                  onPressed: () => unawaited(onRetry()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
