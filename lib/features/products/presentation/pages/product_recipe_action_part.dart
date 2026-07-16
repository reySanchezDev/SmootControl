part of 'products_page.dart';

extension _ProductsRecipeAction on ProductsPage {
  Future<void> _openRecipeDialog(
    BuildContext context,
    Product product,
    List<Product> products,
  ) async {
    final units = await _loadUnits();
    final service = serviceLocator<SupabaseProductRecipesService>();
    final recipeResult = await service.loadActiveRecipe(product.id);
    if (!context.mounted) return;

    final recipe = switch (recipeResult) {
      AppSuccess(:final value) => value,
      AppFailureResult() => null,
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductRecipeDialog(
        components: products
            .where((candidate) => _canUseAsRecipeComponent(product, candidate))
            .toList(),
        product: product,
        recipe: recipe,
        service: service,
        units: units,
      ),
    );

    if ((saved ?? false) && context.mounted) {
      context.read<ProductsBloc>().add(const ProductsLoadRequested());
    }
  }

  bool _canUseAsRecipeComponent(Product target, Product candidate) {
    if (!candidate.isActive || candidate.id == target.id) return false;
    if (candidate.isRawMaterial) return true;
    return candidate.usesRecipe;
  }
}
