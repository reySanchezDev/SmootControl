import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Compact fortnight indicators for the monthly operational report.
class MonthlyOperationalPeriodCutsCard extends StatelessWidget {
  /// Creates the period cuts card.
  const MonthlyOperationalPeriodCutsCard({required this.report, super.key});

  /// Report data.
  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              l10n.monthlyOperationalFortnightCuts,
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                if (compact) {
                  return Column(
                    children: [
                      for (final cut in report.periodCuts)
                        _PeriodCutTile(cut: cut),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (final cut in report.periodCuts)
                      Expanded(child: _PeriodCutTile(cut: cut)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodCutTile extends StatelessWidget {
  const _PeriodCutTile({required this.cut});

  final MonthlyOperationalPeriodCut cut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final label = cut.labelKey == 'first_half'
        ? l10n.monthlyOperationalFirstHalf
        : l10n.monthlyOperationalSecondHalf;
    final balanceLabel = cut.isCovered
        ? l10n.monthlyOperationalEstimatedSurplus
        : l10n.monthlyOperationalMissingToCover;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    cut.isCovered
                        ? Icons.check_circle_outline
                        : Icons.timelapse_outlined,
                    color: cut.isCovered
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(label, variant: AppTextVariant.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AmountLine(
                label: l10n.reportGrossProfit,
                value: cut.grossProfitInCents,
              ),
              _AmountLine(
                label: l10n.monthlyOperationalMonthlyObligations,
                value: cut.obligationInCents,
              ),
              _AmountLine(label: balanceLabel, value: cut.balanceInCents.abs()),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (cut.coveragePercent / 100).clamp(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: AppText(label, variant: AppTextVariant.label)),
          AppText(
            MoneyFormatter.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}
