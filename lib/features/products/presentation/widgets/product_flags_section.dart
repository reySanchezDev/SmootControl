import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Editable operational flags shown in the product form.
class ProductFlagsSection extends StatelessWidget {
  /// Creates the product flags section.
  const ProductFlagsSection({
    required this.isActive,
    required this.isAvailableInPos,
    required this.isRawMaterial,
    required this.onActiveChanged,
    required this.onAvailableInPosChanged,
    required this.onRawMaterialChanged,
    required this.onTracksInventoryChanged,
    required this.tracksInventory,
    super.key,
  });

  /// Whether the catalog product is active.
  final bool isActive;

  /// Whether the product is visible in POS.
  final bool isAvailableInPos;

  /// Whether the product is raw material instead of sellable.
  final bool isRawMaterial;

  /// Whether inventory is consumed/controlled for this product.
  final bool tracksInventory;

  /// Active flag callback.
  final ValueChanged<bool> onActiveChanged;

  /// POS availability callback.
  final ValueChanged<bool> onAvailableInPosChanged;

  /// Raw material flag callback.
  final ValueChanged<bool> onRawMaterialChanged;

  /// Inventory-control callback.
  final ValueChanged<bool> onTracksInventoryChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: AppText(l10n.productRawMaterialField),
          subtitle: AppText(
            isRawMaterial
                ? l10n.productRawMaterialHelp
                : l10n.productSellableHelp,
            variant: AppTextVariant.label,
            maxLines: 2,
          ),
          value: isRawMaterial,
          onChanged: (value) => onRawMaterialChanged(value ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: AppText(l10n.activeField),
          value: isActive,
          onChanged: (value) => onActiveChanged(value ?? true),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !isRawMaterial,
          title: AppText(l10n.availableInPosField),
          value: !isRawMaterial && isAvailableInPos,
          onChanged: (value) => onAvailableInPosChanged(value ?? true),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: AppText(l10n.tracksInventoryField),
          value: tracksInventory,
          onChanged: (value) => onTracksInventoryChanged(value ?? false),
        ),
      ],
    );
  }
}
