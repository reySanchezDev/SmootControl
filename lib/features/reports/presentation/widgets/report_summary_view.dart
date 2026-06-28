import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_cash_section.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_expenses_section.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_metric_card.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_voids_section.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Full report summary content.
class ReportSummaryView extends StatelessWidget {
  /// Creates a report summary view.
  const ReportSummaryView({required this.summary, super.key});

  /// Summary to display.
  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1024
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                childAspectRatio: columns == 1 ? 3.2 : 2.5,
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ReportMetricCard(
                    label: l10n.reportGrossSales,
                    value: MoneyFormatter.format(summary.grossSalesInCents),
                  ),
                  ReportMetricCard(
                    label: l10n.reportGrossProfit,
                    value: MoneyFormatter.format(summary.grossProfitInCents),
                  ),
                  ReportMetricCard(
                    label: l10n.reportExpenses,
                    value: MoneyFormatter.format(summary.expensesInCents),
                  ),
                  ReportMetricCard(
                    label: l10n.reportNetProfit,
                    value: MoneyFormatter.format(summary.netProfitInCents),
                  ),
                  ReportMetricCard(
                    label: l10n.reportAverageTicket,
                    value: MoneyFormatter.format(summary.averageTicketInCents),
                  ),
                  ReportMetricCard(
                    label: l10n.reportSalesCount,
                    value: summary.salesCount.toString(),
                  ),
                  ReportMetricCard(
                    label: l10n.reportVoidsCount,
                    value: summary.voidsCount.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppText(
                l10n.reportExpensesDetail,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 8),
              ReportExpensesSection(expenses: summary.expenses),
              const SizedBox(height: 24),
              AppText(
                l10n.moduleCashRegister,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 8),
              ReportCashSection(columns: columns, summary: summary),
              const SizedBox(height: 24),
              AppText(
                l10n.reportTopProducts,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 8),
              _ProductMetricList(
                emptyMessage: l10n.reportNoProducts,
                emptyTitle: l10n.reportTopProducts,
                metrics: summary.topProducts,
              ),
              const SizedBox(height: 24),
              AppText(
                l10n.reportLowestProducts,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 8),
              _ProductMetricList(
                emptyMessage: l10n.reportNoProducts,
                emptyTitle: l10n.reportLowestProducts,
                metrics: summary.lowestProducts,
              ),
              const SizedBox(height: 24),
              AppText(
                l10n.reportVoidsDetail,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 8),
              ReportVoidsSection(voids: summary.voids),
            ],
          ),
        );
      },
    );
  }
}

class _ProductMetricList extends StatelessWidget {
  const _ProductMetricList({
    required this.emptyMessage,
    required this.emptyTitle,
    required this.metrics,
  });

  final String emptyMessage;
  final String emptyTitle;
  final List<ProductSalesMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        message: emptyMessage,
        title: emptyTitle,
      );
    }

    return Column(
      children: [
        for (final metric in metrics.take(8))
          _ProductMetricTile(metric: metric),
      ],
    );
  }
}

class _ProductMetricTile extends StatelessWidget {
  const _ProductMetricTile({required this.metric});

  final ProductSalesMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.local_cafe_outlined),
      subtitle: AppText(
        '${metric.quantity} ${l10n.reportUnitsSold}',
        variant: AppTextVariant.label,
      ),
      title: AppText(metric.productName),
      trailing: AppText(MoneyFormatter.format(metric.salesInCents)),
    );
  }
}
