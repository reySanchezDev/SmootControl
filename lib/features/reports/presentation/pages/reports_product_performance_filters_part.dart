part of 'reports_page.dart';

enum _ProductSegmentFilter {
  all('Todos'),
  star('Estrella'),
  opportunity('Oportunidad'),
  volume('Volumen'),
  review('Revisar')
  ;

  const _ProductSegmentFilter(this.label);

  final String label;

  bool accepts(ProductPerformanceRow row) {
    return this == all || row.segment == label;
  }
}

enum _ProductPerformanceSort {
  profit('Utilidad'),
  quantity('Unidades'),
  margin('Margen'),
  sales('Ventas')
  ;

  const _ProductPerformanceSort(this.label);

  final String label;

  int compare(ProductPerformanceRow a, ProductPerformanceRow b) {
    return switch (this) {
      profit => b.grossProfitInCents.compareTo(a.grossProfitInCents),
      quantity => b.quantitySold.compareTo(a.quantitySold),
      margin => b.margin.compareTo(a.margin),
      sales => b.salesInCents.compareTo(a.salesInCents),
    };
  }
}

class _ProductPerformanceFilters extends StatelessWidget {
  const _ProductPerformanceFilters({
    required this.onSegmentChanged,
    required this.onSortChanged,
    required this.segment,
    required this.sort,
  });

  final ValueChanged<_ProductSegmentFilter> onSegmentChanged;
  final ValueChanged<_ProductPerformanceSort> onSortChanged;
  final _ProductSegmentFilter segment;
  final _ProductPerformanceSort sort;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Segmento', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final option in _ProductSegmentFilter.values)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: segment == option,
                    onSelected: (_) => onSegmentChanged(option),
                  ),
              ],
            ),
            const Divider(height: 24),
            Text('Ordenar por', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final option in _ProductPerformanceSort.values)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: sort == option,
                    onSelected: (_) => onSortChanged(option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
