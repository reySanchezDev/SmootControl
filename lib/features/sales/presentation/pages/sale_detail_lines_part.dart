part of 'sale_detail_page.dart';

class _LinesSection extends StatelessWidget {
  const _LinesSection({required this.items});

  final List<SaleItem> items;

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Lineas', variant: AppTextVariant.titleMedium),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const AppText('Esta venta no tiene lineas registradas.')
          else
            _SaleLinesTable(items: items),
        ],
      ),
    );
  }
}

class _SaleLinesTable extends StatelessWidget {
  const _SaleLinesTable({required this.items});

  final List<SaleItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (final item in items) _CompactLineTile(item: item),
            ],
          );
        }

        return Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.4),
          },
          border: TableBorder(
            horizontalInside: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
          children: [
            _lineRow(
              context,
              isHeader: true,
              cells: const ['Producto', 'Cant.', 'Precio', 'Monto'],
            ),
            for (final item in items)
              _lineRow(
                context,
                cells: [
                  _productLabel(item),
                  item.quantity.toString(),
                  MoneyFormatter.format(item.unitPriceInCents),
                  MoneyFormatter.format(item.totalInCents),
                ],
              ),
          ],
        );
      },
    );
  }

  TableRow _lineRow(
    BuildContext context, {
    required List<String> cells,
    bool isHeader = false,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
    );
    return TableRow(
      children: [
        for (var index = 0; index < cells.length; index += 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Text(
              cells[index],
              maxLines: index == 0 ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: index == 0 ? TextAlign.start : TextAlign.end,
              style: style,
            ),
          ),
      ],
    );
  }

  String _productLabel(SaleItem item) {
    final options = item.selectedOptionsLabel?.trim();
    if (options == null || options.isEmpty) return item.productName;
    return '${item.productName}\n$options';
  }
}

class _CompactLineTile extends StatelessWidget {
  const _CompactLineTile({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final options = item.selectedOptionsLabel?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(item.productName),
                if (options != null && options.isNotEmpty)
                  AppText(options, variant: AppTextVariant.label),
                AppText(
                  '${item.quantity} x '
                  '${MoneyFormatter.format(item.unitPriceInCents)}',
                  variant: AppTextVariant.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppText(MoneyFormatter.format(item.totalInCents)),
        ],
      ),
    );
  }
}
