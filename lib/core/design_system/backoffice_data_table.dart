import 'package:flutter/material.dart';

/// Desktop table with a fixed column header and independently scrolling rows.
///
/// Its horizontal viewport is shared by both sections, keeping alignment exact.
class BackofficeDataTable extends StatelessWidget {
  /// Creates a table with a fixed header and a scrollable body.
  const BackofficeDataTable({
    required this.columns,
    required this.rows,
    this.columnWidths,
    this.columnAlignments,
    this.sortableColumns,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    super.key,
  });

  /// Column titles shown in the fixed header.
  final List<String> columns;

  /// Cells rendered in the independently scrolling body.
  final List<List<Widget>> rows;

  /// Optional fixed width for each column.
  final List<double>? columnWidths;

  /// Alignment for each column, including its heading and every cell.
  final List<Alignment>? columnAlignments;

  /// Whether each column supports sort; defaults to excluding the last.
  final List<bool>? sortableColumns;

  /// Currently sorted column, if any.
  final int? sortColumnIndex;

  /// Sort direction.
  final bool sortAscending;

  /// Invoked when a sortable header is selected.
  final ValueChanged<int>? onSort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final widths = columnWidths ?? List<double>.filled(columns.length, 160);
    assert(widths.length == columns.length, 'Every column needs a width.');
    assert(
      columnAlignments == null || columnAlignments!.length == columns.length,
      'Every column needs an alignment.',
    );
    assert(
      sortableColumns == null || sortableColumns!.length == columns.length,
      'Every column needs a sortability value.',
    );
    assert(
      rows.every((row) => row.length == columns.length),
      'Every row must contain one cell per column.',
    );
    final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);

    Widget cell(Widget child, int column, {bool heading = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Align(
        alignment: columnAlignments?[column] ?? Alignment.centerLeft,
        heightFactor: 1,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: heading ? 12 : 13,
            fontWeight: heading ? FontWeight.w600 : FontWeight.w400,
            color: heading ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
          child: child,
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth > totalWidth
              ? constraints.maxWidth / totalWidth
              : 1.0;
          final effectiveWidths = <int, TableColumnWidth>{
            for (var i = 0; i < widths.length; i++)
              i: FixedColumnWidth(widths[i] * scale),
          };
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth * scale,
              child: Column(
                children: [
                  ColoredBox(
                    color: scheme.surfaceContainerLow,
                    child: Table(
                      columnWidths: effectiveWidths,
                      children: [
                        TableRow(
                          children: [
                            for (var i = 0; i < columns.length; i++)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 42,
                                ),
                                child: InkWell(
                                  onTap: onSort == null ||
                                          !(sortableColumns?[i] ??
                                              i != columns.length - 1)
                                      ? null
                                      : () => onSort!(i),
                                  child: cell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            columns[i],
                                            softWrap: true,
                                          ),
                                        ),
                                        if (onSort != null &&
                                            (sortableColumns?[i] ??
                                                i != columns.length - 1)) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            sortColumnIndex == i
                                                ? (sortAscending
                                                      ? Icons.arrow_upward
                                                      : Icons.arrow_downward)
                                                : Icons.unfold_more,
                                            size: 13,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ],
                                      ],
                                    ),
                                    i,
                                    heading: true,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: ListView.builder(
                      primary: false,
                      itemCount: rows.length,
                      itemBuilder: (context, index) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? scheme.surface
                              : scheme.surfaceContainerLowest,
                          border: Border(
                            bottom: BorderSide(color: scheme.outlineVariant),
                          ),
                        ),
                        child: Table(
                          columnWidths: effectiveWidths,
                          children: [
                            TableRow(
                              children: [
                                for (var i = 0; i < columns.length; i++)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 44,
                                    ),
                                    child: cell(rows[index][i], i),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
