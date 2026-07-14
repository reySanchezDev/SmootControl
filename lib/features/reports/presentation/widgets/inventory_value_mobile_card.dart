import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/inventory_value_report.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Mobile card for one inventory value row.
class InventoryValueMobileCard extends StatelessWidget {
  /// Creates the product inventory card.
  const InventoryValueMobileCard({required this.row, super.key});

  /// Product row to render.
  final InventoryValueReportRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(row.productName, variant: AppTextVariant.titleMedium),
            const SizedBox(height: 2),
            AppText(
              row.isRawMaterial
                  ? '${row.categoryName} - ${l10n.rawMaterialStatus}'
                  : row.categoryName,
              maxLines: 2,
              variant: AppTextVariant.label,
            ),
            const SizedBox(height: 8),
            _AmountRow(
              label: l10n.inventoryStockColumn,
              value: row.quantityOnHand.toString(),
            ),
            _AmountRow(
              label: l10n.inventoryCostValueColumn,
              value: MoneyFormatter.format(row.inventoryCostInCents),
            ),
            _AmountRow(
              label: l10n.inventoryPotentialSalesColumn,
              value: MoneyFormatter.format(row.potentialSalesInCents),
            ),
            _AmountRow(
              label: l10n.inventoryPotentialProfitMetric,
              value: MoneyFormatter.format(row.potentialGrossProfitInCents),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: AppText(label)),
          AppText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}
