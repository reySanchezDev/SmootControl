import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/recipes/data/services/supabase_product_recipes_service.dart';
import 'package:smoo_control/features/recipes/presentation/widgets/product_recipe_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Dedicated administrative page for product recipe configuration.
class RecipesPage extends StatefulWidget {
  /// Creates the recipes page.
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  late Future<_RecipesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
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
      await showAppMessageDialog(
        context: context,
        title: 'Recetas',
        message: AppLocalizations.of(context).recipeSavedMessage,
      );
      if (mounted) setState(() => _future = _loadData());
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
      if (candidate.inventoryUnitId == null) return false;
      return candidate.isRawMaterial || candidate.usesRecipe;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}

class _RecipesList extends StatelessWidget {
  const _RecipesList({
    required this.data,
    required this.onEdit,
  });

  final _RecipesData data;
  final Future<void> Function(_RecipesData data, Product product) onEdit;

  @override
  Widget build(BuildContext context) {
    return BackofficeCollectionView<Product>(
      items: data.recipeProducts,
      searchLabel: 'Buscar producto con receta',
      searchTextFor: (product) => product.name,
      emptyTitle: 'Sin productos con receta',
      emptyMessage: 'Activa «Usa receta» en un producto vendible.',
      columns: [
        BackofficeListColumn(
          label: 'Producto',
          width: 470,
          compare: (a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          cell: (_, product) => AppText(
            product.name,
          ),
        ),
        BackofficeListColumn(
          label: 'Tipo',
          width: 230,
          compare: (a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          cell: (_, _) => const Text('Producto vendible con receta'),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 210,
          alignment: Alignment.center,
          cell: (_, product) => TextButton.icon(
            onPressed: () => onEdit(data, product),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar receta'),
          ),
        ),
      ],
      compactBuilder: (_, product) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                product.name,
                variant: AppTextVariant.titleMedium,
              ),
              const AppText(
                'Producto vendible con receta',
                variant: AppTextVariant.label,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onEdit(data, product),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar receta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
