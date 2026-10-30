part of 'products_page.dart';

/// Search and domain filters shared by the product list.
class _ProductsFilterBar extends StatelessWidget {
  const _ProductsFilterBar({
    required this.searchController,
    required this.query,
    required this.status,
    required this.kind,
    required this.category,
    required this.categories,
    required this.categoryPathFor,
    required this.onQueryChanged,
    required this.onKindChanged,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String query;
  final String status;
  final String kind;
  final String? category;
  final List<ProductCategory> categories;
  final String Function(String, List<ProductCategory>) categoryPathFor;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final active = query.isNotEmpty || status != 'all' ||
        kind != 'all' || category != null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 420,
          child: TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Buscar en productos, categorías, precios y estados',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty ? null : IconButton(
                tooltip: 'Borrar búsqueda',
                onPressed: () {
                  searchController.clear();
                  onQueryChanged('');
                },
                icon: const Icon(Icons.close, size: 18),
              ),
              isDense: true,
            ),
          ),
        ),
        _productFilterSelector(
          'Tipo', kind,
          const {'all': 'Todos', 'raw': 'Materia prima',
            'finished': 'Producto terminado'},
          onKindChanged, width: 206,
        ),
        _productFilterSelector(
          'Estado', status,
          const {'all': 'Todos', 'active': 'Activos',
            'inactive': 'Inactivos'},
          onStatusChanged,
        ),
        DropdownMenu<String?>(
          key: ValueKey(category),
          width: 320,
          label: const Text('Categoría'),
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          initialSelection: category,
          dropdownMenuEntries: [
            const DropdownMenuEntry<String?>(value: null, label: 'Todas'),
            for (final entry in categories)
              DropdownMenuEntry<String?>(
                value: entry.id,
                label: entry.parentId == null ? entry.name :
                    categoryPathFor(entry.id, categories),
              ),
          ],
          onSelected: onCategoryChanged,
        ),
        if (active)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar'),
          ),
      ],
    );
  }
}

Widget _productFilterSelector(
  String label,
  String current,
  Map<String, String> choices,
  ValueChanged<String> changed, {
  double width = 148,
}) {
  return SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final option in choices.entries)
          DropdownMenuItem(
            value: option.key,
            child: Text(option.value, softWrap: true),
          ),
      ],
      onChanged: (value) {
        if (value != null) changed(value);
      },
    ),
  );
}

Widget _productStatusLabel(BuildContext context, String label, bool active) {
  final colors = Theme.of(context).colorScheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: active ? colors.primaryContainer : colors.errorContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? colors.onPrimaryContainer : colors.onErrorContainer,
        ),
      ),
    ),
  );
}

int _compareProducts(
  Product a,
  Product b,
  int column,
  String Function(String, List<ProductCategory>) categoryPathFor,
  List<ProductCategory> categories,
) {
  switch (column) {
    case 1:
      return categoryPathFor(a.categoryId, categories).compareTo(
        categoryPathFor(b.categoryId, categories),
      );
    case 2:
      return a.priceInCents.compareTo(b.priceInCents);
    case 3:
      return (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
    case 4:
      return (a.isAvailableInPos ? 1 : 0).compareTo(
        b.isAvailableInPos ? 1 : 0,
      );
    case 5:
      return (a.tracksInventory ? 1 : 0).compareTo(
        b.tracksInventory ? 1 : 0,
      );
    default:
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
