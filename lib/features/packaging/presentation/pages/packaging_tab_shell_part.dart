part of 'packaging_page.dart';

/// Standard Backoffice layout for each operational packaging catalog tab.
class _PackagingTabShell<T> extends StatelessWidget {
  const _PackagingTabShell({
    required this.items,
    required this.columns,
    required this.searchTextFor,
    required this.searchLabel,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onCreate,
    required this.compactBuilder,
    required this.rowKey,
    required this.rowLabel,
    required this.selectionActions,
  });

  final List<T> items;
  final List<BackofficeListColumn<T>> columns;
  final String Function(T) searchTextFor;
  final String searchLabel;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback? onCreate;
  final Widget Function(BuildContext, T) compactBuilder;
  final String Function(T) rowKey;
  final String Function(T) rowLabel;
  final List<BackofficeSelectionAction<T>> selectionActions;

  @override
  Widget build(BuildContext context) {
    return BackofficeCollectionView<T>(
      key: ValueKey(searchLabel),
      items: items,
      columns: columns,
      onCreate: onCreate,
      rowKey: rowKey,
      rowLabel: rowLabel,
      selectionActions: selectionActions,
      searchTextFor: searchTextFor,
      searchLabel: searchLabel,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      compactBuilder: compactBuilder,
    );
  }
}

Widget _packagingCompactItem({
  required String title,
  required String description,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, softWrap: true),
          const SizedBox(height: 6),
          Text(description, softWrap: true),
        ],
      ),
    ),
  );
}
