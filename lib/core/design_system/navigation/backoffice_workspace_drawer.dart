import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_workspace.dart';

/// Module-grouped navigation for narrow Backoffice viewports.
class BackofficeWorkspaceDrawer extends StatelessWidget {
  /// Creates the mobile drawer from permission-filtered destinations.
  const BackofficeWorkspaceDrawer({
    required this.items,
    required this.activeId,
    required this.onSelected,
    super.key,
  });

  /// Destinations in business-priority order.
  final List<BackofficeWorkspaceItem> items;

  /// Currently active page identifier.
  final String? activeId;

  /// Triggered when a user chooses an authorized module.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<BackofficeWorkspaceItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.restaurant_menu_rounded,
              color: scheme.primary,
            ),
            title: Text(
              'SmooControl',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(),
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 6),
              child: Text(
                group.key.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            for (final item in group.value)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label, softWrap: true),
                selected: item.id == activeId,
                onTap: () => onSelected(item.id),
              ),
          ],
        ],
      ),
    );
  }
}
