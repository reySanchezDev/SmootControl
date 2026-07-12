part of 'pos_ticket_panel.dart';

const _servedWidth = 92.0;
const _quantityWidth = 124.0;
const _moneyWidth = 130.0;
const _removeGap = 18.0;
const _removeWidth = 74.0;
const _ticketHorizontalPadding = 24.0;
const double _ticketMinWidth =
    _servedWidth +
    _quantityWidth +
    _moneyWidth * 2 +
    _removeGap +
    _removeWidth +
    _ticketHorizontalPadding;

class _TicketHeader extends StatelessWidget {
  const _TicketHeader();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppPalette.surfaceSecondary,
      child: _TicketColumnRow(
        verticalPadding: 8,
        description: _HeaderText(kind: _HeaderKind.description),
        served: _HeaderText(kind: _HeaderKind.served),
        quantity: _HeaderText(kind: _HeaderKind.quantity),
        price: _HeaderText(kind: _HeaderKind.price),
        amount: _HeaderText(kind: _HeaderKind.amount),
        remove: _HeaderText(kind: _HeaderKind.remove),
      ),
    );
  }
}

enum _HeaderKind { description, served, quantity, price, amount, remove }

class _HeaderText extends StatelessWidget {
  const _HeaderText({required this.kind});

  final _HeaderKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = switch (kind) {
      _HeaderKind.description => l10n.posDescriptionColumn,
      _HeaderKind.served => l10n.posServedColumn,
      _HeaderKind.quantity => l10n.posQuantityColumn,
      _HeaderKind.price => l10n.posPriceColumn,
      _HeaderKind.amount => l10n.posAmountColumn,
      _HeaderKind.remove => l10n.posRemoveColumn,
    };
    final centered =
        kind == _HeaderKind.served ||
        kind == _HeaderKind.quantity ||
        kind == _HeaderKind.remove;
    final rightAligned =
        kind == _HeaderKind.price || kind == _HeaderKind.amount;
    return AppText(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppPalette.textPrimary),
      textAlign: centered
          ? TextAlign.center
          : rightAligned
          ? TextAlign.end
          : TextAlign.start,
      variant: AppTextVariant.label,
    );
  }
}

class _TicketLine extends StatelessWidget {
  const _TicketLine({required this.line});

  final PosCartLine line;

  @override
  Widget build(BuildContext context) {
    return _TicketColumnRow(
      verticalPadding: 6,
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppText(
            line.product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (line.selectedOptionsLabel.isNotEmpty)
            AppText(
              line.selectedOptionsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              variant: AppTextVariant.label,
            ),
        ],
      ),
      served: _ServedToggle(line: line),
      quantity: _QuantityControls(line: line),
      price: AppText(
        MoneyFormatter.format(line.product.priceInCents),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      ),
      amount: AppText(
        MoneyFormatter.format(line.totalInCents),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      ),
      remove: IconButton(
        tooltip: AppLocalizations.of(context).removeAction,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => unawaited(_removeLine(context)),
      ),
    );
  }

  Future<void> _removeLine(BuildContext context) async {
    final confirmed = await confirmRemovePosLine(context, line: line);
    if (!confirmed || !context.mounted) return;
    context.read<PosBloc>().add(PosProductRemoved(line.lineKey));
  }
}

class _TicketColumnRow extends StatelessWidget {
  const _TicketColumnRow({
    required this.description,
    required this.served,
    required this.quantity,
    required this.price,
    required this.amount,
    required this.remove,
    this.verticalPadding = 4,
  });

  final Widget description;
  final Widget served;
  final Widget quantity;
  final Widget price;
  final Widget amount;
  final Widget remove;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > _ticketMinWidth
            ? constraints.maxWidth
            : _ticketMinWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: verticalPadding,
              ),
              child: Row(
                children: [
                  Expanded(child: description),
                  SizedBox(
                    width: _servedWidth,
                    child: Center(child: served),
                  ),
                  SizedBox(
                    width: _quantityWidth,
                    child: Center(child: quantity),
                  ),
                  SizedBox(
                    width: _moneyWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: price,
                    ),
                  ),
                  SizedBox(
                    width: _moneyWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: amount,
                    ),
                  ),
                  const SizedBox(width: _removeGap),
                  SizedBox(
                    width: _removeWidth,
                    child: Center(child: remove),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
