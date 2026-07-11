part of 'sale_detail_page.dart';

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.items, required this.sale});

  final List<SaleItem> items;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final units = items.fold(0, (total, item) => total + item.quantity);
    return _SectionSurface(
      child: Column(
        children: [
          _TotalRow(label: 'Unidades', value: units.toString()),
          _TotalRow(
            label: 'Subtotal',
            value: MoneyFormatter.format(sale.subtotalInCents),
          ),
          _TotalRow(
            label: 'Total',
            value: MoneyFormatter.format(sale.totalInCents),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final bool emphasized;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.columns, required this.entries});

  final int columns;
  final List<_InfoEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            for (final entry in entries)
              SizedBox(
                width: _itemWidth(constraints.maxWidth, columns),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(entry.label, variant: AppTextVariant.label),
                    const SizedBox(height: 2),
                    Text(
                      entry.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  double _itemWidth(double maxWidth, int columns) {
    final availableWidth = maxWidth - ((columns - 1) * 14);
    return (availableWidth / columns).clamp(150, 360).toDouble();
  }
}

class _InfoEntry {
  const _InfoEntry(this.label, this.value);

  final String label;
  final String value;
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _SaleDetailData {
  const _SaleDetailData({
    required this.items,
    required this.paymentMethodName,
  });

  final List<SaleItem> items;
  final String paymentMethodName;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
