part of 'reports_page.dart';

class _ProductPerformanceView extends StatelessWidget {
  const _ProductPerformanceView({
    required this.onSegmentToggled,
    required this.onSortToggled,
    required this.report,
    required this.segments,
    required this.sorts,
  });

  final ValueChanged<_ProductSegmentFilter> onSegmentToggled;
  final ValueChanged<_ProductPerformanceSort> onSortToggled;
  final ProductPerformanceReport report;
  final Set<_ProductSegmentFilter> segments;
  final List<_ProductPerformanceSort> sorts;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.restaurant_menu_outlined,
        title: 'Sin ventas',
        message: 'No hay productos vendidos en el rango seleccionado.',
      );
    }
    final rows = _visibleRows;
    return Column(
      children: [
        _ProductPerformanceFilters(
          onSegmentToggled: onSegmentToggled,
          onSortToggled: onSortToggled,
          segments: segments,
          sorts: sorts,
        ),
        const SizedBox(height: 10),
        _ProductPerformanceList(
          rows: rows,
          segmentLabel: _segmentLabel,
          sortLabel: _sortLabel,
        ),
      ],
    );
  }

  List<ProductPerformanceRow> get _visibleRows {
    final rows = report.rows.where(_acceptsSegment).toList()
      ..sort((a, b) {
        for (final sort in sorts) {
          final result = sort.compare(a, b);
          if (result != 0) return result;
        }
        return b.grossProfitInCents.compareTo(a.grossProfitInCents);
      });
    return rows;
  }

  bool _acceptsSegment(ProductPerformanceRow row) {
    return segments.any((segment) => segment.accepts(row));
  }

  String get _segmentLabel {
    if (segments.contains(_ProductSegmentFilter.all)) return 'Todos';
    return segments.map((segment) => segment.label).join(', ');
  }

  String get _sortLabel {
    return sorts.map((sort) => sort.label).join(' + ');
  }
}

class _ProductPerformanceList extends StatelessWidget {
  const _ProductPerformanceList({
    required this.rows,
    required this.segmentLabel,
    required this.sortLabel,
  });

  final List<ProductPerformanceRow> rows;
  final String segmentLabel;
  final String sortLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'Sin productos',
        message: 'No hay productos con esos filtros para este rango.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${rows.length} productos - $segmentLabel - $sortLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        for (final row in rows) _ProductPerformanceCard(row: row),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                _ProductSegmentLabel(segment: row.segment),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _CompactProductMetric(
                    label: 'Unid.',
                    value: _quantityLabel(row.quantitySold),
                  ),
                ),
                Expanded(
                  child: _CompactProductMetric(
                    label: 'Venta',
                    value: MoneyFormatter.format(row.salesInCents),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _CompactProductMetric(
                    label: 'Utilidad',
                    value: MoneyFormatter.format(row.grossProfitInCents),
                  ),
                ),
                Expanded(
                  child: _CompactProductMetric(
                    label: 'Margen',
                    value: _percent(row.margin),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactProductMetric extends StatelessWidget {
  const _CompactProductMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: Theme.of(context).textTheme.labelMedium,
        children: [
          TextSpan(
            text: value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ProductSegmentLabel extends StatelessWidget {
  const _ProductSegmentLabel({required this.segment});

  final String segment;

  @override
  Widget build(BuildContext context) {
    final color = _segmentColor(context);
    return Text(
      segment == 'Oportunidad' ? 'Potenciar' : segment,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Color _segmentColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (segment) {
      'Estrella' => scheme.primary,
      'Oportunidad' => scheme.tertiary,
      'Volumen' => scheme.secondary,
      'Revisar' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
  }
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _quantityLabel(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}
