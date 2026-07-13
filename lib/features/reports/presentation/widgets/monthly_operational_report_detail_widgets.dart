import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Mobile daily list for the monthly operational report.
class OperationalMobileList extends StatelessWidget {
  /// Creates the mobile list.
  const OperationalMobileList({required this.report, super.key});

  /// Report data.
  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final row in report.dailyRows) _DailyCard(row: row)],
    );
  }
}

/// Desktop/tablet daily table for the monthly operational report.
class OperationalDataTable extends StatelessWidget {
  /// Creates the data table.
  const OperationalDataTable({required this.report, super.key});

  /// Report data.
  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: AppText(l10n.salesDateLabel)),
            DataColumn(label: AppText(l10n.reportGrossSales), numeric: true),
            DataColumn(label: AppText(l10n.reportGrossProfit), numeric: true),
            DataColumn(label: AppText(l10n.reportExpenses), numeric: true),
            DataColumn(
              label: AppText(l10n.monthlyOperationalResult),
              numeric: true,
            ),
          ],
          rows: [
            for (final row in report.dailyRows)
              DataRow(
                cells: [
                  DataCell(AppText(_formatDate(row.date))),
                  DataCell(AppText(MoneyFormatter.format(row.salesInCents))),
                  DataCell(
                    AppText(MoneyFormatter.format(row.grossProfitInCents)),
                  ),
                  DataCell(AppText(MoneyFormatter.format(row.expensesInCents))),
                  DataCell(AppText(MoneyFormatter.format(row.resultInCents))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Standard money row used by operational report cards.
class OperationalAmountRow extends StatelessWidget {
  /// Creates one amount row.
  const OperationalAmountRow({
    required this.label,
    required this.value,
    super.key,
  });

  /// Row label.
  final String label;

  /// Money value in minor currency units.
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: AppText(label)),
          AppText(
            MoneyFormatter.format(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.row});

  final MonthlyOperationalDailyRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(_formatDate(row.date), variant: AppTextVariant.titleMedium),
            const SizedBox(height: 8),
            OperationalAmountRow(
              label: l10n.reportGrossSales,
              value: row.salesInCents,
            ),
            OperationalAmountRow(
              label: l10n.reportGrossProfit,
              value: row.grossProfitInCents,
            ),
            OperationalAmountRow(
              label: l10n.reportExpenses,
              value: row.expensesInCents,
            ),
            OperationalAmountRow(
              label: l10n.monthlyOperationalResult,
              value: row.resultInCents,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
