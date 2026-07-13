import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';
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
        report.consideredExpensesInCents == 0 &&
        report.payrollNetInCents == 0) {
      final l10n = AppLocalizations.of(context);
      return AppEmptyState(
        icon: Icons.analytics_outlined,
        message: l10n.monthlyOperationalEmptyMessage,
        title: l10n.inventoryValueEmptyTitle,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OperationalTotalsCard(report: report),
            const SizedBox(height: 12),
            _OperationalDecisionCard(report: report),
            const SizedBox(height: 12),
            _OperationalExpenseBreakdown(report: report),
            const SizedBox(height: 12),
            MonthlyOperationalCoverageCard(report: report),
          ],
        );
      },
    );
  }
}

class _OperationalTotalsCard extends StatelessWidget {
  const _OperationalTotalsCard({required this.report});

  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric(
              label: l10n.reportGrossSales,
              value: report.totalSalesInCents,
            ),
            _Metric(
              label: l10n.monthlyOperationalProductCost,
              value: report.totalCostInCents,
            ),
            _Metric(
              label: l10n.reportGrossProfit,
              value: report.grossProfitInCents,
            ),
            _Metric(
              label: l10n.monthlyOperationalProjectedCoverage,
              value: report.projectedCoverageInCents,
            ),
            _Metric(
              label: l10n.monthlyOperationalActualCoverage,
              value: report.actualCoverageInCents,
            ),
            _Metric(
              emphasized: true,
              label: l10n.monthlyOperationalAvailableCoverage,
              value: report.coverageAvailableInCents,
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationalDecisionCard extends StatelessWidget {
  const _OperationalDecisionCard({required this.report});

  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final risk = report.hasCoverageRisk;
    return Card(
      color: risk ? colorScheme.errorContainer : colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(risk ? Icons.warning_amber : Icons.check_circle_outline),
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
            const SizedBox(height: 8),
            AppText(
              risk
                  ? l10n.monthlyOperationalRiskMessage
                  : l10n.monthlyOperationalHealthyMessage,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: l10n.monthlyOperationalCoverage,
                  value: '${report.coveragePercent.toStringAsFixed(1)}%',
                ),
                _InfoChip(
                  label: l10n.monthlyOperationalAdvances,
                  value: MoneyFormatter.format(
                    report.advancesDeliveredInCents,
                  ),
                ),
                _InfoChip(
                  label: l10n.monthlyOperationalPendingConsumption,
                  value: MoneyFormatter.format(
                    report.pendingStaffConsumptionInCents,
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

class _OperationalExpenseBreakdown extends StatelessWidget {
  const _OperationalExpenseBreakdown({required this.report});

  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = report.consideredExpensesByCategory.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              l10n.monthlyOperationalExpensesTitle,
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              AppText(l10n.reportNoExpenses)
            else
              for (final row in rows) _ExpenseRow(row: row, report: report),
            if (report.excludedExpensesInCents > 0) ...[
              const Divider(),
              OperationalAmountRow(
                label: l10n.monthlyOperationalExcludedExpenses,
                value: report.excludedExpensesInCents,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final bool emphasized;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primary.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, variant: AppTextVariant.label),
          const SizedBox(height: 2),
          AppText(
            MoneyFormatter.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: AppText('$label: $value'));
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
        : row.totalInCents / report.consideredExpensesInCents * 100;
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
          LinearProgressIndicator(value: percent.clamp(0, 100) / 100),
        ],
      ),
    );
  }
}
