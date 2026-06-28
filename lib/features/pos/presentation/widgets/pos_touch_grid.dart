import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';

/// Touch-first dynamic button grid for POS bands.
class PosTouchGrid extends StatelessWidget {
  /// Creates a dynamic POS grid.
  const PosTouchGrid({
    required this.children,
    this.minTileHeight = 58,
    this.minTileWidth = 128,
    super.key,
  });

  /// Tiles rendered by the grid.
  final List<Widget> children;

  /// Minimum usable touch width.
  final double minTileWidth;

  /// Minimum usable touch height.
  final double minTileHeight;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxColumns = (constraints.maxWidth / minTileWidth).floor();
        final columns = children.length <= maxColumns
            ? children.length
            : maxColumns.clamp(1, children.length);
        final rows = (children.length / columns).ceil();
        final visibleRows = (constraints.maxHeight / minTileHeight)
            .floor()
            .clamp(1, rows);
        final tileWidth = constraints.maxWidth / columns;
        final tileHeight = constraints.maxHeight / visibleRows;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            childAspectRatio: tileWidth / tileHeight,
            crossAxisCount: columns,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) => children[index],
          itemCount: children.length,
          padding: const EdgeInsets.all(4),
          physics: rows <= visibleRows
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
        );
      },
    );
  }
}

/// Large tactile POS button.
class PosTouchButton extends StatelessWidget {
  /// Creates a POS button.
  const PosTouchButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.tone = PosButtonTone.primary,
    super.key,
  });

  /// Visible label.
  final String label;

  /// Optional icon.
  final IconData? icon;

  /// Selection state.
  final bool selected;

  /// Button color family.
  final PosButtonTone tone;

  /// Tap callback.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      PosButtonTone.danger => colorScheme.error,
      PosButtonTone.neutral =>
        selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
      PosButtonTone.success => colorScheme.tertiary,
      PosButtonTone.primary =>
        selected ? colorScheme.primary : colorScheme.primaryContainer,
    };
    final foreground = switch (tone) {
      PosButtonTone.danger => colorScheme.onError,
      PosButtonTone.neutral =>
        selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
      PosButtonTone.success => colorScheme.onTertiary,
      PosButtonTone.primary =>
        selected ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
    };

    return Material(
      borderRadius: BorderRadius.circular(4),
      color: onPressed == null
          ? colorScheme.surfaceContainerHighest.withValues(alpha: .55)
          : background,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Icon(icon, color: foreground, size: 18),
                if (icon != null) const SizedBox(height: 2),
                Flexible(
                  child: AppText(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    variant: AppTextVariant.label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Button color family.
enum PosButtonTone {
  /// Main POS tiles.
  primary,

  /// Neutral utility actions.
  neutral,

  /// Positive/payment action.
  success,

  /// Destructive action.
  danger,
}
