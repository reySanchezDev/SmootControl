part of 'reports_page.dart';

class _ProductPerformanceView extends StatelessWidget {
  const _ProductPerformanceView({required this.report});

  final ProductPerformanceReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.restaurant_menu_outlined,
        title: 'Sin ventas',
        message: 'No hay productos vendidos en el rango seleccionado.',
      );
    }
    return Column(
      children: [
        _ProductPerformanceSummary(report: report),
        const SizedBox(height: 12),
        _ProductPerformanceAdvice(report: report),
        const SizedBox(height: 12),
        for (final row in report.rows) _ProductPerformanceCard(row: row),
      ],
    );
  }
}

class _ProductPerformanceSummary extends StatelessWidget {
  const _ProductPerformanceSummary({required this.report});

  final ProductPerformanceReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _ProductHighlight(
              label: 'Mas vendido',
              row: report.bestSeller,
              value: _quantityLabel(report.bestSeller?.quantitySold ?? 0),
            ),
            const Divider(),
            _ProductHighlight(
              label: 'Mas rentable',
              row: report.mostProfitable,
              value: MoneyFormatter.format(
                report.mostProfitable?.grossProfitInCents ?? 0,
              ),
            ),
            const Divider(),
            _ProductHighlight(
              label: 'Mejor margen',
              row: report.bestMargin,
              value: _percent(report.bestMargin?.margin ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPerformanceAdvice extends StatelessWidget {
  const _ProductPerformanceAdvice({required this.report});

  final ProductPerformanceReport report;

  @override
  Widget build(BuildContext context) {
    final opportunities = report.rows
        .where((row) => row.segment == 'Oportunidad')
        .take(3)
        .map((row) => row.productName)
        .join(', ');
    final text = opportunities.isEmpty
        ? 'Revisa productos con margen bajo para ajustar costo, precio '
              'o receta.'
        : 'Potencia productos de alto margen: $opportunities.';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lightbulb_outline),
        title: const Text('Lectura rapida'),
        subtitle: Text(text),
      ),
    );
  }
}

class _ProductHighlight extends StatelessWidget {
  const _ProductHighlight({
    required this.label,
    required this.row,
    required this.value,
  });

  final String label;
  final ProductPerformanceRow? row;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(
                row?.productName ?? 'Sin datos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ProductPerformanceCard extends StatelessWidget {
  const _ProductPerformanceCard({required this.row});

  final ProductPerformanceRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(row.segment)),
              ],
            ),
            Text(row.categoryName),
            const SizedBox(height: 8),
            _ReportAmountRow(
              label: 'Unidades',
              value: _quantityLabel(row.quantitySold),
            ),
            _ReportAmountRow(
              label: 'Total vendido',
              value: MoneyFormatter.format(row.salesInCents),
            ),
            _ReportAmountRow(
              label: 'Costo historico',
              value: MoneyFormatter.format(row.costInCents),
            ),
            _ReportAmountRow(
              label: 'Utilidad bruta',
              value: MoneyFormatter.format(row.grossProfitInCents),
            ),
            _ReportAmountRow(label: 'Margen', value: _percent(row.margin)),
          ],
        ),
      ),
    );
  }
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _quantityLabel(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}
