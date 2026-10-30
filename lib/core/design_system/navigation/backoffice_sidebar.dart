import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_sidebar_shape.dart';

/// Executive Ivory dimensions and motion tokens for the Backoffice sidebar.
///
/// Kept independent of the POS navigation and styling.
abstract final class BackofficeSidebarTokens {
  /// Width of the expanded sidebar content.
  static const double expandedWidth = 248;

  /// Width of the collapsed sidebar content.
  static const double collapsedWidth = 64;

  /// Width reserved for the centered collapse handle.
  static const double handleProtrusion = 20;

  /// Vertical hit area of the collapse handle.
  static const double handleHitHeight = 64;

  /// Duration used for sidebar width and handle transitions.
  static const Duration transition = Duration(milliseconds: 240);
}

/// One permission-filtered navigation destination.
@immutable
class BackofficeNavItem {
  /// Creates a navigation destination.
  const BackofficeNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.group = 'General',
  });

  /// Stable identifier passed to the shell when this item is selected.
  final String id;

  /// Visible destination label when the sidebar is expanded.
  final String label;

  /// Icon displayed for this destination.
  final IconData icon;

  /// Group heading used when the sidebar is expanded.
  final String group;
}

/// Navigation rail with a centered edge-mounted curved collapse handle.
///
/// [items] must already be filtered by the existing route access policy.
/// State is externally controlled so a Backoffice shell can persist it.
class BackofficeSidebar extends StatelessWidget {
  /// Creates a controlled Backoffice sidebar.
  const BackofficeSidebar({
    required this.items,
    required this.activeId,
    required this.collapsed,
    required this.onCollapsedChanged,
    required this.onSelected,
    super.key,
  });

  /// Permission-filtered destinations to display.
  final List<BackofficeNavItem> items;

  /// Identifier of the currently selected destination.
  final String activeId;

  /// Whether labels and group headings are hidden.
  final bool collapsed;

  /// Called when the centered handle changes the collapsed state.
  final ValueChanged<bool> onCollapsedChanged;

  /// Called when a destination is selected.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = collapsed
        ? BackofficeSidebarTokens.collapsedWidth
        : BackofficeSidebarTokens.expandedWidth;
    final groups = <String, List<BackofficeNavItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }

    return AnimatedContainer(
      duration: BackofficeSidebarTokens.transition,
      curve: Curves.easeOutCubic,
      width: width + BackofficeSidebarTokens.handleProtrusion,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BackofficeSidebarShapePainter(
                baseWidth: width,
                protrusion: BackofficeSidebarTokens.handleProtrusion,
                fill: colors.surfaceContainerLow,
                edge: colors.outlineVariant,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            width: width,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Tooltip(
                  message: 'SmooControl',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        color: colors.primary,
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Text(
                          'SmooControl',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 8 : 12,
                    ),
                    children: [
                      for (final entry in groups.entries) ...[
                        if (!collapsed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                        for (final item in entry.value)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Tooltip(
                              message: collapsed ? item.label : '',
                              child: Semantics(
                                selected: item.id == activeId,
                                button: true,
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        (event.logicalKey ==
                                                LogicalKeyboardKey.enter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.space)) {
                                      onSelected(item.id);
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Material(
                                    color: item.id == activeId
                                        ? colors.primaryContainer
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => onSelected(item.id),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(minHeight: 42),
                                        child: Row(
                                          mainAxisAlignment: collapsed
                                              ? MainAxisAlignment.center
                                              : MainAxisAlignment.start,
                                          children: [
                                            if (!collapsed)
                                              const SizedBox(width: 12),
                                            Icon(
                                              item.icon,
                                              size: 20,
                                              color: item.id == activeId
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurfaceVariant,
                                            ),
                                            if (!collapsed) ...[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  item.label,
                                                  softWrap: true,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          AnimatedPositioned(
            duration: BackofficeSidebarTokens.transition,
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: width,
            child: Center(
              child: Tooltip(
                message: collapsed ? 'Expandir menú' : 'Contraer menú',
                child: Semantics(
                  label: collapsed ? 'Expandir menú' : 'Contraer menú',
                  button: true,
                  child: SizedBox(
                    width: BackofficeSidebarTokens.handleProtrusion,
                    height: BackofficeSidebarTokens.handleHitHeight,
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey == LogicalKeyboardKey.space)) {
                          onCollapsedChanged(!collapsed);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => onCollapsedChanged(!collapsed),
                          child: Center(
                            child: Icon(
                              collapsed
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

