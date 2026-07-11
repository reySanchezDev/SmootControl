part of 'reports_page.dart';

class _ExpensesReportView extends StatelessWidget {
  const _ExpensesReportView({required this.report});

  final ExpensesReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'No hay gastos operativos en el rango seleccionado.',
        title: 'Sin datos',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ExpensesTotalsCard(report: report),
            const SizedBox(height: 12),
            _ExpenseCategoryBreakdown(report: report),
            const SizedBox(height: 12),
            if (compact)
              _ExpensesMobileList(report: report)
            else
              _ExpensesDataTable(report: report),
          ],
        );
      },
    );
  }
}

class _ExpensesTotalsCard extends StatelessWidget {
  const _ExpensesTotalsCard({required this.report});

  final ExpensesReport report;

  @override
  Widget build(BuildContext context) {
    final topCategory = report.topCategory;
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
                    label: 'Total gastos',
                    value: MoneyFormatter.format(report.totalInCents),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TotalPill(
                    emphasized: true,
                    label: 'Promedio diario',
                    value: MoneyFormatter.format(report.averageDailyInCents),
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
                  label: 'Mayor categoria',
                  value: topCategory?.categoryName ?? 'N/D',
                ),
                _MiniMetric(
                  label: 'Categorias',
                  value: report.byCategory.length.toString(),
                ),
                _MiniMetric(
                  label: 'Dias',
                  value: report.periodDays.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCategoryBreakdown extends StatelessWidget {
  const _ExpenseCategoryBreakdown({required this.report});

  final ExpensesReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Gastos por categoria',
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final row in report.byCategory.take(6)) ...[
              _ExpenseCategoryRow(
                row: row,
                totalInCents: report.totalInCents,
              ),
              if (row != report.byCategory.take(6).last)
                Divider(color: colorScheme.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpenseCategoryRow extends StatelessWidget {
  const _ExpenseCategoryRow({
    required this.row,
    required this.totalInCents,
  });

  final ExpenseCategoryReportRow row;
  final int totalInCents;

  @override
  Widget build(BuildContext context) {
    final percent = totalInCents == 0
        ? 0
        : (row.totalInCents / totalInCents * 100).clamp(0, 100);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: AppText(row.categoryName)),
              AppText(
                MoneyFormatter.format(row.totalInCents),
                style: const TextStyle(fontWeight: FontWeight.w700),
                variant: AppTextVariant.label,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: percent / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 3),
          AppText(
            '${percent.toStringAsFixed(1)}% del total',
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}

class _ExpensesMobileList extends StatelessWidget {
  const _ExpensesMobileList({required this.report});

  final ExpensesReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in report.rows) _ExpensesMobileCard(row: row),
      ],
    );
  }
}

class _ExpensesMobileCard extends StatelessWidget {
  const _ExpensesMobileCard({required this.row});

  final DailyExpensesReportRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                _formatDate(row.date),
                variant: AppTextVariant.titleMedium,
              ),
            ),
            AppText(
              MoneyFormatter.format(row.totalInCents),
              style: const TextStyle(fontWeight: FontWeight.w800),
              variant: AppTextVariant.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensesDataTable extends StatelessWidget {
  const _ExpensesDataTable({required this.report});

  final ExpensesReport report;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final row in report.rows)
        DataRow(
          cells: [
            DataCell(Text(_formatDate(row.date))),
            DataCell(Text(MoneyFormatter.format(row.totalInCents))),
          ],
        ),
      DataRow(
        cells: [
          const DataCell(Text('Totales')),
          DataCell(Text(MoneyFormatter.format(report.totalInCents))),
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
            DataColumn(label: Text('Total gastos'), numeric: true),
          ],
          rows: rows,
        ),
      ),
    );
  }
}
