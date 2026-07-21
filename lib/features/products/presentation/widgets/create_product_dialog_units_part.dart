part of 'create_product_dialog.dart';

extension _CreateProductDialogUnits on _CreateProductDialogState {
  Future<void> openUnitsDialog() async {
    final factor = double.tryParse(
      _purchaseFactorController.text.trim().replaceAll(',', '.'),
    );
    final initial = _purchaseUnitId == null || _inventoryUnitId == null
        ? null
        : ProductUnitsConfig(
            inventoryUnitId: _inventoryUnitId!,
            purchaseFactor: factor ?? 1,
            purchaseUnitId: _purchaseUnitId!,
            inventoryDisplayUnitId: _inventoryDisplayUnitId,
            recipeDefaultUnitId: _recipeDefaultUnitId,
          );
    final result = await showDialog<ProductUnitsConfig>(
      context: context,
      builder: (_) => ProductUnitsConfigDialog(
        initial: initial,
        units: widget.units,
      ),
    );
    if (result == null || !mounted) return;
    applyUnitsConfig(result);
  }

  String? unitName(String? unitId) {
    if (unitId == null) return null;
    for (final unit in widget.units) {
      if (unit.id == unitId) return '${unit.name} (${unit.code})';
    }
    return null;
  }

  String costFieldLabel(AppLocalizations l10n) {
    if (!_isRawMaterial || !_tracksInventory) return l10n.costInCentsField;
    final purchaseUnit = unitName(_purchaseUnitId);
    if (purchaseUnit == null) return 'Costo de compra';
    return 'Costo de compra por $purchaseUnit';
  }
}
