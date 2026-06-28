import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_list_section.dart';
import 'package:smoo_control/core/utils/search_text.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/presentation/widgets/catalog_category_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Collapsible category tree used by catalog maintenance.
class CatalogTreeList extends StatefulWidget {
  /// Creates a category tree.
  const CatalogTreeList({
    required this.categories,
    required this.onEdit,
    required this.onRemove,
    this.searchQuery = '',
    super.key,
  });

  /// Categories to render.
  final List<ProductCategory> categories;

  /// Edit callback.
  final ValueChanged<ProductCategory> onEdit;

  /// Remove level callback. Only subcategories can be removed.
  final ValueChanged<ProductCategory> onRemove;

  /// Current search query.
  final String searchQuery;

  @override
  State<CatalogTreeList> createState() => _CatalogTreeListState();
}

class _CatalogTreeListState extends State<CatalogTreeList> {
  final Set<String> _knownRootIds = {};
  String? _expandedRootId;
  bool _initializedCollapsedRoots = false;

  @override
  void didUpdateWidget(CatalogTreeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rootIds = _rootCategories().map((category) => category.id).toSet();
    _knownRootIds.removeWhere((id) => !rootIds.contains(id));
    if (_expandedRootId != null && !rootIds.contains(_expandedRootId)) {
      _expandedRootId = null;
    }
    _collapseNewRoots();
  }

  @override
  Widget build(BuildContext context) {
    _collapseRootsOnFirstBuild();
    final entries = _visibleEntries();
    final l10n = AppLocalizations.of(context);

    if (entries.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.manage_search_outlined,
          message: l10n.emptySearchMessage,
          title: l10n.emptySearchTitle,
        ),
      );
    }

    return AppListSection(
      children: [
        for (final entry in entries)
          CatalogCategoryTile(
            category: entry.category,
            depth: entry.depth,
            hasChildren: _hasChildren(entry.category.id),
            isCollapsed: _expandedRootId != entry.category.id,
            parentPath: _parentPathFor(entry.category),
            onEdit: () => widget.onEdit(entry.category),
            onRemove: entry.category.parentId == null
                ? null
                : () => widget.onRemove(entry.category),
            onToggleRoot:
                entry.category.parentId == null &&
                    _hasChildren(entry.category.id)
                ? () => _toggleRoot(entry.category.id)
                : null,
          ),
      ],
    );
  }

  void _toggleRoot(String categoryId) {
    setState(() {
      _expandedRootId = _expandedRootId == categoryId ? null : categoryId;
    });
  }

  void _collapseRootsOnFirstBuild() {
    if (_initializedCollapsedRoots) return;
    _initializedCollapsedRoots = true;
    _collapseNewRoots();
  }

  void _collapseNewRoots() {
    for (final root in _rootCategories()) {
      _knownRootIds.add(root.id);
    }
  }

  List<_CategoryEntry> _visibleEntries() {
    if (widget.searchQuery.trim().isNotEmpty) {
      return _searchEntries();
    }

    final entries = <_CategoryEntry>[];
    for (final root in _rootCategories()) {
      entries.add(_CategoryEntry(category: root, depth: 0));
      if (_expandedRootId == root.id) {
        _addChildren(root.id, 1, entries);
      }
    }

    return entries;
  }

  List<_CategoryEntry> _searchEntries() {
    final matches = widget.categories.where(_matchesSearch).toList()
      ..sort((first, second) {
        final firstPath = _pathFor(first);
        final secondPath = _pathFor(second);
        return firstPath.compareTo(secondPath);
      });

    return [
      for (final category in matches)
        _CategoryEntry(
          category: category,
          depth: _depthFor(category),
        ),
    ];
  }

  void _addChildren(
    String parentId,
    int depth,
    List<_CategoryEntry> entries,
  ) {
    for (final child in _childrenOf(parentId)) {
      entries.add(_CategoryEntry(category: child, depth: depth));
      _addChildren(child.id, depth + 1, entries);
    }
  }

  List<ProductCategory> _rootCategories() {
    final ids = widget.categories.map((category) => category.id).toSet();
    return widget.categories.where((category) {
        final parentId = category.parentId;
        return parentId == null || !ids.contains(parentId);
      }).toList()
      ..sort((first, second) => first.sortOrder.compareTo(second.sortOrder));
  }

  List<ProductCategory> _childrenOf(String parentId) {
    return widget.categories
        .where((category) => category.parentId == parentId)
        .toList()
      ..sort((first, second) => first.sortOrder.compareTo(second.sortOrder));
  }

  bool _hasChildren(String categoryId) {
    return widget.categories.any((category) => category.parentId == categoryId);
  }

  String? _parentPathFor(ProductCategory category) {
    final parents = <String>[];
    var parentId = category.parentId;
    final visited = <String>{category.id};

    while (parentId != null && visited.add(parentId)) {
      final parent = _categoryById(parentId);
      if (parent == null) break;
      parents.insert(0, parent.name);
      parentId = parent.parentId;
    }

    if (parents.isEmpty) return null;
    return parents.join(' > ');
  }

  String _pathFor(ProductCategory category) {
    final parentPath = _parentPathFor(category);
    if (parentPath == null) return category.name;

    return '$parentPath > ${category.name}';
  }

  bool _matchesSearch(ProductCategory category) {
    return containsNormalizedSearch(_pathFor(category), widget.searchQuery);
  }

  int _depthFor(ProductCategory category) {
    var depth = 0;
    var parentId = category.parentId;
    final visited = <String>{category.id};

    while (parentId != null && visited.add(parentId)) {
      final parent = _categoryById(parentId);
      if (parent == null) break;
      depth++;
      parentId = parent.parentId;
    }

    return depth;
  }

  ProductCategory? _categoryById(String id) {
    for (final category in widget.categories) {
      if (category.id == id) return category;
    }

    return null;
  }
}

class _CategoryEntry {
  const _CategoryEntry({
    required this.category,
    required this.depth,
  });

  final ProductCategory category;
  final int depth;
}
