part of 'reports_page.dart';

class _DailySalesReportView extends StatelessWidget {
  const _DailySalesReportView({required this.report});

  final DailySalesReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'No hay ventas completadas en el rango seleccionado.',
        title: 'Sin datos',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DailySalesTotalsCard(report: report),
            const SizedBox(height: 12),
            if (compact)
              _DailySalesMobileList(report: report)
            else
              _DailySalesDataTable(report: report),
          ],
        );
      },
    );
  }
}

class _DailySalesTotalsCard extends StatelessWidget {
  const _DailySalesTotalsCard({required this.report});

  final DailySalesReport report;

  @override
  Widget build(BuildContext context) {
    final margin = report.totalSalesInCents == 0
        ? 0
        : (report.grossProfitInCents / report.totalSalesInCents) * 100;
    final periodDays = report.to.difference(report.from).inDays + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _TotalPill(
                    emphasized: true,
                    label: 'Vendido',
                    value: MoneyFormatter.format(report.totalSalesInCents),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TotalPill(
                    emphasized: true,
                    label: 'Utilidad',
                    value: MoneyFormatter.format(report.grossProfitInCents),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniMetric(
                  label: 'Costos',
                  value: MoneyFormatter.format(report.totalCostInCents),
                ),
                _MiniMetric(
                  label: 'Margen',
                  value: '${margin.toStringAsFixed(1)}%',
                ),
                _MiniMetric(
                  label: 'Dias',
                  value: periodDays.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalPill extends StatelessWidget {
  const _TotalPill({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final bool emphasized;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, variant: AppTextVariant.label),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppText(value, variant: AppTextVariant.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _DailySalesMobileList extends StatelessWidget {
  const _DailySalesMobileList({required this.report});

  final DailySalesReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in report.rows)
          _DailySalesMobileCard(
            row: row,
          ),
      ],
    );
  }
}

class _DailySalesMobileCard extends StatelessWidget {
  const _DailySalesMobileCard({
    required this.row,
  });

  final DailySalesReportRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              _formatDate(row.date),
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 8),
            _ReportAmountRow(
              label: 'Total vendido',
              value: MoneyFormatter.format(row.totalSalesInCents),
            ),
            _ReportAmountRow(
              label: 'Total costos',
              value: MoneyFormatter.format(row.totalCostInCents),
            ),
            _ReportAmountRow(
              label: 'Utilidad bruta',
              value: MoneyFormatter.format(row.grossProfitInCents),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailySalesDataTable extends StatelessWidget {
  const _DailySalesDataTable({required this.report});

  final DailySalesReport report;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final row in report.rows)
        DataRow(
          cells: [
            DataCell(Text(_formatDate(row.date))),
            DataCell(Text(MoneyFormatter.format(row.totalSalesInCents))),
            DataCell(Text(MoneyFormatter.format(row.totalCostInCents))),
            DataCell(Text(MoneyFormatter.format(row.grossProfitInCents))),
          ],
        ),
      DataRow(
        cells: [
          const DataCell(Text('Totales')),
          DataCell(Text(MoneyFormatter.format(report.totalSalesInCents))),
          DataCell(Text(MoneyFormatter.format(report.totalCostInCents))),
          DataCell(Text(MoneyFormatter.format(report.grossProfitInCents))),
        ],
      ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Total vendido'), numeric: true),
            DataColumn(label: Text('Total costos'), numeric: true),
            DataColumn(label: Text('Utilidad bruta'), numeric: true),
          ],
          rows: rows,
        ),
      ),
    );
  }
}
