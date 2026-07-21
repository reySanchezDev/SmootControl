part of 'inventory_page.dart';

class _InventoryAdjustmentSummary extends StatelessWidget {
  const _InventoryAdjustmentSummary({required this.rows});

  final List<_InventoryAdjustmentRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deltas = rows.map((row) => row.delta).whereType<double>();
    final changed = deltas.where((delta) => delta != 0).length;
    final positive = deltas
        .where((delta) => delta > 0)
        .fold<double>(0, (sum, delta) => sum + delta);
    final negative = deltas
        .where((delta) => delta < 0)
        .fold<double>(0, (sum, delta) => sum + delta.abs());
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
                value: _adjustmentQuantityText(positive),
              ),
            ),
            Expanded(
              child: _AdjustmentSummaryMetric(
                label: l10n.inventoryAdjustmentNegative,
                value: _adjustmentQuantityText(negative),
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
    final counted = row.countedQuantity;
    final displayStock = row.item.displayQuantity;
    final displayUnit = row.item.displayUnitName;
    final baseUnit = row.item.inventoryUnitName;
    final countedBase = counted == null
        ? null
        : row.countedBaseQuantity(counted);
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
                    value: _quantityWithUnit(displayStock, displayUnit),
                    helper: _baseDetail(row.item.quantityOnHand, baseUnit),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: row.countController,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText:
                          '${l10n.inventoryAdjustmentCountedStock}'
                          '${displayUnit == null ? '' : ' ($displayUnit)'}',
                      helperText: _countBaseDetail(
                        countedBase,
                        baseUnit,
                        displayUnit,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdjustmentReadOnlyValue(
                    label: l10n.inventoryAdjustmentDifference,
                    value: _quantityWithUnit(delta, baseUnit),
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

String? _baseDetail(double value, String? unitName) {
  if (unitName == null || unitName.isEmpty) return null;
  return 'Base: ${_quantityWithUnit(value, unitName)}';
}

String? _countBaseDetail(
  double? value,
  String? baseUnit,
  String? displayUnit,
) {
  if (value == null || baseUnit == null || baseUnit.isEmpty) return null;
  if (displayUnit == baseUnit) return null;
  return 'Conteo base: ${_quantityWithUnit(value, baseUnit)}';
}

String _adjustmentQuantityText(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  if (value.abs() > 0 && value.abs() < 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(2);
}

String _quantityWithUnit(double? value, String? unitName) {
  if (value == null) return '-';
  final unit = unitName == null || unitName.isEmpty ? '' : ' $unitName';
  return '${_adjustmentQuantityText(value)}$unit';
}

class _AdjustmentReadOnlyValue extends StatelessWidget {
  const _AdjustmentReadOnlyValue({
    required this.label,
    required this.value,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(isDense: true, labelText: label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(value, maxLines: 1),
          if (helper != null)
            AppText(helper!, maxLines: 1, variant: AppTextVariant.label),
        ],
      ),
    );
  }
}
