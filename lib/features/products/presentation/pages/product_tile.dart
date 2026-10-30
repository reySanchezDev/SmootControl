part of 'products_page.dart';

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.categoryPath,
    required this.onDeactivate,
    required this.onEdit,
    required this.product,
  });

  final String categoryPath;
  final VoidCallback onDeactivate;
  final VoidCallback onEdit;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = MoneyFormatter.format(product.priceInCents);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_cafe_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    product.name,
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
                AppTileActions(
                  compact: true,
                  actions: [
                    AppTileAction(
                      icon: Icons.edit_outlined,
                      label: l10n.editAction,
                      onPressed: onEdit,
                    ),
                    if (product.isActive)
                      AppTileAction(
                        color: Theme.of(context).colorScheme.error,
                        icon: Icons.toggle_off_outlined,
                        label: l10n.deactivateAction,
                        onPressed: onDeactivate,
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),
            AppText(
              _subtitle(l10n),
              variant: AppTextVariant.label,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: AppText(
                price,
                variant: AppTextVariant.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final status = [
      if (product.isActive) l10n.activeStatus else l10n.inactiveStatus,
      if (product.isAvailableInPos)
        l10n.availableInPosStatus
      else
        l10n.unavailableInPosStatus,
      if (product.requiresOptionSelection) l10n.productHasOptionsStatus,
      if (product.isRawMaterial)
        l10n.rawMaterialStatus
      else
        l10n.sellableProductStatus,
      if (product.usesRecipe) l10n.productUsesRecipeField,
      if (product.tracksInventory) l10n.tracksInventoryField,
    ].join(' - ');
    if (categoryPath.isEmpty) return status;

    return '$categoryPath - $status';
  }
}
