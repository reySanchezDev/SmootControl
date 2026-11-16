import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/canonical_consumption_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/presentation/pages/canonical_packaging_rules_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_dialog.dart';
import 'package:smoo_control/features/recipes/domain/entities/canonical_recipe.dart';
import 'package:smoo_control/features/recipes/presentation/pages/canonical_recipe_dialog.dart';

/// QA-only canonical article workspace, isolated from the legacy writers.
class CanonicalItemsPage extends StatefulWidget {
  const CanonicalItemsPage({super.key});
  @override
  State<CanonicalItemsPage> createState() => _CanonicalItemsPageState();
}

class _CanonicalItemsPageState extends State<CanonicalItemsPage> {
  SupabaseAdminRepository get _repository =>
      serviceLocator<SupabaseAdminRepository>();
  late Future<AppResult<List<CanonicalItem>>> _items = _repository
      .getCanonicalItems();
  ({CanonicalItem? item, List<MeasurementUnit> units,
    List<CanonicalClassification> classifications})? _editor;
  CanonicalItemType? _filter;
  bool _busy = false;
  void _refresh() {
    setState(() {
      _items = _repository.getCanonicalItems();
    });
  }

  Future<void> _edit(CanonicalItem? current) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final unitsResult = await _repository.getMeasurementUnits();
      final classificationsResult = await _repository.getCanonicalClassifications();
      if (!mounted) return;
      if (unitsResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (classificationsResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      setState(() => _editor = (
        item: current,
        units: (unitsResult as AppSuccess<List<MeasurementUnit>>).value,
        classifications: (classificationsResult
            as AppSuccess<List<CanonicalClassification>>).value,
      ));
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
          await showAppMessageDialog(
            context: context,
            title: 'Artículo guardado',
            message: 'Los cambios se guardaron correctamente.',
          );
        case AppFailureResult(:final error):
          _error(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recipe(CanonicalItem selected) async {
    if (_busy ||
        selected.id == null ||
        selected.type == CanonicalItemType.service) {
      return;
    }
    setState(() => _busy = true);
    try {
      final catalog = await _repository.getCanonicalItems();
      final units = await _repository.getMeasurementUnits();
      final existing = await _repository.loadCanonicalRecipe(selected.id!);
      if (!mounted) return;
      if (catalog case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (units case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (existing case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => CanonicalRecipeDialog(
          item: selected,
          items: (catalog as AppSuccess<List<CanonicalItem>>).value,
          units: (units as AppSuccess<List<MeasurementUnit>>).value,
          existing: (existing as AppSuccess<CanonicalRecipe?>).value,
        ),
      );
      if (result ?? false) {
        if (mounted) _refresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _packagingRules(CanonicalItem selected) async {
    if (_busy || !selected.canSell) return;
    setState(() => _busy = true);
    try {
      final catalog = await _repository.getCanonicalItems();
      final saleTypes = await _repository.getSalesTypes();
      final rules = await _repository.getCanonicalConsumptionRules();
      if (!mounted) return;
      if (catalog case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (saleTypes case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (rules case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => CanonicalPackagingRulesDialog(
          source: selected,
          items: (catalog as AppSuccess<List<CanonicalItem>>).value,
          salesTypes: (saleTypes as AppSuccess<List<SalesType>>).value,
          rules: (rules as AppSuccess<List<CanonicalConsumptionRule>>).value,
        ),
      );
      if (result ?? false) {
        if (mounted) _refresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    title: 'Productos',
    body: IndexedStack(
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
              success: _catalog,
            );
          },
        ),
        if (_editor != null)
          CanonicalItemEditor(
            key: ValueKey(_editor!.item?.id ?? 'new'),
            item: _editor!.item,
            units: _editor!.units,
            classifications: _editor!.classifications,
            saving: _busy,
            onBack: () => setState(() => _editor = null),
            onSave: _saveEditor,
          ),
      ],
    ),
  );

  Widget _catalog(List<CanonicalItem> items) {
    final visible = items.where((item) => _filter == null || item.type == _filter)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Text('Tipo'),
              const SizedBox(width: 12),
              DropdownButton<CanonicalItemType?>(
                value: _filter,
                hint: const Text('Todos'),
                items: [
                  const DropdownMenuItem<CanonicalItemType?>(
                    child: Text('Todos'),
                  ),
                  ...CanonicalItemType.values.map(
                    (type) => DropdownMenuItem<CanonicalItemType?>(
                      value: type, child: Text(type.label),
                    ),
                  ),
                ],
                onChanged: (type) => setState(() => _filter = type),
              ),
            ],
          ),
        ),
        Expanded(
          child: BackofficeCollectionView<CanonicalItem>(
            items: visible,
            rowKey: (item) => item.id ?? item.code,
            rowLabel: (item) => item.name,
            onCreate: () => _edit(null),
            createEnabled: !_busy,
            globalActions: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
            selectionActions: [
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Editar',
                icon: Icons.edit_outlined,
                enabledWhen: (_) => !_busy,
                onPressed: (item) => _edit(item),
              ),
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Receta',
                icon: Icons.restaurant_menu_outlined,
                enabledWhen: (item) =>
                    !_busy && item.id != null &&
                    item.type != CanonicalItemType.service,
                onPressed: _recipe,
              ),
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Empaques y reglas',
                icon: Icons.inventory_2_outlined,
                enabledWhen: (item) => !_busy && item.canSell,
                onPressed: _packagingRules,
              ),
            ],
            searchLabel: 'Buscar por código o nombre',
            searchTextFor: (item) => '${item.code} ${item.name}',
            emptyTitle: items.isEmpty ? 'Todavía no hay artículos' : 'Sin coincidencias',
            emptyMessage: items.isEmpty
                ? 'Utilizá Nuevo para registrar el primer artículo.'
                : 'Revisá la búsqueda o el filtro seleccionado.',
            compactBuilder: (context, item) => ListTile(
              title: Text(item.name),
              subtitle: Text('${item.code} · ${item.type.label}'),
            ),
            columns: [
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
            ],
          ),
        ),
      ],
    );
  }
}
