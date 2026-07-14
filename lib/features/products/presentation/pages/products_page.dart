import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_searchable_list_section.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
import 'package:smoo_control/core/design_system/confirm_deactivate_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_bloc.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_event.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_state.dart';
import 'package:smoo_control/features/products/presentation/widgets/create_product_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'product_tile.dart';

/// Product management page.
class ProductsPage extends StatelessWidget {
  /// Creates the products page.
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<ProductsBloc>()..add(const ProductsLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openCreateDialog(context),
              tooltip: l10n.createAction,
            ),
          ],
          title: l10n.moduleProducts,
          body: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              return switch (state) {
                ProductsInitial() ||
                ProductsLoading() => const AppLoadingPage(),
                ProductsFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleProducts,
                ),
                ProductsLoaded(:final products) when products.isEmpty =>
                  AppEmptyState(
                    icon: Icons.local_cafe_outlined,
                    message: l10n.emptyProductsMessage,
                    title: l10n.emptyProductsTitle,
                  ),
                ProductsLoaded(:final products) => FutureBuilder(
                  future: _loadCategories(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? <ProductCategory>[];

                    return AppSearchableListSection<Product>(
                      emptyMessage: l10n.emptySearchMessage,
                      emptyTitle: l10n.emptySearchTitle,
                      items: products,
                      searchLabel: l10n.searchField,
                      searchTextForItem: (product) => [
                        product.name,
                        _categoryPathFor(product.categoryId, categories),
                        if (product.isActive)
                          l10n.activeStatus
                        else
                          l10n.inactiveStatus,
                        if (product.isAvailableInPos)
                          l10n.availableInPosStatus
                        else
                          l10n.unavailableInPosStatus,
                        if (product.isRawMaterial)
                          l10n.rawMaterialStatus
                        else
                          l10n.sellableProductStatus,
                        if (product.tracksInventory) l10n.tracksInventoryField,
                      ].join(' '),
                      itemBuilder: (context, product) => _ProductTile(
                        categoryPath: _categoryPathFor(
                          product.categoryId,
                          categories,
                        ),
                        product: product,
                        onDeactivate: () => _deactivateProduct(
                          context,
                          product,
                        ),
                        onEdit: () => _openEditDialog(context, product),
                      ),
                    );
                  },
                ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final categories = await _loadCategories();
    final modifierGroups = await _loadModifierGroups();
    if (!context.mounted) {
      return;
    }

    final product = await showDialog<Product>(
      context: context,
      builder: (_) => CreateProductDialog(
        categories: categories,
        modifierGroups: modifierGroups,
      ),
    );

    if (product != null && context.mounted) {
      context.read<ProductsBloc>().add(ProductSaved(product));
    }
  }

  Future<void> _openEditDialog(BuildContext context, Product product) async {
    final categories = await _loadCategories();
    final modifierGroups = await _loadModifierGroups();
    if (!context.mounted) {
      return;
    }

    final updated = await showDialog<Product>(
      context: context,
      builder: (_) => CreateProductDialog(
        categories: categories,
        modifierGroups: modifierGroups,
        product: product,
      ),
    );

    if (updated != null && context.mounted) {
      context.read<ProductsBloc>().add(ProductSaved(updated));
    }
  }

  Future<void> _deactivateProduct(
    BuildContext context,
    Product product,
  ) async {
    final confirmed = await confirmDeactivateCatalogItem(
      context,
      name: product.name,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    context.read<ProductsBloc>().add(
      ProductSaved(
        Product(
          id: product.id,
          categoryId: product.categoryId,
          name: product.name,
          priceInCents: product.priceInCents,
          costInCents: product.costInCents,
          isActive: false,
          isAvailableInPos: false,
          isRawMaterial: product.isRawMaterial,
          optionGroups: product.optionGroups,
          modifierGroupIds: product.modifierGroupIds,
          tracksInventory: product.tracksInventory,
        ),
      ),
    );
  }

  Future<List<ModifierGroup>> _loadModifierGroups() async {
    final result = await serviceLocator<SupabaseAdminRepository>().getCatalog();

    return switch (result) {
      AppSuccess(:final value) => value.groups,
      AppFailureResult() => <ModifierGroup>[],
    };
  }

  Future<List<ProductCategory>> _loadCategories() async {
    final result = await serviceLocator<SupabaseAdminRepository>()
        .getCategories();

    return switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult() => <ProductCategory>[],
    };
  }

  String _categoryPathFor(
    String categoryId,
    List<ProductCategory> categories,
  ) {
    final category = _categoryById(categoryId, categories);
    if (category == null) return '';

    final names = <String>[category.name];
    var parentId = category.parentId;
    final visited = <String>{category.id};

    while (parentId != null && visited.add(parentId)) {
      final parent = _categoryById(parentId, categories);
      if (parent == null) break;
      names.insert(0, parent.name);
      parentId = parent.parentId;
    }

    return names.join(' / ');
  }

  ProductCategory? _categoryById(
    String id,
    List<ProductCategory> categories,
  ) {
    for (final category in categories) {
      if (category.id == id) return category;
    }

    return null;
  }
}
