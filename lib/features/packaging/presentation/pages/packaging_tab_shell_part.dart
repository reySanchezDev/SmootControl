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
  });

  final List<T> items;
  final List<BackofficeListColumn<T>> columns;
  final String Function(T) searchTextFor;
  final String searchLabel;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback? onCreate;
  final Widget Function(BuildContext, T) compactBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: BackofficeNewAction(onPressed: onCreate),
          ),
        ),
        Expanded(
          child: BackofficeCollectionView<T>(
            key: ValueKey(searchLabel),
            items: items,
            columns: columns,
            searchTextFor: searchTextFor,
            searchLabel: searchLabel,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            compactBuilder: compactBuilder,
          ),
        ),
      ],
    );
  }
}

Widget _packagingCompactItem({
  required String title,
  required String description,
  required VoidCallback onEdit,
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
          ),
        ],
      ),
    ),
  );
}
