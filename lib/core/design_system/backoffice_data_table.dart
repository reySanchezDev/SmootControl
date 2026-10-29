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
    super.key,
  });

  /// Column titles shown in the fixed header.
  final List<String> columns;

  /// Cells rendered in the independently scrolling body.
  final List<List<Widget>> rows;

  /// Optional fixed width for each column.
  final List<double>? columnWidths;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final widths = columnWidths ?? List<double>.filled(columns.length, 160);
    assert(widths.length == columns.length, 'Every column needs a width.');
    assert(
      rows.every((row) => row.length == columns.length),
      'Every row must contain one cell per column.',
    );
    final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);

    Widget cell(Widget child, {bool heading = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
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

    final tableWidths = <int, TableColumnWidth>{
      for (var i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i]),
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth < constraints.maxWidth
                ? constraints.maxWidth
                : totalWidth,
            child: Column(
              children: [
                ColoredBox(
                  color: scheme.surfaceContainerLow,
                  child: Table(
                    columnWidths: tableWidths,
                    children: [
                      TableRow(
                        children: [
                          for (final title in columns)
                            SizedBox(
                              height: 38,
                              child: cell(Text(title), heading: true),
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
                        columnWidths: tableWidths,
                        children: [
                          TableRow(
                            children: [
                              for (final value in rows[index])
                                SizedBox(
                                  height: 42,
                                  child: cell(value),
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
        ),
      ),
    );
  }
}
