import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/recipes/data/services/supabase_product_recipes_service.dart';
import 'package:smoo_control/features/recipes/presentation/widgets/product_recipe_dialog.dart';

/// Dedicated administrative page for product recipe configuration.
class RecipesPage extends StatefulWidget {
  /// Creates the recipes page.
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final _searchController = TextEditingController();
  late Future<_RecipesData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Recetas',
      body: FutureBuilder<_RecipesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingPage();
          }
          if (snapshot.hasError) {
            return AppEmptyState(
              icon: Icons.error_outline,
              message: snapshot.error.toString(),
              title: 'No se pudieron cargar recetas',
            );
          }
          return _RecipesList(
            data: snapshot.data ?? const _RecipesData.empty(),
            onEdit: _openRecipeDialog,
            onQueryChanged: (value) => setState(() => _query = value),
            query: _query,
            searchController: _searchController,
          );
        },
      ),
    );
  }

  Future<_RecipesData> _loadData() async {
    final repository = serviceLocator<SupabaseAdminRepository>();
    final productsResult = await repository.getProducts();
    final unitsResult = await repository.getMeasurementUnits();
    return _RecipesData(
      products: switch (productsResult) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      units: switch (unitsResult) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
    );
  }

  Future<void> _openRecipeDialog(_RecipesData data, Product product) async {
    final service = serviceLocator<SupabaseProductRecipesService>();
    final recipeResult = await service.loadActiveRecipe(product.id);
    if (!mounted) return;

    final recipe = switch (recipeResult) {
      AppSuccess(:final value) => value,
      AppFailureResult() => null,
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductRecipeDialog(
        components: data.componentsFor(product),
        product: product,
        recipe: recipe,
        service: service,
        units: data.units,
      ),
    );
    if ((saved ?? false) && mounted) {
      setState(() => _future = _loadData());
    }
  }
}

final class _RecipesData {
  const _RecipesData({required this.products, required this.units});

  const _RecipesData.empty() : products = const [], units = const [];

  final List<Product> products;
  final List<MeasurementUnit> units;

  List<Product> get recipeProducts {
    return products.where((product) {
      return product.isActive && !product.isRawMaterial && product.usesRecipe;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Product> componentsFor(Product target) {
    return products.where((candidate) {
      if (!candidate.isActive || candidate.id == target.id) return false;
      if (candidate.isRawMaterial) return true;
      return candidate.usesRecipe;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}

class _RecipesList extends StatelessWidget {
  const _RecipesList({
    required this.data,
    required this.onEdit,
    required this.onQueryChanged,
    required this.query,
    required this.searchController,
  });

  final _RecipesData data;
  final Future<void> Function(_RecipesData data, Product product) onEdit;
  final ValueChanged<String> onQueryChanged;
  final String query;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppSearchField(
          controller: searchController,
          label: 'Buscar producto con receta',
          onClear: () {
            searchController.clear();
            onQueryChanged('');
          },
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        if (data.recipeProducts.isEmpty)
          const AppEmptyState(
            icon: Icons.restaurant_menu_outlined,
            message: 'Marca productos vendibles con "Usa receta" en Productos.',
            title: 'Sin productos tipo receta',
          )
        else if (products.isEmpty)
          const AppEmptyState(
            icon: Icons.search_off_outlined,
            message: 'No hay productos que coincidan con la busqueda.',
            title: 'Sin resultados',
          )
        else
          for (final product in products)
            Card(
              child: ListTile(
                leading: const Icon(Icons.restaurant_menu_outlined),
                title: AppText(product.name, maxLines: 2),
                subtitle: const AppText(
                  'Producto vendible con receta',
                  variant: AppTextVariant.label,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(data, product),
                  tooltip: 'Editar receta',
                ),
                onTap: () => onEdit(data, product),
              ),
            ),
      ],
    );
  }

  List<Product> get _filteredProducts {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return data.recipeProducts;
    return data.recipeProducts.where((product) {
      return product.name.toLowerCase().contains(normalized);
    }).toList();
  }
}
