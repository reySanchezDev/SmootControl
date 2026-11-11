import 'package:flutter/material.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/recipes/domain/entities/canonical_recipe.dart';

/// Canonical recipe editor; changes create a new, immutable server version.
class CanonicalRecipeDialog extends StatefulWidget {
  /// Opens the recipe of [item] with only same-tenant components.
  const CanonicalRecipeDialog({
    required this.item,
    required this.items,
    required this.units,
    required this.existing,
    super.key,
  });

  /// Sellable article that owns the recipe.
  final CanonicalItem item;

  /// Candidate ingredients.
  final List<CanonicalItem> items;

  /// Restaurant measurement units.
  final List<MeasurementUnit> units;

  /// Previously active version.
  final CanonicalRecipe? existing;

  @override
  State<CanonicalRecipeDialog> createState() => _CanonicalRecipeDialogState();
}

class _CanonicalRecipeDialogState extends State<CanonicalRecipeDialog> {
  late List<CanonicalRecipeLine> _lines;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lines = [...?widget.existing?.lines];
  }

  Future<void> _newLine() async {
    final result = await showDialog<CanonicalRecipeLine>(
      context: context,
      builder: (_) => _RecipeComponentDialog(
        owner: widget.item,
        items: widget.items,
        units: widget.units,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _lines.add(result));
  }

  Future<void> _save() async {
    if (_busy || _lines.isEmpty || widget.item.id == null) return;
    setState(() => _busy = true);
    final result = await serviceLocator<SupabaseAdminRepository>()
        .saveCanonicalRecipe(
          itemId: widget.item.id!,
          lines: _lines,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case AppSuccess():
        Navigator.of(context).pop(true);
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _lines.fold<double>(0, (sum, line) {
      final matches = widget.items.where(
        (item) => item.id == line.componentItemId,
      );
      if (matches.isEmpty) return sum;
      final ingredient = matches.first;
      return sum + ingredient.cost * line.quantity *
          (1 + line.wastePercent / 100);
    });
    return AlertDialog(
      title: Text('Receta: ${widget.item.name}'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Versión activa: ${widget.existing?.version ?? 'Nueva'}'),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _lines.length,
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  final item = widget.items.where(
                    (candidate) => candidate.id == line.componentItemId,
                  );
                  final name = item.isEmpty
                      ? 'Componente desconocido'
                      : item.first.name;
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('Cantidad: ${line.quantity}'),
                    trailing: IconButton(
                      tooltip: 'Quitar componente',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _lines.removeAt(index)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _newLine,
                icon: const Icon(Icons.add),
                label: const Text('Agregar ingrediente'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Costo estimado sin conversión: '
              '${totalCost.toStringAsFixed(2)}',
            ),
            const Text(
              'El costo definitivo depende de unidades y '
              'conversiones del servidor.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy || _lines.isEmpty ? null : _save,
          child: const Text('Guardar nueva versión'),
        ),
      ],
    );
  }
}

class _RecipeComponentDialog extends StatefulWidget {
  const _RecipeComponentDialog({
    required this.owner,
    required this.items,
    required this.units,
  });
  final CanonicalItem owner;
  final List<CanonicalItem> items;
  final List<MeasurementUnit> units;

  @override
  State<_RecipeComponentDialog> createState() =>
      _RecipeComponentDialogState();
}

class _RecipeComponentDialogState extends State<_RecipeComponentDialog> {
  String? _itemId;
  final _quantity = TextEditingController(text: '1');

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _accept() {
    final quantity = double.tryParse(_quantity.text.replaceAll(',', '.'));
    if (_itemId == null || quantity == null || !quantity.isFinite ||
        quantity <= 0) return;
    final item = widget.items.firstWhere((entry) => entry.id == _itemId);
    Navigator.of(context).pop(CanonicalRecipeLine(
      componentItemId: item.id!,
      unitId: item.baseUnitId,
      quantity: quantity,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.items.where(
      (item) =>
          item.id != widget.owner.id &&
          item.id != null &&
          item.type != CanonicalItemType.service &&
          item.isActive,
    ).toList();
    return AlertDialog(
      title: const Text('Agregar ingrediente'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _itemId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Artículo componente',
              ),
              items: [
                for (final item in available)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.code} · ${item.name}'),
                  ),
              ],
              onChanged: (id) => setState(() => _itemId = id),
            ),
            TextFormField(
              controller: _quantity,
              decoration: const InputDecoration(
                labelText: 'Cantidad en unidad base',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_itemId != null)
              Text('Unidad: ${widget.units.where(
                (unit) => unit.id == widget.items.firstWhere(
                  (item) => item.id == _itemId,
                ).baseUnitId,
              ).map((unit) => unit.name).join(', ')}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _accept,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
