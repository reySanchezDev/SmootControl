part of 'pos_catalog_tiles.dart';

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

class _DraggableProductTile extends StatelessWidget {
  const _DraggableProductTile({
    required this.canAdd,
    required this.categoryId,
    required this.compact,
    required this.product,
    required this.products,
  });

  final bool canAdd;
  final String categoryId;
  final bool compact;
  final Product product;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Product>(
      onAcceptWithDetails: (details) => _moveProduct(context, details.data),
      onWillAcceptWithDetails: (details) => details.data.id != product.id,
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return LongPressDraggable<Product>(
          data: product,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragFeedback(product: product),
          maxSimultaneousDrags: 1,
          childWhenDragging: Opacity(
            opacity: .42,
            child: _ProductTile(
              canAdd: canAdd,
              compact: compact,
              product: product,
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: highlighted
                ? BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: _ProductTile(
              canAdd: canAdd,
              compact: compact,
              product: product,
            ),
          ),
        );
      },
    );
  }

  void _moveProduct(BuildContext context, Product draggedProduct) {
    final reordered = swapPosProductsForDrop(
      draggedProduct: draggedProduct,
      products: products,
      targetProduct: product,
    );
    if (identical(reordered, products)) return;
    context.read<PosBloc>().add(
      PosProductsReordered(
        categoryId: categoryId,
        productIds: [for (final item in reordered) item.id],
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 8,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: .24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                variant: AppTextVariant.label,
              ),
              const SizedBox(height: 2),
              AppText(
                MoneyFormatter.format(product.priceInCents),
                variant: AppTextVariant.label,
              ),
            ],
          ),
        ),
      ),
    );
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
