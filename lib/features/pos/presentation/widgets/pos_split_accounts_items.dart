import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/theme/app_semantic_colors.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Draggable/tappable item row for the split-account workspace.
class SplitAccountItemRow extends StatelessWidget {
  /// Creates a split item row.
  const SplitAccountItemRow({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Draft item displayed by the row.
  final SaleItemDraft item;

  /// Whether this item is selected for touch assignment.
  final bool selected;

  /// Item tap callback.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;

    return LongPressDraggable<SaleItemDraft>(
      data: item,
      feedback: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        child: SizedBox(
          width: 320,
          child: Opacity(opacity: 0.9, child: _row(context)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _row(context)),
      child: Material(
        color: selected
            ? semanticColors.splitSelectedItemBackground
            : colorScheme.surface.withValues(alpha: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: selected
              ? BorderSide(color: colorScheme.secondary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: _row(context),
        ),
      ),
    );
  }

  Widget _row(BuildContext context) {
    final options = item.selectedOptionsLabel;
    final productLabel = options == null || options.isEmpty
        ? item.productName
        : '${item.productName}\n$options';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: selected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20,
                  )
                : const Icon(Icons.radio_button_unchecked, size: 20),
          ),
          Expanded(
            flex: 5,
            child: AppText(
              productLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: AppText(
              item.quantity.toString(),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: AppText(
              MoneyFormatter.format(item.totalInCents),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// Total row for one split panel.
class SplitAccountTotal extends StatelessWidget {
  /// Creates a split total row.
  const SplitAccountTotal({required this.items, super.key});

  /// Items included in the total.
  final List<SaleItemDraft> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0, (sum, item) => sum + item.totalInCents);

    return Row(
      children: [
        Expanded(
          child: AppText(AppLocalizations.of(context).splitAccountTotalLabel),
        ),
        AppText(
          MoneyFormatter.format(total),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          variant: AppTextVariant.titleMedium,
        ),
      ],
    );
  }
}
