import 'package:flutter/material.dart';

/// Shared pagination footer for all administrative Backoffice listings.
class BackofficePaginationFooter extends StatelessWidget {
  /// Uses the same layout, spacing and labels across equivalent pages.
  const BackofficePaginationFooter({
    required this.rowsPerPage,
    required this.onRowsPerPageChanged,
    required this.firstIndex,
    required this.visibleCount,
    required this.totalCount,
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  /// Current records-per-page setting.
  final int rowsPerPage;

  /// Updates page size and resets the current page in the parent widget.
  final ValueChanged<int> onRowsPerPageChanged;

  /// Zero-based start index of the visible records.
  final int firstIndex;

  /// Number of visible records on this page.
  final int visibleCount;

  /// Number of matching records across all pages.
  final int totalCount;

  /// Zero-based page index.
  final int pageIndex;

  /// Total number of pages, at least one.
  final int pageCount;

  /// Previous-page handler; disabled on the first page.
  final VoidCallback? onPrevious;

  /// Next-page handler; disabled on the final page.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final pageSizeControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Registros por página'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: rowsPerPage,
          items: const [
            DropdownMenuItem(value: 10, child: Text('10')),
            DropdownMenuItem(value: 15, child: Text('15')),
            DropdownMenuItem(value: 25, child: Text('25')),
            DropdownMenuItem(value: 50, child: Text('50')),
          ],
          onChanged: (value) {
            if (value != null) onRowsPerPageChanged(value);
          },
        ),
      ],
    );

    final from = totalCount == 0 ? 0 : firstIndex + 1;
    final to = firstIndex + visibleCount;
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$from–$to de $totalCount'),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${pageIndex + 1} / $pageCount'),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 650) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: pageSizeControl,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: navigation,
                ),
              ],
            );
          }
          return Row(
            children: [
              pageSizeControl,
              const Spacer(),
              navigation,
            ],
          );
        },
      ),
    );
  }
}
