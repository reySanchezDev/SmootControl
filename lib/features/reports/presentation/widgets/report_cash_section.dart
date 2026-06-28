import 'package:flutter/material.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_metric_card.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Cash register metrics for the selected report period.
class ReportCashSection extends StatelessWidget {
  /// Creates a cash report section.
  const ReportCashSection({
    required this.columns,
    required this.summary,
    super.key,
  });

  /// Responsive grid columns.
  final int columns;

  /// Report summary with cash totals.
  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GridView.count(
      childAspectRatio: columns == 1 ? 3.2 : 2.5,
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ReportMetricCard(
          label: l10n.reportCashSessions,
          value: summary.cashSessionsCount.toString(),
        ),
        ReportMetricCard(
          label: l10n.cashOpeningAmount,
          value: MoneyFormatter.format(summary.cashOpeningInCents),
        ),
        ReportMetricCard(
          label: l10n.cashSalesAmount,
          value: MoneyFormatter.format(summary.cashSalesInCents),
        ),
        ReportMetricCard(
          label: l10n.cashExpensesAmount,
          value: MoneyFormatter.format(summary.cashExpensesInCents),
        ),
        ReportMetricCard(
          label: l10n.cashExpectedAmount,
          value: MoneyFormatter.format(summary.cashExpectedInCents),
        ),
        ReportMetricCard(
          label: l10n.cashPhysicalAmount,
          value: MoneyFormatter.format(summary.cashPhysicalInCents),
        ),
        ReportMetricCard(
          label: l10n.cashDifferenceAmount,
          value: MoneyFormatter.format(summary.cashDifferenceInCents),
        ),
      ],
    );
  }
}
