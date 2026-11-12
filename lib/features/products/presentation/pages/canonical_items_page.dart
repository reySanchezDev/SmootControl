import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/canonical_consumption_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/presentation/pages/canonical_packaging_rules_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_dialog.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_items_empty_state.dart';
import 'package:smoo_control/features/recipes/domain/entities/canonical_recipe.dart';
import 'package:smoo_control/features/recipes/presentation/pages/canonical_recipe_dialog.dart';
/// QA-only canonical article workspace, isolated from the legacy writers.
class CanonicalItemsPage extends StatefulWidget {
  /// Creates the canonical catalog.
  const CanonicalItemsPage({super.key});
  @override
  State<CanonicalItemsPage> createState() => _CanonicalItemsPageState();
}
class _CanonicalItemsPageState extends State<CanonicalItemsPage> {
  SupabaseAdminRepository get _repository =>
      serviceLocator<SupabaseAdminRepository>();
  late Future<AppResult<List<CanonicalItem>>> _items = _repository
      .getCanonicalItems();
  final _searchController = TextEditingController();
  CanonicalItem? _selected;
  String _query = '';
  CanonicalItemType? _filter;
  bool _busy = false;
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  void _refresh() {
    setState(() {
      _selected = null;
      _items = _repository.getCanonicalItems();
    });
  }
  Future<void> _edit(CanonicalItem? current) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait<Object>([
        _repository.getMeasurementUnits(),
        _repository.getCanonicalClassifications(),
      ]);
      if (!mounted) return;
      final unitsResult = results[0] as AppResult<List<MeasurementUnit>>;
      final classesResult =
          results[1] as AppResult<List<CanonicalClassification>>;
      if (unitsResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (classesResult case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      final units = (unitsResult as AppSuccess<List<MeasurementUnit>>).value;
      final classes =
          (classesResult as AppSuccess<List<CanonicalClassification>>).value;
      final result = await showDialog<CanonicalItem>(
        context: context,
        builder: (_) => CanonicalItemDialog(
          item: current,
          units: units,
          classifications: classes,
        ),
      );
      if (result == null || !mounted) return;
      final saved = await _repository.saveCanonicalItem(result);
      if (!mounted) return;
      switch (saved) {
        case AppSuccess():
          _refresh();
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
    title: 'Artículos',
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por código o nombre',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              DropdownButton<CanonicalItemType?>(
                value: _filter,
                hint: const Text('Todos los tipos'),
                items: [
                  const DropdownMenuItem<CanonicalItemType?>(
                    child: Text('Todos los tipos'),
                  ),
                  ...CanonicalItemType.values.map(
                    (type) => DropdownMenuItem<CanonicalItemType?>(
                      value: type,
                      child: Text(type.label),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _filter = value),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _selected == null
                    ? null
                    : () => _edit(_selected),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _selected == null ||
                        _selected!.type == CanonicalItemType.service
                    ? null
                    : () => _recipe(_selected!),
                icon: const Icon(Icons.restaurant_menu_outlined),
                label: const Text('Receta'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _selected?.canSell != true
                    ? null
                    : () => _packagingRules(_selected!),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Empaques y reglas'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<AppResult<List<CanonicalItem>>>(
            future: _items,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return snapshot.data!.when(
                failure: (failure) => Center(
                  child: Text(failure.message),
                ),
                success: (items) {
                  final q = _query.trim().toLowerCase();
                  final visible = items.where((item) {
                    if (_filter != null && item.type != _filter) return false;
                    if (q.isEmpty) return true;
                    return item.code.toLowerCase().contains(q) ||
                        item.name.toLowerCase().contains(q);
                  }).toList();
                  if (visible.isEmpty) {
                    return CanonicalItemsEmptyState(
                      noRecords: items.isEmpty,
                      busy: _busy,
                      onCreate: () => _edit(null),
                      onClearFilters: () => setState(() {
                        _searchController.clear();
                        _query = '';
                        _filter = null;
                      }),
                    );
                  }
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return ListTile(
                        selected: _selected?.id == item.id,
                        title: Text('${item.code} · ${item.name}'),
                        subtitle: Text(
                          '${item.type.label} · '
                          '${item.isActive ? 'Activo' : 'Inactivo'} · '
                          '${item.canSell ? 'Vendible' : 'No vendible'}',
                        ),
                        trailing: Text(
                          'Costo: ${item.cost.toStringAsFixed(2)}  '
                          'Precio: ${item.price.toStringAsFixed(2)}',
                        ),
                        onTap: () => setState(() => _selected = item),
                        onLongPress: () => _edit(item),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}