import 'package:flutter/material.dart';

/// Shared desktop data table for administrative modules.
///
/// Uses Material table semantics and the active scoped Backoffice theme.
class BackofficeDataTable extends StatelessWidget {
  /// Creates a standardized Backoffice table.
  const BackofficeDataTable({
    required this.columns,
    required this.rows,
    super.key,
  });

  /// Column labels.
  final List<String> columns;

  /// Data rows with the same number of cells as [columns].
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                colorScheme.surfaceContainerLow,
              ),
              dividerThickness: 0.6,
              columnSpacing: 24,
              horizontalMargin: 20,
              headingRowHeight: 44,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              columns: [
                for (final name in columns) DataColumn(label: Text(name)),
              ],
              rows: [
                for (final cells in rows)
                  DataRow(
                    cells: [for (final cell in cells) DataCell(cell)],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
