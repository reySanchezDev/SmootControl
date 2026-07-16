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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final price = MoneyFormatter.format(product.priceInCents);
        return ListTile(
          leading: const Icon(Icons.local_cafe_outlined),
          subtitle: AppText(
            compact ? '$price - ${_subtitle(l10n)}' : _subtitle(l10n),
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.label,
          ),
          title: AppText(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: AppTileActions(
            compact: compact,
            inlineLeading: AppText(price, variant: AppTextVariant.label),
            actions: [
              if (product.isActive)
                AppTileAction(
                  color: Theme.of(context).colorScheme.error,
                  icon: Icons.delete_outline,
                  label: l10n.deactivateAction,
                  onPressed: onDeactivate,
                ),
              AppTileAction(
                icon: Icons.edit_outlined,
                label: l10n.editAction,
                onPressed: onEdit,
              ),
            ],
          ),
        );
      },
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
