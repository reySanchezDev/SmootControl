import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/recipes/domain/entities/product_recipe.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Mutable draft for one recipe row.
final class ProductRecipeRowDraft {
  /// Creates an empty draft.
  ProductRecipeRowDraft()
    : quantityController = TextEditingController(),
      wasteController = TextEditingController(text: '0');

  /// Creates a draft from a saved line.
  ProductRecipeRowDraft.fromLine(ProductRecipeLine line)
    : componentProductId = line.componentProductId,
      unitId = line.unitId,
      quantityController = TextEditingController(
        text: _formatNumber(line.quantity),
      ),
      wasteController = TextEditingController(
        text: _formatNumber(line.wastePercent),
      );

  /// Selected component product id.
  String? componentProductId;

  /// Selected unit id.
  String? unitId;

  /// Quantity controller.
  final TextEditingController quantityController;

  /// Waste percent controller.
  final TextEditingController wasteController;

  /// Converts this draft to a recipe line.
  ProductRecipeLine? toLine(int displayOrder) {
    final componentId = componentProductId;
    final selectedUnitId = unitId;
    final quantity = double.tryParse(quantityController.text.trim());
    final waste = double.tryParse(
      wasteController.text.trim().isEmpty ? '0' : wasteController.text.trim(),
    );
    if (componentId == null ||
        selectedUnitId == null ||
        quantity == null ||
        quantity <= 0 ||
        waste == null ||
        waste < 0) {
      return null;
    }
    return ProductRecipeLine(
      componentProductId: componentId,
      quantity: quantity,
      unitId: selectedUnitId,
      wastePercent: waste,
      displayOrder: displayOrder,
    );
  }

  /// Disposes controllers.
  void dispose() {
    quantityController.dispose();
    wasteController.dispose();
  }
}

/// Visual editor for one recipe row.
class ProductRecipeRowCard extends StatefulWidget {
  /// Creates a recipe row card.
  const ProductRecipeRowCard({
    required this.components,
    required this.row,
    required this.units,
    this.onRemove,
    super.key,
  });

  /// Available components.
  final List<Product> components;

  /// Available units.
  final List<MeasurementUnit> units;

  /// Mutable row draft.
  final ProductRecipeRowDraft row;

  /// Optional remove callback.
  final VoidCallback? onRemove;

  @override
  State<ProductRecipeRowCard> createState() => _ProductRecipeRowCardState();
}

class _ProductRecipeRowCardState extends State<ProductRecipeRowCard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Row(
              children: [
                Expanded(
                  child: AppText(
                    l10n.productRecipeComponentField,
                    variant: AppTextVariant.label,
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onRemove,
                    tooltip: l10n.deleteAction,
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _validComponentId,
              items: [
                for (final product in widget.components)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(product.name),
                  ),
              ],
              onChanged: (value) {
                setState(() => widget.row.componentProductId = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.row.quantityController,
                    decoration: InputDecoration(
                      labelText: l10n.productRecipeQuantityField,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _validUnitId,
                    decoration: InputDecoration(
                      labelText: l10n.productRecipeUnitField,
                    ),
                    items: [
                      for (final unit in widget.units)
                        DropdownMenuItem(
                          value: unit.id,
                          child: Text('${unit.name} (${unit.code})'),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => widget.row.unitId = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.row.wasteController,
              decoration: InputDecoration(
                labelText: l10n.productRecipeWasteField,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _validComponentId {
    final value = widget.row.componentProductId;
    return widget.components.any((product) => product.id == value)
        ? value
        : null;
  }

  String? get _validUnitId {
    final value = widget.row.unitId;
    return widget.units.any((unit) => unit.id == value) ? value : null;
  }
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}
