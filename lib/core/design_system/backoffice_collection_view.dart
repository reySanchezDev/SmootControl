import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/design_system/backoffice_data_table.dart';

/// Column contract shared across administrative catalog screens.
class BackofficeListColumn<T> {
  /// Creates a sortable data column or a non-sortable actions column.
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
    this.compactBuilder,
    super.key,
  });

  /// Current records.
  final List<T> items;

  /// Data columns. The last column is conventionally Actions.
  final List<BackofficeListColumn<T>> columns;

  /// Domain-backed fields that may be searched.
  final String Function(T item) searchTextFor;

  /// Search field's user-friendly label.
  final String searchLabel;

  /// No-results description.
  final String emptyMessage;

  /// No-results heading.
  final String emptyTitle;

  /// Optional mobile card renderer.
  final Widget Function(BuildContext context, T item)? compactBuilder;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) {
      return widget.searchTextFor(item)
          .toLowerCase()
          .contains(_query.trim().toLowerCase());
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 720 && widget.compactBuilder != null;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: AppSearchField(
                controller: _searchController,
                label: widget.searchLabel,
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 0;
                }),
                onClear: () => setState(() {
                  _searchController.clear();
                  _query = '';
                  _page = 0;
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
                          itemBuilder: (context, index) =>
                              widget.compactBuilder!(context, shown[index]),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                        )
                      : BackofficeDataTable(
                          columns: [
                            for (final column in widget.columns) column.label,
                          ],
                          columnWidths: [
                            for (final column in widget.columns) column.width,
                          ],
                          columnAlignments: [
                            for (final column in widget.columns)
                              column.alignment,
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
                          rows: [
                            for (final item in shown)
                              [
                                for (final column in widget.columns)
                                  column.cell(context, item),
                              ],
                          ],
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text('Registros por página'),
                  DropdownButton<int>(
                    value: _pageSize,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 15, child: Text('15')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _pageSize = value;
                          _page = 0;
                        });
                      }
                    },
                  ),
                  Text(
                    '${filtered.isEmpty ? 0 : start + 1}–'
                    '${start + shown.length} de ${filtered.length}',
                  ),
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: current == 0
                        ? null
                        : () => setState(() => _page = current - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${current + 1} / $totalPages'),
                  IconButton(
                    tooltip: 'Página siguiente',
                    onPressed: current + 1 >= totalPages
                        ? null
                        : () => setState(() => _page = current + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
