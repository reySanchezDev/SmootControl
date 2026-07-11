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
                        if (product.tracksInventory) 'Controla inventario',
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
      if (product.tracksInventory) 'Controla inventario',
    ].join(' - ');
    if (categoryPath.isEmpty) return status;

    return '$categoryPath - $status';
  }
}
