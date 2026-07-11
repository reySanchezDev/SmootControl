part of 'pos_catalog_tiles.dart';

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
