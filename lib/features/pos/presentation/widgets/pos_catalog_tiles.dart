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
        final columns = _columnsFor(constraints.maxWidth, compact: compact);
        final aspectRatio = _aspectRatioFor(
          constraints.maxWidth,
          columns: columns,
          compact: compact,
        );
        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            childAspectRatio: aspectRatio,
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index < categories.length) {
              return _CategoryTile(
                category: categories[index],
                compact: compact,
              );
            }
            return _ProductTile(
              canAdd: canAddProducts,
              compact: compact,
              product: products[index - categories.length],
            );
          },
          itemCount: categories.length + products.length,
        );
      },
    );
  }

  int _columnsFor(double maxWidth, {required bool compact}) {
    const horizontalPadding = 20.0;
    final targetTileWidth = compact ? 190.0 : 300.0;
    final availableWidth = (maxWidth - horizontalPadding).clamp(1.0, maxWidth);
    final minColumns = compact ? 2 : 1;
    return (availableWidth / targetTileWidth).floor().clamp(minColumns, 8);
  }

  double _aspectRatioFor(
    double maxWidth, {
    required int columns,
    required bool compact,
  }) {
    const horizontalPadding = 20.0;
    const spacing = 8.0;
    final availableWidth =
        (maxWidth - horizontalPadding - (columns - 1) * spacing).clamp(
          1.0,
          maxWidth,
        );
    final tileWidth = availableWidth / columns;
    if (!compact) return 2.85;
    final tileHeight = (tileWidth / 2.1).clamp(76.0, 92.0);
    return tileWidth / tileHeight;
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
  const _CategoryTile({
    required this.category,
    required this.compact,
  });

  final ProductCategory category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _MenuTile(
      compact: compact,
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
    required this.compact,
    required this.product,
  });

  final bool canAdd;
  final bool compact;
  final Product product;

  @override
  Widget build(BuildContext context) {
    return _MenuTile(
      compact: compact,
      label: product.name,
      onTap: () => _addProduct(context),
      price: MoneyFormatter.format(product.priceInCents),
      product: true,
    );
  }

  Future<void> _addProduct(BuildContext context) async {
    final bloc = context.read<PosBloc>();
    if (!canAdd) {
      bloc.add(PosProductAdded(product));
      return;
    }

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
    required this.compact,
    required this.label,
    required this.onTap,
    this.icon,
    this.price,
    this.product = false,
  });

  final bool compact;
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final String? price;
  final bool product;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelVariant = compact
        ? AppTextVariant.label
        : AppTextVariant.titleMedium;
    final labelStyle = compact
        ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
        : null;
    final priceStyle = compact ? const TextStyle(fontSize: 12) : null;
    return Material(
      borderRadius: BorderRadius.circular(4),
      color: _backgroundColor(colorScheme),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 20 : 24),
                SizedBox(height: compact ? 4 : 8),
              ],
              Flexible(
                child: AppText(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                  variant: labelVariant,
                ),
              ),
              if (price != null) ...[
                SizedBox(height: compact ? 2 : 4),
                AppText(
                  price!,
                  style: priceStyle,
                  variant: AppTextVariant.label,
                ),
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
