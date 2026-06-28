import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_list_section.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/utils/search_text.dart';

/// List section with a reusable local search input.
class AppSearchableListSection<T> extends StatefulWidget {
  /// Creates a searchable list section.
  const AppSearchableListSection({
    required this.emptyMessage,
    required this.emptyTitle,
    required this.itemBuilder,
    required this.items,
    required this.searchLabel,
    required this.searchTextForItem,
    this.emptyIcon = Icons.manage_search_outlined,
    super.key,
  });

  /// Icon shown when no item matches the search query.
  final IconData emptyIcon;

  /// Message shown when no item matches the search query.
  final String emptyMessage;

  /// Title shown when no item matches the search query.
  final String emptyTitle;

  /// Builds each filtered item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Items available to search.
  final List<T> items;

  /// Localized search field label.
  final String searchLabel;

  /// Text used to match each item against the query.
  final String Function(T item) searchTextForItem;

  @override
  State<AppSearchableListSection<T>> createState() =>
      _AppSearchableListSectionState<T>();
}

class _AppSearchableListSectionState<T>
    extends State<AppSearchableListSection<T>> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AppSearchField(
            controller: _controller,
            label: widget.searchLabel,
            onChanged: _changeQuery,
            onClear: _clearQuery,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: widget.emptyIcon,
                    message: widget.emptyMessage,
                    title: widget.emptyTitle,
                  ),
                )
              : AppListSection(
                  children: [
                    for (final item in items) widget.itemBuilder(context, item),
                  ],
                ),
        ),
      ],
    );
  }

  void _changeQuery(String value) {
    setState(() => _query = value);
  }

  void _clearQuery() {
    _controller.clear();
    _changeQuery('');
  }

  List<T> _filteredItems() {
    return widget.items
        .where(
          (item) => containsNormalizedSearch(
            widget.searchTextForItem(item),
            _query,
          ),
        )
        .toList();
  }
}
