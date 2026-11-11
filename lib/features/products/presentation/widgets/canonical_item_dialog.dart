import 'package:flutter/material.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';

/// Creates and edits all three canonical types through one article form.
class CanonicalItemDialog extends StatefulWidget {
  /// Creates the form with data already authorized for the current tenant.
  const CanonicalItemDialog({
    required this.units,
    required this.classifications,
    this.item,
    super.key,
  });

  /// Existing article or null to create.
  final CanonicalItem? item;

  /// Measurement units available to the restaurant.
  final List<MeasurementUnit> units;

  /// Independent functional classifications.
  final List<CanonicalClassification> classifications;

  @override
  State<CanonicalItemDialog> createState() => _CanonicalItemDialogState();
}

class _CanonicalItemDialogState extends State<CanonicalItemDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _price = TextEditingController(text: '0');
  late CanonicalItemType _type;
  late bool _canSell;
  late bool _canPurchase;
  late bool _visibleInPos;
  late bool _usesRecipe;
  late bool _sendToKitchen;
  late bool _isActive;
  late Set<String> _classifications;
  String? _baseUnit;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _code.text = item?.code ?? '';
    _name.text = item?.name ?? '';
    _cost.text = item?.cost.toString() ?? '0';
    _price.text = item?.price.toString() ?? '0';
    _type = item?.type ?? CanonicalItemType.inventory;
    _canSell = item?.canSell ?? false;
    _canPurchase = item?.canPurchase ?? true;
    _visibleInPos = item?.visibleInPos ?? false;
    _usesRecipe = item?.usesRecipe ?? false;
    _sendToKitchen = item?.sendToKitchen ?? false;
    _isActive = item?.isActive ?? true;
    _classifications = {...?item?.classificationIds};
    _baseUnit = item?.baseUnitId;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _cost.dispose();
    _price.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Obligatorio';
    return null;
  }

  String? _nonnegative(String? value) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < 0) {
      return 'Ingresá un importe válido';
    }
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_baseUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una unidad base.')),
      );
      return;
    }
    if (_visibleInPos && !_canSell) return;
    if (_usesRecipe && _type == CanonicalItemType.service) return;
    Navigator.of(context).pop(
      CanonicalItem(
        id: widget.item?.id,
        code: _code.text.trim(),
        name: _name.text.trim(),
        type: _type,
        baseUnitId: _baseUnit!,
        cost: double.parse(_cost.text.replaceAll(',', '.')),
        price: double.parse(_price.text.replaceAll(',', '.')),
        canSell: _canSell,
        canPurchase: _canPurchase,
        visibleInPos: _visibleInPos,
        usesRecipe: _usesRecipe,
        sendToKitchen: _sendToKitchen,
        isActive: _isActive,
        classificationIds: _classifications.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.units.where((unit) => unit.isActive).toList();
    if (_baseUnit != null &&
        !units.any((unit) => unit.id == _baseUnit)) {
      final prior = widget.units.where((unit) => unit.id == _baseUnit);
      units.addAll(prior);
    }
    return AlertDialog(
      title: Text(widget.item == null ? 'Nuevo artículo' : 'Editar artículo'),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Código *',
                  ),
                  maxLength: 64,
                  validator: _required,
                ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                  ),
                  maxLength: 250,
                  validator: _required,
                ),
                DropdownButtonFormField<CanonicalItemType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo técnico *',
                  ),
                  items: CanonicalItemType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (type) {
                    if (type == null) return;
                    setState(() {
                      _type = type;
                      if (type == CanonicalItemType.service) {
                        _usesRecipe = false;
                      }
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: units.any((unit) => unit.id == _baseUnit)
                      ? _baseUnit
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Unidad base *',
                  ),
                  items: units.map((unit) {
                    return DropdownMenuItem(
                      value: unit.id,
                      child: Text('${unit.name} (${unit.code})'),
                    );
                  }).toList(),
                  onChanged: (id) => setState(() => _baseUnit = id),
                  validator: _required,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        decoration: const InputDecoration(
                          labelText: 'Costo por unidad base',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _nonnegative,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        decoration: const InputDecoration(
                          labelText: 'Precio por unidad base',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _nonnegative,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Clasificaciones funcionales'),
                if (widget.classifications.isEmpty)
                  const Text('No hay clasificaciones configuradas.'),
                ...widget.classifications.map((classification) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(classification.name),
                    value: _classifications.contains(classification.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _classifications.add(classification.id);
                        } else {
                          _classifications.remove(classification.id);
                        }
                      });
                    },
                  );
                }),
                const Divider(),
                SwitchListTile(
                  title: const Text('Se puede vender'),
                  value: _canSell,
                  onChanged: (value) {
                    setState(() {
                      _canSell = value;
                      if (!value) _visibleInPos = false;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Se puede comprar'),
                  value: _canPurchase,
                  onChanged: (value) =>
                      setState(() => _canPurchase = value),
                ),
                SwitchListTile(
                  title: const Text('Visible en POS'),
                  value: _visibleInPos,
                  onChanged: _canSell
                      ? (value) => setState(() => _visibleInPos = value)
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Utiliza receta'),
                  value: _usesRecipe,
                  onChanged: _type == CanonicalItemType.service
                      ? null
                      : (value) => setState(() => _usesRecipe = value),
                ),
                SwitchListTile(
                  title: const Text('Enviar a cocina'),
                  value: _sendToKitchen,
                  onChanged: (value) =>
                      setState(() => _sendToKitchen = value),
                ),
                SwitchListTile(
                  title: const Text('Activo'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
