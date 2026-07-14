part of 'inventory_page.dart';

class _InventoryAdjustmentSummary extends StatelessWidget {
  const _InventoryAdjustmentSummary({required this.rows});

  final List<_InventoryAdjustmentRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deltas = rows.map((row) => row.delta).whereType<int>();
    final changed = deltas.where((delta) => delta != 0).length;
    final positive = deltas
        .where((delta) => delta > 0)
        .fold<int>(0, (sum, delta) => sum + delta);
    final negative = deltas
        .where((delta) => delta < 0)
        .fold<int>(0, (sum, delta) => sum + delta.abs());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _AdjustmentSummaryMetric(
                label: l10n.inventoryAdjustmentChanged,
                value: changed.toString(),
              ),
            ),
            Expanded(
              child: _AdjustmentSummaryMetric(
                label: l10n.inventoryAdjustmentPositive,
                value: positive.toString(),
              ),
            ),
            Expanded(
              child: _AdjustmentSummaryMetric(
                label: l10n.inventoryAdjustmentNegative,
                value: negative.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentSummaryMetric extends StatelessWidget {
  const _AdjustmentSummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppText(
          value,
          variant: AppTextVariant.titleMedium,
          maxLines: 1,
        ),
        AppText(
          label,
          variant: AppTextVariant.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _InventoryAdjustmentTile extends StatelessWidget {
  const _InventoryAdjustmentTile({required this.row, required this.onChanged});

  final _InventoryAdjustmentRow row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final delta = row.delta;
    final deltaText = delta == null ? '-' : delta.toString();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              row.item.productName,
              style: const TextStyle(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if ((row.item.categoryPath ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              AppText(
                row.item.categoryPath!,
                variant: AppTextVariant.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AdjustmentReadOnlyValue(
                    label: l10n.inventoryAdjustmentSystemStock,
                    value: row.item.quantityOnHand.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: row.countController,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.inventoryAdjustmentCountedStock,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdjustmentReadOnlyValue(
                    label: l10n.inventoryAdjustmentDifference,
                    value: deltaText,
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

class _AdjustmentReadOnlyValue extends StatelessWidget {
  const _AdjustmentReadOnlyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(isDense: true, labelText: label),
      child: AppText(value, maxLines: 1),
    );
  }
}
