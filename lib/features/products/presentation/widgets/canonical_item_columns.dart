import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';

/// Reuses shared tabular contracts for the existing canonical catalog.
List<BackofficeListColumn<CanonicalItem>> canonicalItemColumns() => [

              BackofficeListColumn<CanonicalItem>(
                label: 'Código', width: 130,
                compare: (a, b) => a.code.compareTo(b.code),
                cell: (_, item) => Text(item.code),
              ),
              BackofficeListColumn<CanonicalItem>(
                label: 'Nombre', width: 280,
                compare: (a, b) => a.name.compareTo(b.name),
                cell: (_, item) => Text(item.name),
              ),
              BackofficeListColumn<CanonicalItem>(
                label: 'Tipo', width: 170,
                compare: (a, b) => a.type.label.compareTo(b.type.label),
                cell: (_, item) => Text(item.type.label),
              ),
              BackofficeListColumn<CanonicalItem>(
                label: 'Costo', width: 110,
                alignment: Alignment.centerRight,
                compare: (a, b) => a.cost.compareTo(b.cost),
                cell: (_, item) => Text(item.cost.toStringAsFixed(2)),
              ),
              BackofficeListColumn<CanonicalItem>(
                label: 'Precio', width: 110,
                alignment: Alignment.centerRight,
                compare: (a, b) => a.price.compareTo(b.price),
                cell: (_, item) => Text(item.price.toStringAsFixed(2)),
              ),
              BackofficeListColumn<CanonicalItem>(
                label: 'Estado', width: 110,
                alignment: Alignment.center,
                compare: (a, b) => a.isActive == b.isActive
                    ? 0 : a.isActive ? 1 : -1,
                cell: (_, item) => Text(item.isActive ? 'Activo' : 'Inactivo'),
              ),
];
