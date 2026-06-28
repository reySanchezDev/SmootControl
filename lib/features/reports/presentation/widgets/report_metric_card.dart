import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';

/// Compact metric card used in report grids.
class ReportMetricCard extends StatelessWidget {
  /// Creates a report metric card.
  const ReportMetricCard({
    required this.label,
    required this.value,
    super.key,
  });

  /// Metric label.
  final String label;

  /// Metric value.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText(label, variant: AppTextVariant.label),
            const SizedBox(height: 8),
            AppText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              variant: AppTextVariant.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
