import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';

/// Full-width desktop catalog table; hierarchy remains available on mobile.
class CatalogBackofficeTable extends StatelessWidget {
  /// Creates the table without changing category business rules.
  const CatalogBackofficeTable({
    required this.categories,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  /// Existing catalog data.
  final List<ProductCategory> categories;

  /// Edit handler.
  final ValueChanged<ProductCategory> onEdit;

  /// Handler for removing subordinate levels.
  final ValueChanged<ProductCategory> onRemove;

  String _parentName(ProductCategory item) {
    if (item.parentId == null) return '—';
    for (final category in categories) {
      if (category.id == item.parentId) return category.name;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BackofficeCollectionView<ProductCategory>(
      items: categories,
      searchLabel: 'Buscar categoría, subcategoría o categoría superior',
      searchTextFor: (item) =>
          '${item.name} ${_parentName(item)} '
          '${item.parentId == null ? 'categoría' : 'subcategoría'} '
          '${item.isActive ? 'activo' : 'inactivo'}',
      emptyTitle: 'Sin resultados',
      emptyMessage: 'No hay categorías que coincidan con la búsqueda.',
      columns: [
        BackofficeListColumn(
          label: 'Categoría',
          width: 300,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, item) => Text(item.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Tipo',
          width: 160,
          compare: (a, b) =>
              (a.parentId == null ? 0 : 1).compareTo(
                b.parentId == null ? 0 : 1,
              ),
          cell: (_, item) =>
              Text(item.parentId == null ? 'Categoría' : 'Subcategoría'),
        ),
        BackofficeListColumn(
          label: 'Categoría superior',
          width: 250,
          compare: (a, b) =>
              _parentName(a).compareTo(_parentName(b)),
          cell: (_, item) => Text(_parentName(item), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Posición',
          width: 110,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.sortOrder.compareTo(b.sortOrder),
          cell: (_, item) => Text('${item.sortOrder}'),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 125,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
          cell: (_, item) => Text(
            item.isActive ? 'Activo' : 'Inactivo',
            style: TextStyle(
              color: item.isActive ? colors.primary : colors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 258,
          alignment: Alignment.center,
          cell: (_, item) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => onEdit(item),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Editar'),
              ),
              if (item.parentId != null)
                TextButton.icon(
                  onPressed: () => onRemove(item),
                  icon: const Icon(Icons.remove_circle_outline, size: 17),
                  label: const Text('Quitar nivel'),
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
