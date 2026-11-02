import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// User-facing row for a category or subcategory level.
class CatalogCategoryTile extends StatelessWidget {
  /// Creates a catalog category row.
  const CatalogCategoryTile({
    required this.category,
    required this.depth,
    required this.hasChildren,
    required this.isCollapsed,
    required this.onEdit,
    required this.onRemove,
    required this.onToggleRoot,
    required this.parentPath,
    this.onSelect,
    this.selected = false,
    super.key,
  });

  /// Category level displayed by the row.
  final ProductCategory category;

  /// Visual nesting depth.
  final int depth;

  /// Whether this category has child levels.
  final bool hasChildren;

  /// Whether the root branch is collapsed.
  final bool isCollapsed;

  /// Opens category edition.
  final VoidCallback onEdit;

  /// Removes the subcategory level.
  final VoidCallback? onRemove;

  /// Toggles a root group.
  final VoidCallback? onToggleRoot;

  /// Parent path for subcategory labels.
  final String? parentPath;

  /// Optional catalog selection mode (no duplicate row actions).
  final VoidCallback? onSelect;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typeLabel = category.isSubcategory
        ? l10n.categoryTypeSubcategory
        : l10n.categoryTypeCategory;
    final statusLabel = category.isActive
        ? l10n.activeStatus
        : l10n.inactiveStatus;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return ListTile(
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          contentPadding: EdgeInsets.only(left: 8 + (depth * 24), right: 16),
          leading: _leadingIcon(context, l10n),
          onTap: onSelect ?? onToggleRoot,
          subtitle: AppText(
            _subtitle(l10n, typeLabel, statusLabel),
            variant: AppTextVariant.label,
          ),
          title: AppText(
            category.name,
          ),
          trailing: onSelect != null
              ? null
              : AppTileActions(
                  compact: compact,
                  actions: [
                    if (onRemove != null)
                      AppTileAction(
                        color: Theme.of(context).colorScheme.error,
                        icon: Icons.delete_outline,
                        label: l10n.removeAction,
                        onPressed: onRemove!,
                      ),
                    AppTileAction(
                      icon: Icons.edit_outlined,
                      label: l10n.editAction,
                      onPressed: onEdit,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _leadingIcon(BuildContext context, AppLocalizations l10n) {
    if (onToggleRoot == null) {
      return Icon(
        category.isSubcategory
            ? Icons.subdirectory_arrow_right
            : Icons.category_outlined,
      );
    }

    return IconButton(
      icon: Icon(isCollapsed ? Icons.chevron_right : Icons.expand_more),
      onPressed: onToggleRoot,
      tooltip: isCollapsed ? l10n.expandGroupAction : l10n.collapseGroupAction,
    );
  }

  String _subtitle(
    AppLocalizations l10n,
    String typeLabel,
    String statusLabel,
  ) {
    final path = parentPath;
    final groupLabel = hasChildren && category.parentId == null
        ? ' - ${isCollapsed ? l10n.collapsedStatus : l10n.expandedStatus}'
        : '';
    final positionLabel = 'Posicion ${category.sortOrder}';
    if (path == null) {
      return '$typeLabel - $positionLabel - $statusLabel$groupLabel';
    }

    return '$typeLabel - $positionLabel - '
        '${l10n.categoryInsideOf}: $path - $statusLabel';
  }
}
