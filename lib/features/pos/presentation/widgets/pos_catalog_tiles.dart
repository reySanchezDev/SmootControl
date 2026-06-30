import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/product_options_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Vertical or horizontal root category rail for the POS.
class PosCategoryRail extends StatelessWidget {
  /// Creates a category rail.
  const PosCategoryRail({
    required this.activeCategoryId,
    required this.categories,
    this.compact = false,
    super.key,
  });

  /// Selected category identifier.
  final String? activeCategoryId;

  /// Root categories shown in the rail.
  final List<ProductCategory> categories;

  /// Whether the rail should be horizontal.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        height: 84,
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) => SizedBox(
            width: 148,
            child: _CategoryRailButton(
              active: categories[index].id == activeCategoryId,
              category: categories[index],
            ),
          ),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemCount: categories.length,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) => _CategoryRailButton(
        active: categories[index].id == activeCategoryId,
        category: categories[index],
      ),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemCount: categories.length,
    );
  }
}

/// Grid with subcategories and products for the active POS category.
class PosMenuGrid extends StatelessWidget {
  /// Creates a POS menu grid.
  const PosMenuGrid({
    required this.canAddProducts,
    required this.categories,
    required this.products,
    super.key,
  });

  /// Whether product tiles can add items to the active table.
  final bool canAddProducts;

  /// Subcategories shown in the current menu.
  final List<ProductCategory> categories;

  /// Products shown in the current menu.
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            childAspectRatio: compact ? 1.65 : 2.85,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            maxCrossAxisExtent: compact ? 190 : 300,
          ),
          itemBuilder: (context, index) {
            if (index < categories.length) {
              return _CategoryTile(category: categories[index]);
            }
            return _ProductTile(
              canAdd: canAddProducts,
              product: products[index - categories.length],
            );
          },
          itemCount: categories.length + products.length,
        );
      },
    );
  }
}

class _CategoryRailButton extends StatelessWidget {
  const _CategoryRailButton({
    required this.active,
    required this.category,
  });

  final bool active;
  final ProductCategory category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = active
        ? colorScheme.onPrimary
        : colorScheme.onInverseSurface;
    return Material(
      borderRadius: BorderRadius.circular(4),
      color: active ? colorScheme.primary : colorScheme.inverseSurface,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _select(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: textColor),
                  child: AppText(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    variant: AppTextVariant.label,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: textColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _select(BuildContext context) {
    context.read<PosBloc>().add(PosCategorySelected(category.id));
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final ProductCategory category;

  @override
  Widget build(BuildContext context) {
    return _MenuTile(
      icon: Icons.folder_outlined,
      label: category.name,
      onTap: () {
        context.read<PosBloc>().add(PosCategorySelected(category.id));
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.canAdd,
    required this.product,
  });

  final bool canAdd;
  final Product product;

  @override
  Widget build(BuildContext context) {
    return _MenuTile(
      label: product.name,
      onTap: canAdd ? () => _addProduct(context) : null,
      price: MoneyFormatter.format(product.priceInCents),
      product: true,
    );
  }

  Future<void> _addProduct(BuildContext context) async {
    final bloc = context.read<PosBloc>();
    final state = bloc.state;
    final optionGroups = state is PosReady
        ? state.optionGroupsFor(product)
        : product.optionGroups;

    if (optionGroups.isEmpty) {
      bloc.add(PosProductAdded(product));
      return;
    }

    final selected = await showDialog<List<SelectedProductOption>>(
      context: context,
      builder: (_) => ProductOptionsDialog(
        product: product,
        optionGroups: optionGroups,
      ),
    );
    if (selected == null || !context.mounted) return;
    bloc.add(PosProductAdded(product, selectedOptions: selected));
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.label,
    required this.onTap,
    this.icon,
    this.price,
    this.product = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final String? price;
  final bool product;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      borderRadius: BorderRadius.circular(4),
      color: _backgroundColor(colorScheme),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: AppText(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  variant: AppTextVariant.titleMedium,
                ),
              ),
              if (price != null) ...[
                const SizedBox(height: 4),
                AppText(price!, variant: AppTextVariant.label),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _backgroundColor(ColorScheme colorScheme) {
    if (onTap == null) {
      return colorScheme.surfaceContainerHighest.withValues(alpha: .55);
    }
    return product
        ? colorScheme.surfaceContainerHighest
        : colorScheme.primaryContainer;
  }
}
