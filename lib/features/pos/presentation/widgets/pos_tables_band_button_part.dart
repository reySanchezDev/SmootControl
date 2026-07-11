part of 'pos_tables_band.dart';

class _TableButton extends StatelessWidget {
  const _TableButton({
    required this.indicator,
    required this.isOccupied,
    required this.isSelected,
    required this.label,
    required this.onRename,
    required this.onPressed,
  });

  final String? indicator;
  final bool isOccupied;
  final bool isSelected;
  final String label;
  final VoidCallback? onRename;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;
    final background = _backgroundColor(colorScheme, semanticColors);
    final foreground = isSelected || isOccupied
        ? semanticColors.tableOnStatus
        : colorScheme.onSurface;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        variant: AppTextVariant.label,
                      ),
                      if (isOccupied) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: semanticColors.tableBadgeBackground,
                          ),
                          child: AppText(
                            indicator ?? l10n.tableOccupiedLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: semanticColors.tableOnStatus,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            variant: AppTextVariant.label,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onRename != null && isSelected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      iconSize: 16,
                      onPressed: onRename,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        height: 28,
                        width: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _backgroundColor(
    ColorScheme colorScheme,
    AppSemanticColors semanticColors,
  ) {
    if (isSelected) return semanticColors.tableSelectedBackground;
    if (isOccupied) return semanticColors.tableOccupiedBackground;
    return colorScheme.surface;
  }
}

class _TableDragFeedback extends StatelessWidget {
  const _TableDragFeedback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 118, maxWidth: 170),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: AppText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            variant: AppTextVariant.label,
          ),
        ),
      ),
    );
  }
}
