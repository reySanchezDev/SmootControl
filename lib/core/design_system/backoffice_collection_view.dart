import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/design_system/backoffice_data_table.dart';
import 'package:smoo_control/core/design_system/backoffice_pagination_footer.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/utils/search_text.dart';

/// Column contract shared across administrative catalog screens.
class BackofficeListColumn<T> {
  /// Creates an administrative data column.
  const BackofficeListColumn({
    required this.label,
    required this.width,
    required this.cell,
    this.compare,
    this.alignment = Alignment.centerLeft,
  });

  /// Human-readable column heading.
  final String label;

  /// Minimum column width in logical pixels.
  final double width;

  /// Cell widget with complete, accessible content.
  final Widget Function(BuildContext context, T item) cell;

  /// Semantic comparison function; null means not sortable.
  final int Function(T a, T b)? compare;

  /// Common alignment for heading and data.
  final Alignment alignment;
}

/// Reusable search, sort, pagination and responsive rendering for admin lists.
class BackofficeCollectionView<T> extends StatefulWidget {
  /// Builds the collection without imposing domain-specific data logic.
  const BackofficeCollectionView({
    required this.items,
    required this.columns,
    required this.searchTextFor,
    required this.searchLabel,
    required this.emptyMessage,
    required this.emptyTitle,
    this.showSearch = true,
    this.compactBuilder,
    this.onCreate,
    this.globalActions = const [],
    this.rowKey,
    this.rowLabel,
    this.selectionActions,
    super.key,
  }) : assert(
         selectionActions == null || rowKey != null,
         'Selection-based lists need a stable rowKey.',
       );

  /// Current records.
  final List<T> items;

  /// Data columns, excluding per-row actions when selection is enabled.
  final List<BackofficeListColumn<T>> columns;

  /// Domain-backed fields that may be searched.
  final String Function(T item) searchTextFor;

  /// Search field's user-friendly label.
  final String searchLabel;

  /// Whether to render search when a parent already provides filtering.
  final bool showSearch;

  /// No-results description.
  final String emptyMessage;

  /// No-results heading.
  final String emptyTitle;

  /// Optional mobile card renderer.
  final Widget Function(BuildContext context, T item)? compactBuilder;

  /// Optional primary create action in the same fixed command bar.
  final VoidCallback? onCreate;

  /// Explicit page commands shown alongside selected-record commands.
  final List<Widget> globalActions;

  /// Stable identity used only in selection-based catalog lists.
  final String Function(T item)? rowKey;

  /// Record name shown alongside the selection state.
  final String Function(T item)? rowLabel;

  /// Explicit commands; never hidden behind a generic menu.
  final List<BackofficeSelectionAction<T>>? selectionActions;

  @override
  State<BackofficeCollectionView<T>> createState() =>
      _BackofficeCollectionViewState<T>();
}

class _BackofficeCollectionViewState<T>
    extends State<BackofficeCollectionView<T>> {
  final _searchController = TextEditingController();
  String _query = '';
  int _page = 0;
  int _pageSize = 15;
  int _sortColumn = 0;
  bool _ascending = true;
  String? _selectedKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.selectionActions == null ||
          !widget.columns.any((column) {
            final name = column.label.trim().toLowerCase();
            return name == 'acciones' || name == 'actions';
          }),
      'Selection commands must not duplicate an Actions column.',
    );
    final filtered = widget.items.where((item) {
      return containsNormalizedSearch(widget.searchTextFor(item), _query);
    }).toList();
    if (_sortColumn < widget.columns.length) {
      final comparator = widget.columns[_sortColumn].compare;
      if (comparator != null) {
        filtered.sort((a, b) {
          final order = comparator(a, b);
          return _ascending ? order : -order;
        });
      }
    }

    final totalPages = filtered.isEmpty
        ? 1
        : (filtered.length + _pageSize - 1) ~/ _pageSize;
    final current = _page.clamp(0, totalPages - 1);
    final start = current * _pageSize;
    final shown = filtered.skip(start).take(_pageSize).toList();
    T? selected;
    int? selectedIndex;
    if (widget.rowKey != null && widget.selectionActions != null) {
      for (var i = 0; i < shown.length; i++) {
        if (widget.rowKey!(shown[i]) == _selectedKey) {
          selected = shown[i];
          selectedIndex = i;
          break;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 720 && widget.compactBuilder != null;
        return Column(
          children: [
            if (widget.selectionActions != null)
              BackofficeSelectionToolbar<T>(
                actions: widget.selectionActions!,
                selected: selected,
                selectedLabel: selected == null
                    ? null
                    : widget.rowLabel?.call(selected),
                onCreate: widget.onCreate,
                globalActions: widget.globalActions,
              ),
            if (widget.showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: AppSearchField(
                  controller: _searchController,
                  label: widget.searchLabel,
                  onChanged: (value) => setState(() {
                    _query = value;
                    _page = 0;
                    _selectedKey = null;
                  }),
                  onClear: () => setState(() {
                    _searchController.clear();
                    _query = '';
                    _page = 0;
                    _selectedKey = null;
                  }),
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: AppEmptyState(
                        message: widget.emptyMessage,
                        title: widget.emptyTitle,
                      ),
                    )
                  : compact
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: shown.length,
                      itemBuilder: (context, index) => InkWell(
                        onTap: widget.selectionActions == null
                            ? null
                            : () => setState(() {
                                _selectedKey = widget.rowKey!(shown[index]);
                              }),
                        child: Semantics(
                          selected: selectedIndex == index,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedIndex == index
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: widget.compactBuilder!(
                              context,
                              shown[index],
                            ),
                          ),
                        ),
                      ),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                    )
                  : BackofficeDataTable(
                      columns: [
                        for (final column in widget.columns) column.label,
                      ],
                      columnWidths: [
                        for (final column in widget.columns) column.width,
                      ],
                      columnAlignments: [
                        for (final column in widget.columns) column.alignment,
                      ],
                      sortableColumns: [
                        for (final column in widget.columns)
                          column.compare != null,
                      ],
                      sortColumnIndex: _sortColumn,
                      sortAscending: _ascending,
                      onSort: (index) {
                        if (widget.columns[index].compare == null) return;
                        setState(() {
                          if (_sortColumn == index) {
                            _ascending = !_ascending;
                          } else {
                            _sortColumn = index;
                            _ascending = true;
                          }
                          _page = 0;
                        });
                      },
                      selectedRowIndex: selectedIndex,
                      onRowSelected: widget.selectionActions == null
                          ? null
                          : (index) => setState(() {
                              _selectedKey = widget.rowKey!(shown[index]);
                            }),
                      rows: [
                        for (final item in shown)
                          [
                            for (final column in widget.columns)
                              column.cell(context, item),
                          ],
                      ],
                    ),
            ),
            BackofficePaginationFooter(
              rowsPerPage: _pageSize,
              onRowsPerPageChanged: (value) => setState(() {
                _pageSize = value;
                _page = 0;
                _selectedKey = null;
              }),
              firstIndex: start,
              visibleCount: shown.length,
              totalCount: filtered.length,
              pageIndex: current,
              pageCount: totalPages,
              onPrevious: current == 0
                  ? null
                  : () => setState(() {
                      _page = current - 1;
                      _selectedKey = null;
                    }),
              onNext: current + 1 >= totalPages
                  ? null
                  : () => setState(() {
                      _page = current + 1;
                      _selectedKey = null;
                    }),
            ),
          ],
        );
      },
    );
  }
}
