part of 'reports_page.dart';

class _ProductPerformanceView extends StatelessWidget {
  const _ProductPerformanceView({
    required this.onSegmentChanged,
    required this.onSortChanged,
    required this.report,
    required this.segment,
    required this.sort,
  });

  final ValueChanged<_ProductSegmentFilter> onSegmentChanged;
  final ValueChanged<_ProductPerformanceSort> onSortChanged;
  final ProductPerformanceReport report;
  final _ProductSegmentFilter segment;
  final _ProductPerformanceSort sort;

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
        _ProductPerformanceFilters(
          onSegmentChanged: onSegmentChanged,
          onSortChanged: onSortChanged,
          segment: segment,
          sort: sort,
        ),
        const SizedBox(height: 12),
        _ProductPerformanceList(
          rows: _visibleRows,
          segment: segment,
          sort: sort,
        ),
      ],
    );
  }

  List<ProductPerformanceRow> get _visibleRows {
    return report.rows.where(segment.accepts).toList()..sort((a, b) {
      final primary = sort.compare(a, b);
      if (primary != 0) return primary;
      return b.grossProfitInCents.compareTo(a.grossProfitInCents);
    });
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

class _ProductPerformanceList extends StatelessWidget {
  const _ProductPerformanceList({
    required this.rows,
    required this.segment,
    required this.sort,
  });

  final List<ProductPerformanceRow> rows;
  final _ProductSegmentFilter segment;
  final _ProductPerformanceSort sort;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return AppEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'Sin productos',
        message: 'No hay productos en ${segment.label} para este rango.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${rows.length} productos - ${segment.label} - ${sort.label}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        for (final row in rows) _ProductPerformanceCard(row: row),
      ],
    );
  }
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _quantityLabel(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}
