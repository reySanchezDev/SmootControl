import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/backoffice_data_table.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/inventory_value_report.dart';
import 'package:smoo_control/features/reports/presentation/widgets/inventory_value_mobile_card.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

// These widgets are public because the report page composes them directly.
// ignore_for_file: public_member_api_docs

class InventoryTotalsCard extends StatelessWidget {
  const InventoryTotalsCard({required this.report, super.key});

  final InventoryValueReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InventoryMetric(
                  label: l10n.inventoryCostMetric,
                  value: MoneyFormatter.format(report.inventoryCostInCents),
                ),
                _InventoryMetric(
                  label: l10n.inventoryPotentialSalesMetric,
                  value: MoneyFormatter.format(report.potentialSalesInCents),
                ),
                _InventoryMetric(
                  label: l10n.inventoryPotentialProfitMetric,
                  value: MoneyFormatter.format(
                    report.potentialGrossProfitInCents,
                  ),
                ),
                _InventoryMetric(
                  label: l10n.inventoryMarginMetric,
                  value: '${report.marginPercent.toStringAsFixed(1)}%',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InventoryAlert(
                  label: l10n.inventoryWithStockMetric,
                  value: report.stockedProductCount,
                ),
                _InventoryAlert(
                  label: l10n.inventoryMissingCostMetric,
                  value: report.missingCostCount,
                ),
                _InventoryAlert(
                  label: l10n.inventoryMissingPriceMetric,
                  value: report.missingPriceCount,
                ),
                _InventoryAlert(
                  label: l10n.inventoryLowMarginMetric,
                  value: report.lowMarginCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryCategoryBreakdown extends StatelessWidget {
  const InventoryCategoryBreakdown({required this.rows, super.key});

  final List<InventoryValueReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = InventoryValueReport(
      generatedAt: DateTime.now(),
      rows: rows,
    ).byCategory.take(6).toList();
    final total = rows.fold(0, (sum, row) => sum + row.inventoryCostInCents);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              l10n.inventoryCategoryValueTitle,
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final row in categories)
              _InventoryCategoryRow(row: row, totalInCents: total),
          ],
        ),
      ),
    );
  }
}

class InventoryMobileList extends StatelessWidget {
  const InventoryMobileList({required this.rows, super.key});

  final List<InventoryValueReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final row in rows) InventoryValueMobileCard(row: row)],
    );
  }
}

class InventoryDataTable extends StatelessWidget {
  const InventoryDataTable({required this.rows, super.key});

  final List<InventoryValueReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 440,
      child: BackofficeDataTable(
        columns: [
          l10n.inventoryProductColumn,
          l10n.inventoryCategoryColumn,
          l10n.inventoryStockColumn,
          l10n.inventoryCostColumn,
          l10n.inventoryPriceColumn,
          l10n.inventoryCostValueColumn,
          l10n.inventoryPotentialSalesColumn,
          l10n.inventoryProfitColumn,
        ],
        columnWidths: const [250, 250, 145, 160, 160, 180, 185, 180],
        columnAlignments: const [
          Alignment.centerLeft,
          Alignment.centerLeft,
          Alignment.centerRight,
          Alignment.centerRight,
          Alignment.centerRight,
          Alignment.centerRight,
          Alignment.centerRight,
          Alignment.centerRight,
        ],
        sortableColumns: const [
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
        ],
        rows: [
          for (final row in rows)
            [
              Text(row.productName),
              Text(
                row.isRawMaterial
                    ? '${row.categoryName} - ${l10n.rawMaterialStatus}'
                    : row.categoryName,
              ),
              Text(_quantityText(row.quantityOnHand)),
              Text(MoneyFormatter.format(row.costInCents)),
              Text(MoneyFormatter.format(row.priceInCents)),
              Text(MoneyFormatter.format(row.inventoryCostInCents)),
              Text(MoneyFormatter.format(row.potentialSalesInCents)),
              Text(MoneyFormatter.format(row.potentialGrossProfitInCents)),
            ],
        ],
      ),
    );
  }
}

String _quantityText(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(2);

class _InventoryMetric extends StatelessWidget {
  const _InventoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 142),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, variant: AppTextVariant.label),
          const SizedBox(height: 2),
          AppText(value, variant: AppTextVariant.titleMedium),
        ],
      ),
    );
  }
}

class _InventoryAlert extends StatelessWidget {
  const _InventoryAlert({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        value > 0 ? Icons.info_outline : Icons.check_circle_outline,
        size: 18,
      ),
      backgroundColor: value > 0
          ? colorScheme.errorContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerHighest,
      label: AppText('$label: $value'),
    );
  }
}

class _InventoryCategoryRow extends StatelessWidget {
  const _InventoryCategoryRow({
    required this.row,
    required this.totalInCents,
  });

  final InventoryValueCategoryRow row;
  final int totalInCents;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = totalInCents <= 0
        ? 0
        : (row.inventoryCostInCents / totalInCents * 100).clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: AppText(row.categoryName, maxLines: 2)),
              AppText(
                MoneyFormatter.format(row.inventoryCostInCents),
                style: const TextStyle(fontWeight: FontWeight.w700),
                variant: AppTextVariant.label,
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            minHeight: 6,
            value: percent / 100,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 3),
          AppText(
            AppLocalizations.of(context).inventoryCapitalPercentLabel(
              percent.toStringAsFixed(1),
            ),
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}
