import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/theme/app_semantic_colors.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Header and actions for the original order panel.
class SplitOriginalHeader extends StatelessWidget {
  /// Creates the original split header.
  const SplitOriginalHeader({
    required this.compact,
    required this.title,
    required this.onAddAccount,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  /// Panel title.
  final String title;

  /// Whether the header should use tighter spacing.
  final bool compact;

  /// Adds a new split account.
  final VoidCallback onAddAccount;

  /// Cancels split account editing.
  final VoidCallback onCancel;

  /// Confirms current account split.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticColors = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          variant: AppTextVariant.titleMedium,
        ),
        SizedBox(height: compact ? 8 : 12),
        Row(
          children: [
            Expanded(
              child: _SplitHeaderAction(
                key: const ValueKey('split-confirm'),
                background: semanticColors.splitConfirmAction,
                height: compact ? 40 : 44,
                foreground: semanticColors.onSplitAction,
                label: l10n.confirmAction,
                onPressed: onConfirm,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SplitHeaderAction(
                background: semanticColors.splitCancelAction,
                height: compact ? 40 : 44,
                foreground: semanticColors.onSplitAction,
                label: l10n.cancelAction,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 74,
              child: _SplitHeaderAction(
                key: const ValueKey('split-add-account'),
                background: semanticColors.splitAddAction,
                height: compact ? 40 : 44,
                foreground: semanticColors.onSplitAction,
                label: '+',
                onPressed: onAddAccount,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitHeaderAction extends StatelessWidget {
  const _SplitHeaderAction({
    required this.background,
    required this.height,
    required this.foreground,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final Color background;
  final Color foreground;
  final double height;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppText(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
