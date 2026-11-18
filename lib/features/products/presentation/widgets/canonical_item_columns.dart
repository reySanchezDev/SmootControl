import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_labels.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shared columns for the canonical catalog; generated code stays internal.
List<BackofficeListColumn<CanonicalItem>> canonicalItemColumns(
  List<ProductCategory> categories,
  AppLocalizations l10n,
) => [
  BackofficeListColumn<CanonicalItem>(
    label: 'Código comercial',
    width: 150,
    alignment: Alignment.center,
    compare: (a, b) => (a.commercialCode ?? 0).compareTo(
      b.commercialCode ?? 0,
    ),
    cell: (_, item) => Text(item.commercialCode?.toString() ?? '—'),
  ),
  BackofficeListColumn<CanonicalItem>(
    label: 'Categoría',
    width: 180,
    compare: (a, b) => _categoryName(a, categories).compareTo(
      _categoryName(b, categories),
    ),
    cell: (_, item) => Text(_categoryName(item, categories)),
  ),
  BackofficeListColumn<CanonicalItem>(
    label: l10n.canonicalItemRoleField,
    width: 170,
    compare: (a, b) => canonicalItemRoleLabel(l10n, a.itemClass).compareTo(
      canonicalItemRoleLabel(l10n, b.itemClass),
    ),
    cell: (_, item) => Text(canonicalItemRoleLabel(l10n, item.itemClass)),
  ),
  BackofficeListColumn<CanonicalItem>(
    label: 'Nombre',
    width: 280,
    compare: (a, b) => a.name.compareTo(b.name),
    cell: (_, item) => Text(item.name),
  ),
  BackofficeListColumn<CanonicalItem>(
    label: l10n.canonicalItemTypeField,
    width: 170,
    compare: (a, b) => canonicalItemTypeLabel(l10n, a.type).compareTo(
      canonicalItemTypeLabel(l10n, b.type),
    ),
    cell: (_, item) => Text(canonicalItemTypeLabel(l10n, item.type)),
  ),
  BackofficeListColumn<CanonicalItem>(
    label: 'Costo',
    width: 110,
    alignment: Alignment.centerRight,
    compare: (a, b) => a.cost.compareTo(b.cost),
    cell: (_, item) => Text(item.cost.toStringAsFixed(2)),
  ),
  BackofficeListColumn<CanonicalItem>(
    label: 'Precio',
    width: 110,
    alignment: Alignment.centerRight,
    compare: (a, b) => a.price.compareTo(b.price),
    cell: (_, item) => Text(item.price.toStringAsFixed(2)),
  ),
  BackofficeListColumn<CanonicalItem>(
    label: 'Estado',
    width: 110,
    alignment: Alignment.center,
    compare: (a, b) => a.isActive == b.isActive
        ? 0
        : a.isActive
        ? 1
        : -1,
    cell: (_, item) => Text(item.isActive ? 'Activo' : 'Inactivo'),
  ),
];

String _categoryName(
  CanonicalItem item,
  List<ProductCategory> categories,
) {
  for (final category in categories) {
    if (category.id == item.categoryId) return category.name;
  }
  return 'Sin categoría';
}
