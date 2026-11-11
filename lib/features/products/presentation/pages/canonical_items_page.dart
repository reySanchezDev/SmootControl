import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_dialog.dart';

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
  CanonicalItem? _selected;
  String _query = '';
  CanonicalItemType? _filter;
  bool _busy = false;

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
                label: const Text('Nuevo artículo'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _selected == null
                    ? null
                    : () => _edit(_selected),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar seleccionado'),
              ),
              IconButton(
                onPressed: _busy ? null : _refresh,
                tooltip: 'Actualizar artículos',
                icon: const Icon(Icons.refresh),
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
                    return const Center(
                      child: Text('No hay artículos para este filtro.'),
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
