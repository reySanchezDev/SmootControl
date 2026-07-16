import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Unit fields used by raw materials.
class ProductUnitsSection extends StatelessWidget {
  /// Creates the unit section.
  const ProductUnitsSection({
    required this.inventoryUnitId,
    required this.onInventoryUnitChanged,
    required this.onPurchaseUnitChanged,
    required this.purchaseFactorController,
    required this.purchaseUnitId,
    required this.units,
    super.key,
  });

  /// Available units.
  final List<MeasurementUnit> units;

  /// Selected purchase unit id.
  final String? purchaseUnitId;

  /// Selected inventory base unit id.
  final String? inventoryUnitId;

  /// Factor controller from purchase unit to inventory unit.
  final TextEditingController purchaseFactorController;

  /// Purchase unit callback.
  final ValueChanged<String?> onPurchaseUnitChanged;

  /// Inventory unit callback.
  final ValueChanged<String?> onInventoryUnitChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeUnits = units.where((unit) => unit.isActive).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        AppText(l10n.productUnitsTitle, variant: AppTextVariant.label),
        const SizedBox(height: 8),
        _UnitDropdown(
          label: l10n.productPurchaseUnitField,
          units: activeUnits,
          value: purchaseUnitId,
          onChanged: onPurchaseUnitChanged,
        ),
        const SizedBox(height: 12),
        _UnitDropdown(
          label: l10n.productInventoryUnitField,
          units: activeUnits,
          value: inventoryUnitId,
          onChanged: onInventoryUnitChanged,
        ),
        const SizedBox(height: 12),
        AppInput(
          label: l10n.productPurchaseFactorField,
          controller: purchaseFactorController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 4),
        AppText(
          l10n.productPurchaseFactorHelp,
          variant: AppTextVariant.label,
          maxLines: 2,
        ),
      ],
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
      initialValue: units.any((unit) => unit.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: units
          .map(
            (unit) => DropdownMenuItem<String>(
              value: unit.id,
              child: Text('${unit.name} (${unit.code})'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
