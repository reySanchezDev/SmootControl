part of 'inventory_page.dart';

class _BatchPurchaseHeader extends StatelessWidget {
  const _BatchPurchaseHeader({required this.productLabel});

  final String productLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: AppText(productLabel, variant: AppTextVariant.label),
          ),
          const SizedBox(
            width: 96,
            child: AppText('CANTIDAD', variant: AppTextVariant.label),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 120,
            child: AppText('COSTO', variant: AppTextVariant.label),
          ),
        ],
      ),
    );
  }
}

double _batchDialogHeight(Size mediaSize, bool isCompact) {
  if (!isCompact) return 520;
  final availableHeight = mediaSize.height * 0.72;
  return availableHeight.clamp(420.0, 560.0);
}

class _ProductBatchPurchaseTile extends StatelessWidget {
  const _ProductBatchPurchaseTile({
    required this.row,
    required this.compact,
  });

  final _BatchProductRow row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _BatchPurchaseTile(
      title: row.item.productName,
      subtitle: row.item.categoryPath,
      quantityController: row.quantityController,
      costController: row.costController,
      compact: compact,
    );
  }
}

class _PackagingBatchPurchaseTile extends StatelessWidget {
  const _PackagingBatchPurchaseTile({
    required this.row,
    required this.compact,
  });

  final _BatchPackagingRow row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _BatchPurchaseTile(
      title: row.item.packagingName,
      quantityController: row.quantityController,
      costController: row.costController,
      compact: compact,
    );
  }
}

class _BatchPurchaseTile extends StatelessWidget {
  const _BatchPurchaseTile({
    required this.title,
    required this.quantityController,
    required this.costController,
    required this.compact,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final TextEditingController quantityController;
  final TextEditingController costController;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  AppText(
                    subtitle!,
                    maxLines: 2,
                    variant: AppTextVariant.label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Cantidad',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: costController,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Costo',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((subtitle ?? '').isNotEmpty)
                  AppText(
                    subtitle!,
                    maxLines: 1,
                    variant: AppTextVariant.label,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Cant.',
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextField(
              controller: costController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Costo',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
