import 'package:flutter/material.dart';

/// Executive Ivory dimensions and motion tokens for the Backoffice sidebar.
///
/// Kept independent of the POS navigation and styling.
abstract final class BackofficeSidebarTokens {
  static const double expandedWidth = 248;
  static const double collapsedWidth = 64;
  static const double handleProtrusion = 20;
  static const double handleHitHeight = 64;
  static const Duration transition = Duration(milliseconds: 240);
}

/// One permission-filtered navigation destination.
@immutable
class BackofficeNavItem {
  const BackofficeNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.group = 'General',
  });

  final String id;
  final String label;
  final IconData icon;
  final String group;
}

/// Navigation rail with a centered edge-mounted curved collapse handle.
///
/// [items] must already be filtered by the existing route access policy.
/// State is externally controlled so a Backoffice shell can persist it.
class BackofficeSidebar extends StatelessWidget {
  const BackofficeSidebar({
    required this.items,
    required this.activeId,
    required this.collapsed,
    required this.onCollapsedChanged,
    required this.onSelected,
    super.key,
  });

  final List<BackofficeNavItem> items;
  final String activeId;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;
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
              painter: _SidebarShapePainter(
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
                      Icon(Icons.restaurant_menu_rounded, color: colors.primary),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Text('SmooControl',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12),
                    children: [
                      for (final entry in groups.entries) ...[
                        if (!collapsed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                                child: Material(
                                  color: item.id == activeId
                                      ? colors.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => onSelected(item.id),
                                    child: SizedBox(
                                      height: 42,
                                      child: Row(
                                        mainAxisAlignment: collapsed
                                            ? MainAxisAlignment.center
                                            : MainAxisAlignment.start,
                                        children: [
                                          if (!collapsed) const SizedBox(width: 12),
                                          Icon(item.icon, size: 20,
                                              color: item.id == activeId
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurfaceVariant),
                                          if (!collapsed) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                item.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}

class _SidebarShapePainter extends CustomPainter {
  const _SidebarShapePainter({
    required this.baseWidth,
    required this.protrusion,
    required this.fill,
    required this.edge,
  });

  final double baseWidth;
  final double protrusion;
  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    const halfNotch = 38.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(baseWidth, 0)
      ..lineTo(baseWidth, center - halfNotch)
      ..cubicTo(baseWidth, center - 22, baseWidth + protrusion,
          center - 22, baseWidth + protrusion, center)
      ..cubicTo(baseWidth + protrusion, center + 22, baseWidth,
          center + 22, baseWidth, center + halfNotch)
      ..lineTo(baseWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _SidebarShapePainter old) =>
      baseWidth != old.baseWidth ||
      protrusion != old.protrusion ||
      fill != old.fill ||
      edge != old.edge;
}
