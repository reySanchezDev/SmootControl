import 'package:flutter/material.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/canonical_consumption_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:uuid/uuid.dart';

/// Edit canonical packaging consumption; never writes packaging_items.
class CanonicalPackagingRulesDialog extends StatefulWidget {
  /// Creates the editor for one sellable article and its candidate resources.
  const CanonicalPackagingRulesDialog({
    required this.source,
    required this.items,
    required this.salesTypes,
    required this.rules,
    super.key,
  });

  /// Article whose sales will consume packaging.
  final CanonicalItem source;

  /// Canonical catalog for selecting an item to consume.
  final List<CanonicalItem> items;

  /// Active sale modalities.
  final List<SalesType> salesTypes;

  /// Existing rule records (edit reuses their UUID).
  final List<CanonicalConsumptionRule> rules;

  @override
  State<CanonicalPackagingRulesDialog> createState() =>
      _CanonicalPackagingRulesDialogState();
}

class _CanonicalPackagingRulesDialogState
    extends State<CanonicalPackagingRulesDialog> {
  final _quantity = TextEditingController(text: '1');
  String? _salesType;
  String? _consumedItem;
  bool _perOrder = false;
  bool _busy = false;
  CanonicalConsumptionRule? _editing;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _edit(CanonicalConsumptionRule? rule) {
    setState(() {
      _editing = rule;
      _salesType = rule?.salesTypeId;
      _consumedItem = rule?.consumedItemId;
      _quantity.text = rule?.quantity.toString() ?? '1';
      _perOrder = rule?.scope == 'per_order';
    });
  }

  Future<void> _save() async {
    final value = double.tryParse(_quantity.text.replaceAll(',', '.'));
    if (_consumedItem == null ||
        value == null ||
        !value.isFinite ||
        value <= 0) {
      _message('Seleccioná un empaque y una cantidad mayor que cero.');
      return;
    }
    final target = widget.items.where(
      (item) => item.id == _consumedItem,
    ).first;
    if (target.type == CanonicalItemType.service ||
        target.id == widget.source.id) {
      _message('El consumo debe referirse a otro artículo físico o no físico.');
      return;
    }

    final saved = CanonicalConsumptionRule(
      id: _editing?.id ?? const Uuid().v4(),
      sourceItemId: widget.source.id,
      consumedItemId: target.id!,
      salesTypeId: _salesType,
      scope: _perOrder ? 'per_order' : 'per_sale_line',
      quantity: value,
      unitId: target.baseUnitId,
      priority: _editing?.priority ?? 100,
      isActive: _editing?.isActive ?? true,
    );
    setState(() => _busy = true);
    final result = await serviceLocator<SupabaseAdminRepository>()
        .saveCanonicalConsumptionRule(saved);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case AppSuccess():
        Navigator.of(context).pop(true);
      case AppFailureResult(:final error):
        _message(error.message);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.items.where(
      (item) =>
          item.id != widget.source.id &&
          item.id != null &&
          item.isActive &&
          item.type != CanonicalItemType.service,
    ).toList();
    final existing = widget.rules.where(
      (rule) => rule.sourceItemId == widget.source.id,
    ).toList();

    return AlertDialog(
      title: Text('Empaques y consumos: ${widget.source.name}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reglas existentes'),
              if (existing.isEmpty)
                const Text('Aún no hay reglas para este artículo.'),
              ...existing.map((rule) {
                final target = widget.items.where(
                  (item) => item.id == rule.consumedItemId,
                );
                final name = target.isEmpty
                    ? 'Artículo no disponible'
                    : target.first.name;
                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    '${rule.quantity} · '
                    '${rule.scope == 'per_order' ? 'Por pedido' : 'Por unidad'}',
                  ),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _edit(rule),
                    child: const Text('Editar'),
                  ),
                );
              }),
              const Divider(),
              Text(_editing == null ? 'Nueva regla' : 'Editar regla'),
              DropdownButtonFormField<String>(
                key: ValueKey(_consumedItem),
                initialValue: targets.any((i) => i.id == _consumedItem)
                    ? _consumedItem
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Artículo consumido / empaque',
                ),
                items: targets.map((item) {
                  return DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name),
                  );
                }).toList(),
                onChanged: _busy
                    ? null
                    : (id) => setState(() => _consumedItem = id),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_salesType),
                initialValue: _salesType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Modalidad de venta',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    child: Text('Todas las modalidades'),
                  ),
                  ...widget.salesTypes
                      .where((type) => type.isActive)
                      .map((type) => DropdownMenuItem(
                            value: type.id,
                            child: Text(type.name),
                          )),
                ],
                onChanged: _busy
                    ? null
                    : (id) => setState(() => _salesType = id),
              ),
              TextFormField(
                controller: _quantity,
                decoration: const InputDecoration(
                  labelText: 'Cantidad consumida',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              SwitchListTile(
                title: const Text('Una vez por pedido'),
                subtitle: const Text(
                  'Desactivado: cantidad por cada unidad vendida.',
                ),
                value: _perOrder,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _perOrder = value),
              ),
              const SizedBox(height: 8),
              const Text(
                'El consumo y su reversión se contabilizan al vender y anular.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Guardar regla'),
        ),
      ],
    );
  }
}
