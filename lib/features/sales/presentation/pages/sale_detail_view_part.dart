part of 'sale_detail_page.dart';

class _SaleDetailView extends StatelessWidget {
  const _SaleDetailView({required this.data, required this.sale});

  final _SaleDetailData data;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return ListView(
          padding: EdgeInsets.all(compact ? 12 : 20),
          children: [
            _HeaderSection(
              sale: sale,
              paymentMethodName: data.paymentMethodName,
            ),
            const SizedBox(height: 14),
            _LinesSection(items: data.items),
            const SizedBox(height: 14),
            _TotalsSection(sale: sale, items: data.items),
          ],
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.paymentMethodName,
    required this.sale,
  });

  final String paymentMethodName;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = switch (sale.status) {
      SaleStatus.completed => l10n.saleStatusCompleted,
      SaleStatus.voided => l10n.saleStatusVoided,
    };

    return _SectionSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 820 ? 4 : 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(sale.invoiceNumber, variant: AppTextVariant.titleMedium),
              const SizedBox(height: 12),
              _InfoGrid(
                columns: columns,
                entries: [
                  _InfoEntry('Estado', status),
                  _InfoEntry('Fecha', _formatDate(sale.createdAt)),
                  _InfoEntry('Hora', _formatTime(sale.createdAt)),
                  _InfoEntry(
                    'Tipo de venta',
                    sale.salesTypeName ?? 'No definido',
                  ),
                  _InfoEntry('Metodo de pago', paymentMethodName),
                  if (sale.paymentReference != null)
                    _InfoEntry('Referencia', sale.paymentReference!),
                  if (sale.tableId != null) _InfoEntry('Mesa', sale.tableId!),
                  if (sale.cashRegisterSessionId != null)
                    _InfoEntry('Caja', sale.cashRegisterSessionId!),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
