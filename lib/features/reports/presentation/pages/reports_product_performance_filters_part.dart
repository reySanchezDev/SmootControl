part of 'reports_page.dart';

enum _ProductSegmentFilter {
  all('Todos'),
  star('Estrella'),
  potential('Potenciar'),
  volume('Volumen'),
  review('Revisar')
  ;

  const _ProductSegmentFilter(this.label);

  final String label;

  bool accepts(ProductPerformanceRow row) {
    return switch (this) {
      all => true,
      star => row.segment == 'Estrella',
      potential => row.segment == 'Oportunidad',
      volume => row.segment == 'Volumen',
      review => row.segment == 'Revisar',
    };
  }
}

enum _ProductPerformanceSort {
  profit('Utilidad'),
  margin('Margen'),
  quantity('Unidades'),
  sales('Ventas')
  ;

  const _ProductPerformanceSort(this.label);

  final String label;

  int compare(ProductPerformanceRow a, ProductPerformanceRow b) {
    return switch (this) {
      profit => b.grossProfitInCents.compareTo(a.grossProfitInCents),
      margin => b.margin.compareTo(a.margin),
      quantity => b.quantitySold.compareTo(a.quantitySold),
      sales => b.salesInCents.compareTo(a.salesInCents),
    };
  }
}

class _ProductPerformanceFilters extends StatelessWidget {
  const _ProductPerformanceFilters({
    required this.onSegmentToggled,
    required this.onSortToggled,
    required this.segments,
    required this.sorts,
  });

  final ValueChanged<_ProductSegmentFilter> onSegmentToggled;
  final ValueChanged<_ProductPerformanceSort> onSortToggled;
  final Set<_ProductSegmentFilter> segments;
  final List<_ProductPerformanceSort> sorts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompactFilterLine(
              label: 'Ver',
              children: [
                for (final option in _ProductSegmentFilter.values)
                  FilterChip(
                    label: Text(option.label),
                    selected: segments.contains(option),
                    onSelected: (_) => onSegmentToggled(option),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _CompactFilterLine(
              label: 'Orden',
              children: [
                for (final option in _ProductPerformanceSort.values)
                  FilterChip(
                    label: Text(option.label),
                    selected: sorts.contains(option),
                    onSelected: (_) => onSortToggled(option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactFilterLine extends StatelessWidget {
  const _CompactFilterLine({required this.children, required this.label});

  final List<Widget> children;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 4, children: children),
        ),
      ],
    );
  }
}
