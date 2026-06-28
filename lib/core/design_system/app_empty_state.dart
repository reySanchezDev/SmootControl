import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';

/// Empty-state panel for pages that do not have data yet.
class AppEmptyState extends StatelessWidget {
  /// Creates an empty-state message.
  const AppEmptyState({
    required this.message,
    required this.title,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  /// Visual icon.
  final IconData icon;

  /// Empty-state title.
  final String title;

  /// Empty-state detail.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            AppText(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 8),
            AppText(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
