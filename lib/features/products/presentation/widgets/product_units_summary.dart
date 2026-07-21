import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_text.dart';

/// Compact summary shown inside the product edit dialog.
class ProductUnitsSummary extends StatelessWidget {
  /// Creates the unit summary.
  const ProductUnitsSummary({
    required this.displayUnitName,
    required this.factor,
    required this.inventoryUnitName,
    required this.onConfigure,
    required this.purchaseUnitName,
    required this.recipeUnitName,
    super.key,
  });

  /// Base inventory unit name.
  final String? inventoryUnitName;

  /// Purchase unit name.
  final String? purchaseUnitName;

  /// Recipe default unit name.
  final String? recipeUnitName;

  /// Main display/count unit name.
  final String? displayUnitName;

  /// Purchase to base conversion factor.
  final String factor;

  /// Opens the dedicated configuration dialog.
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final configured = inventoryUnitName != null && purchaseUnitName != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              configured ? 'Unidades del producto' : 'Unidades sin configurar',
              variant: AppTextVariant.label,
            ),
            const SizedBox(height: 6),
            AppText(
              configured ? _configuredText() : _emptyText,
              maxLines: 6,
              variant: AppTextVariant.label,
            ),
            const SizedBox(height: 8),
            AppButton(
              icon: Icons.straighten_outlined,
              label: 'Configurar unidades',
              onPressed: onConfigure,
              primary: false,
            ),
          ],
        ),
      ),
    );
  }

  String _configuredText() {
    return 'Base: $inventoryUnitName\n'
        'Compra: $purchaseUnitName\n'
        'Conversion: 1 $purchaseUnitName = $factor $inventoryUnitName\n'
        'Receta: ${recipeUnitName ?? inventoryUnitName}\n'
        'Mostrar/conteo: ${displayUnitName ?? purchaseUnitName}';
  }

  String get _emptyText {
    return 'Configura compra, base, receta y unidad de conteo.';
  }
}
