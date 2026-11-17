// The compact record declarations keep this maintained file under SMO-001.

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_action_feedback.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/packaging/domain/entities/canonical_consumption_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/presentation/pages/canonical_packaging_rules_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_catalog_access.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_columns.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_editor.dart';
import 'package:smoo_control/features/recipes/domain/entities/canonical_recipe.dart';
import 'package:smoo_control/features/recipes/presentation/pages/canonical_recipe_dialog.dart';

part 'canonical_items_content_actions_part.dart';

/// QA-only canonical article workspace, isolated from the legacy writers.
class CanonicalItemsContent extends StatefulWidget {
  /// Creates the canonical Products catalog content.
  const CanonicalItemsContent({super.key});

  @override
  State<CanonicalItemsContent> createState() => _CanonicalItemsContentState();
}

class _CanonicalItemsContentState extends State<CanonicalItemsContent> {
  SupabaseAdminRepository get _repository =>
      serviceLocator<SupabaseAdminRepository>();
  late Future<AppResult<List<CanonicalItem>>> _items = _repository
      .getCanonicalItems();
  late final Future<({bool products, bool packaging})> _access =
      loadCanonicalCatalogAccess(_repository);
  late Future<List<ProductCategory>> _categories = _loadCategories();
  ({
    CanonicalItem? item,
    List<MeasurementUnit> units,
    List<ProductCategory> categories,
    List<CanonicalClassification> classifications,
    int? initialCommercialCode,
  })?
  _editor;
  CanonicalItemType? _filter;
  bool _busy = false;
  void _refresh() {
    setState(() {
      _items = _repository.getCanonicalItems();
      _categories = _loadCategories();
    });
  }

  Future<List<ProductCategory>> _loadCategories() async {
    final result = await _repository.getCategories();
    return result is AppSuccess<List<ProductCategory>>
        ? result.value
        : const [];
  }

  int _nextCommercialCode(List<CanonicalItem> items) {
    var maximum = 0;
    for (final item in items) {
      final code = item.commercialCode ?? 0;
      if (code > maximum) maximum = code;
    }
    return maximum + 1;
  }

  Future<void> _edit(CanonicalItem? current) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final unitsResult = await _repository.getMeasurementUnits();
      final classificationsResult = await _repository
          .getCanonicalClassifications();
      final categoriesResult = await _repository.getCategories();
      final itemsResult = await _items;
      if (!mounted) return;
      if (unitsResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (classificationsResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (categoriesResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      final nextCommercialCode =
          current?.commercialCode ??
          (itemsResult is AppSuccess<List<CanonicalItem>>
              ? _nextCommercialCode(itemsResult.value)
              : null);
      setState(
        () => _editor = (
          item: current,
          units: (unitsResult as AppSuccess<List<MeasurementUnit>>).value,
          categories: (categoriesResult as AppSuccess<List<ProductCategory>>)
              .value
              .where((category) => category.isActive)
              .toList(),
          classifications:
              (classificationsResult
                      as AppSuccess<List<CanonicalClassification>>)
                  .value,
          initialCommercialCode: nextCommercialCode,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEditor(CanonicalItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _repository.saveCanonicalItem(item);
      if (!mounted) return;
      switch (result) {
        case AppSuccess():
          setState(() => _editor = null);
          _refresh();
          BackofficeActionFeedback.show(
            context,
            outcome: BackofficeActionOutcome.success,
            message: 'Artículo guardado correctamente.',
          );
        case AppFailureResult(:final error):
          _error(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: _editor == null ? 0 : 1,
    children: [
      FutureBuilder<AppResult<List<CanonicalItem>>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.data!.when(
            failure: (failure) => Center(child: Text(failure.message)),
            success: (items) =>
                FutureBuilder<({bool products, bool packaging})>(
                  future: _access,
                  builder: (context, permission) => !permission.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : FutureBuilder<List<ProductCategory>>(
                          future: _categories,
                          builder: (context, categories) => categories.hasData
                              ? _catalog(
                                  items,
                                  permission.data!,
                                  categories.data!,
                                )
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                ),
          );
        },
      ),
      if (_editor != null)
        CanonicalItemEditor(
          key: ValueKey(_editor!.item?.id ?? 'new'),
          item: _editor!.item,
          units: _editor!.units,
          classifications: _editor!.classifications,
          categories: _editor!.categories,
          saving: _busy,
          onBack: () => setState(() => _editor = null),
          onSave: _saveEditor,
        ),
    ],
  );

  Widget _catalog(
    List<CanonicalItem> items,
    ({bool products, bool packaging}) access,
    List<ProductCategory> categories,
  ) {
    final visible = items
        .where((item) => _filter == null || item.type == _filter)
        .toList();
    return Column(
      children: [
        Expanded(
          child: BackofficeCollectionView<CanonicalItem>(
            key: ValueKey(_filter?.databaseValue ?? 'all'),
            items: visible,
            rowKey: (item) => item.id ?? item.code,
            rowLabel: (item) => item.name,
            onCreate: () => _edit(null),
            createEnabled: !_busy && access.products,
            globalActions: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
            searchTrailing: _typeFilter(),
            selectionActions: [
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Editar',
                icon: Icons.edit_outlined,
                enabledWhen: (_) => !_busy && access.products,
                onPressed: _edit,
              ),
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Receta',
                icon: Icons.restaurant_menu_outlined,
                enabledWhen: (item) =>
                    !_busy &&
                    access.products &&
                    item.id != null &&
                    item.type != CanonicalItemType.service,
                onPressed: _recipe,
              ),
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Empaques y reglas',
                icon: Icons.inventory_2_outlined,
                enabledWhen: (item) =>
                    !_busy && access.packaging && item.canSell,
                onPressed: _packagingRules,
              ),
            ],
            searchLabel: 'Buscar por código comercial o nombre',
            searchTextFor: (item) =>
                '${item.commercialCode ?? ''} ${item.name}',
            emptyTitle: items.isEmpty
                ? 'Todavía no hay artículos'
                : 'Sin coincidencias',
            emptyMessage: items.isEmpty
                ? 'Utilizá Nuevo para registrar el primer artículo.'
                : 'Revisá la búsqueda o el filtro seleccionado.',
            compactBuilder: (context, item) => ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.commercialCode ?? '—'} · ${item.type.label}',
              ),
            ),
            columns: canonicalItemColumns(categories),
          ),
        ),
      ],
    );
  }

  Widget _typeFilter() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Tipo'),
      const SizedBox(width: 12),
      DropdownButton<CanonicalItemType?>(
        value: _filter,
        hint: const Text('Todos'),
        items: [
          const DropdownMenuItem<CanonicalItemType?>(child: Text('Todos')),
          ...CanonicalItemType.values.map(
            (type) => DropdownMenuItem<CanonicalItemType?>(
              value: type,
              child: Text(type.label),
            ),
          ),
        ],
        onChanged: (type) => setState(() => _filter = type),
      ),
    ],
  );
}
