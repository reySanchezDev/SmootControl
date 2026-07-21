import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';

/// Result returned by the product unit configuration dialog.
final class ProductUnitsConfig {
  /// Creates a unit configuration.
  const ProductUnitsConfig({
    required this.inventoryUnitId,
    required this.purchaseFactor,
    required this.purchaseUnitId,
    this.inventoryDisplayUnitId,
    this.recipeDefaultUnitId,
  });

  /// Unit used to buy the product.
  final String purchaseUnitId;

  /// Base inventory unit.
  final String inventoryUnitId;

  /// Suggested recipe unit.
  final String? recipeDefaultUnitId;

  /// Main display/count unit.
  final String? inventoryDisplayUnitId;

  /// Base inventory units represented by one purchase unit.
  final double purchaseFactor;
}

/// Dedicated unit configuration dialog for one product.
class ProductUnitsConfigDialog extends StatefulWidget {
  /// Creates the dialog.
  const ProductUnitsConfigDialog({
    required this.units,
    this.initial,
    super.key,
  });

  /// Available units.
  final List<MeasurementUnit> units;

  /// Current product configuration.
  final ProductUnitsConfig? initial;

  @override
  State<ProductUnitsConfigDialog> createState() =>
      _ProductUnitsConfigDialogState();
}

class _ProductUnitsConfigDialogState extends State<ProductUnitsConfigDialog> {
  late String? _purchaseUnitId = widget.initial?.purchaseUnitId;
  late String? _inventoryUnitId = widget.initial?.inventoryUnitId;
  late String? _recipeDefaultUnitId = widget.initial?.recipeDefaultUnitId;
  late String? _inventoryDisplayUnitId =
      widget.initial?.inventoryDisplayUnitId;
  late final _factorController = TextEditingController(
    text: (widget.initial?.purchaseFactor ?? 1).toString(),
  );
  String? _error;

  @override
  void dispose() {
    _factorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.units.where((unit) => unit.isActive).toList();
    return AlertDialog(
      title: const AppText(
        'Configurar unidades',
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UnitDropdown(
                label: 'Unidad base de inventario',
                units: units,
                value: _inventoryUnitId,
                onChanged: (value) => setState(() {
                  _inventoryUnitId = value;
                  _recipeDefaultUnitId ??= value;
                  _inventoryDisplayUnitId ??= value;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              _UnitDropdown(
                label: 'Unidad de compra',
                units: units,
                value: _purchaseUnitId,
                onChanged: (value) => setState(() {
                  _purchaseUnitId = value;
                  _inventoryDisplayUnitId ??= value;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              AppInput(
                label: 'Factor compra a base',
                controller: _factorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 4),
              const AppText(
                'Ejemplo: 1 tarro con 3200 gramos usa factor 3200.',
                maxLines: 2,
                variant: AppTextVariant.label,
              ),
              const SizedBox(height: 12),
              _UnitDropdown(
                label: 'Unidad usada en recetas',
                units: units,
                value: _recipeDefaultUnitId,
                onChanged: (value) => setState(() {
                  _recipeDefaultUnitId = value;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              _UnitDropdown(
                label: 'Unidad principal para inventario',
                units: units,
                value: _inventoryDisplayUnitId,
                onChanged: (value) => setState(() {
                  _inventoryDisplayUnitId = value;
                  _error = null;
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(_error!, maxLines: 2),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(label: 'Guardar', onPressed: _submit),
      ],
    );
  }

  void _submit() {
    final factor = double.tryParse(
      _factorController.text.trim().replaceAll(',', '.'),
    );
    if (_purchaseUnitId == null || _inventoryUnitId == null) {
      setState(() => _error = 'Selecciona unidad base y unidad de compra.');
      return;
    }
    if (factor == null || factor <= 0) {
      setState(() => _error = 'Indica un factor mayor que cero.');
      return;
    }
    Navigator.of(context).pop(
      ProductUnitsConfig(
        inventoryUnitId: _inventoryUnitId!,
        purchaseFactor: factor,
        purchaseUnitId: _purchaseUnitId!,
        inventoryDisplayUnitId: _inventoryDisplayUnitId ?? _purchaseUnitId,
        recipeDefaultUnitId: _recipeDefaultUnitId ?? _inventoryUnitId,
      ),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({
    required this.label,
    required this.onChanged,
    required this.units,
    required this.value,
  });

  final String label;
  final List<MeasurementUnit> units;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      initialValue: units.any((unit) => unit.id == value) ? value : null,
      items: [
        for (final unit in units)
          DropdownMenuItem(
            value: unit.id,
            child: Text('${unit.name} (${unit.code})'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
