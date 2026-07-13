import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';
import 'package:smoo_control/features/reports/presentation/widgets/monthly_operational_period_cuts_widgets.dart';
import 'package:smoo_control/features/reports/presentation/widgets/monthly_operational_report_coverage_widgets.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Responsive body for the monthly operational report.
class MonthlyOperationalReportView extends StatelessWidget {
  /// Creates the report view.
  const MonthlyOperationalReportView({required this.report, super.key});

  /// Report data.
  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    if (report.totalSalesInCents == 0 &&
        report.monthlyObligationInCents == 0 &&
        report.payrollNetInCents == 0) {
      final l10n = AppLocalizations.of(context);
      return AppEmptyState(
        icon: Icons.analytics_outlined,
        message: l10n.monthlyOperationalEmptyMessage,
        title: l10n.inventoryValueEmptyTitle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OperationalTotalsCard(report: report),
        const SizedBox(height: 12),
        MonthlyOperationalPeriodCutsCard(report: report),
        const SizedBox(height: 12),
        _OperationalDetailsCard(report: report),
      ],
    );
  }
}

class _OperationalTotalsCard extends StatelessWidget {
  const _OperationalTotalsCard({required this.report});

  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final risk = report.hasCoverageRisk;
    final balanceLabel = risk
        ? l10n.monthlyOperationalMissingToCover
        : l10n.monthlyOperationalEstimatedSurplus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  risk ? Icons.warning_amber : Icons.check_circle_outline,
                  color: risk ? colorScheme.error : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    risk
                        ? l10n.monthlyOperationalRiskTitle
                        : l10n.monthlyOperationalHealthyTitle,
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AppText(
              risk
                  ? l10n.monthlyOperationalMissingMessage(
                      report.coveragePercent.toStringAsFixed(1),
                      MoneyFormatter.format(report.monthlyBalanceInCents.abs()),
                    )
                  : l10n.monthlyOperationalSurplusMessage(
                      MoneyFormatter.format(report.monthlyBalanceInCents.abs()),
                    ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (report.coveragePercent / 100).clamp(0, 1),
            ),
            const SizedBox(height: 12),
            _SummaryLine(
              label: l10n.reportGrossSales,
              value: report.totalSalesInCents,
            ),
            _SummaryLine(
              label: l10n.monthlyOperationalReserveCost,
              value: report.totalCostInCents,
            ),
            _SummaryLine(
              emphasized: true,
              label: l10n.reportGrossProfit,
              value: report.grossProfitInCents,
            ),
            const Divider(),
            _SummaryLine(
              label: l10n.monthlyOperationalPayroll,
              value: report.payrollNetInCents,
            ),
            _SummaryLine(
              label: l10n.monthlyOperationalCoverageIndicators,
              value: report.coverageObligationInCents,
            ),
            _SummaryLine(
              label: l10n.monthlyOperationalPendingDisbursement,
              value: report.pendingDisbursementInCents,
            ),
            const Divider(),
            _SummaryLine(
              emphasized: true,
              label: balanceLabel,
              value: report.monthlyBalanceInCents.abs(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationalDetailsCard extends StatelessWidget {
  const _OperationalDetailsCard({required this.report});

  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Column(
        children: [
          ExpansionTile(
            title: AppText(l10n.monthlyOperationalCoverageIndicators),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            children: [
              MonthlyOperationalCoverageCard(report: report, framed: false),
            ],
          ),
          ExpansionTile(
            title: AppText(l10n.monthlyOperationalExpensesTitle),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            children: [_OperationalExpenseBreakdown(report: report)],
          ),
        ],
      ),
    );
  }
}

class _OperationalExpenseBreakdown extends StatelessWidget {
  const _OperationalExpenseBreakdown({required this.report});

  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = report.consideredExpensesByCategory.take(6).toList();
    if (rows.isEmpty) return AppText(l10n.reportNoExpenses);
    return Column(
      children: [
        for (final row in rows) _ExpenseRow(row: row, report: report),
        if (report.excludedExpensesInCents > 0) ...[
          const Divider(),
          OperationalAmountRow(
            label: l10n.monthlyOperationalExcludedExpenses,
            value: report.excludedExpensesInCents,
          ),
        ],
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final bool emphasized;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              maxLines: 2,
              variant: emphasized
                  ? AppTextVariant.titleMedium
                  : AppTextVariant.body,
            ),
          ),
          AppText(
            MoneyFormatter.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: emphasized
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
            variant: emphasized
                ? AppTextVariant.titleMedium
                : AppTextVariant.body,
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.report, required this.row});

  final MonthlyOperationalReport report;
  final MonthlyOperationalExpenseRow row;

  @override
  Widget build(BuildContext context) {
    final percent = report.consideredExpensesInCents == 0
        ? 0
        : row.totalInCents / report.consideredExpensesInCents;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OperationalAmountRow(
            label: row.categoryName,
            value: row.totalInCents,
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: percent.clamp(0, 1).toDouble()),
        ],
      ),
    );
  }
}
