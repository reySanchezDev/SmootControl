import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Coverage indicator card for the operational report.
class MonthlyOperationalCoverageCard extends StatelessWidget {
  /// Creates the coverage card.
  const MonthlyOperationalCoverageCard({required this.report, super.key});

  /// Report data.
  final MonthlyOperationalReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              l10n.monthlyOperationalCoverageIndicators,
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 8),
            if (report.coverageRows.isEmpty)
              AppText(l10n.monthlyOperationalNoCoverageConfigured)
            else
              for (final row in report.coverageRows)
                _CoverageObligationTile(row: row),
          ],
        ),
      ),
    );
  }
}

class _CoverageObligationTile extends StatelessWidget {
  const _CoverageObligationTile({required this.row});

  final MonthlyOperationalCoverageRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final covered = row.pendingInCents == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                covered ? Icons.check_circle_outline : Icons.timelapse,
                color: covered ? colorScheme.primary : colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  row.categoryName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  variant: AppTextVariant.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppText(
            '${_typeLabel(l10n, row.typeLabel)} - '
            '${_frequencyLabel(l10n, row.frequencyLabel)}'
            ' - ${_dueDays(row.dueDays, l10n)}',
            variant: AppTextVariant.label,
          ),
          const SizedBox(height: 6),
          OperationalAmountRow(
            label: l10n.monthlyOperationalCoverageGoal,
            value: row.projectedInCents,
          ),
          OperationalAmountRow(
            label: l10n.monthlyOperationalCoverageActual,
            value: row.actualInCents,
          ),
          OperationalAmountRow(
            label: l10n.monthlyOperationalCoveragePending,
            value: row.pendingInCents,
          ),
          const Divider(),
        ],
      ),
    );
  }

  String _dueDays(List<int> days, AppLocalizations l10n) {
    if (days.isEmpty) return l10n.monthlyOperationalNoDueDays;
    return l10n.monthlyOperationalDueDays(days.join(', '));
  }

  String _typeLabel(AppLocalizations l10n, String value) {
    return switch (value) {
      'fixed' => l10n.expenseCoverageTypeFixed,
      'variable' => l10n.expenseCoverageTypeVariable,
      _ => l10n.monthlyOperationalNoCoverageType,
    };
  }

  String _frequencyLabel(AppLocalizations l10n, String value) {
    return switch (value) {
      'weekly' => l10n.expenseCoverageFrequencyWeekly,
      'biweekly' => l10n.expenseCoverageFrequencyBiweekly,
      'monthly' => l10n.expenseCoverageFrequencyMonthly,
      'custom' => l10n.expenseCoverageFrequencyCustom,
      _ => l10n.monthlyOperationalNoCoverageFrequency,
    };
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
