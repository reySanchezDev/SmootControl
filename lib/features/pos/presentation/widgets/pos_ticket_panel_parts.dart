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

class _ServedToggle extends StatelessWidget {
  const _ServedToggle({required this.line});

  final PosCartLine line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final served = line.isServed;
    final background = served ? AppPalette.success : AppPalette.surface;
    final foreground = served ? AppPalette.surface : colorScheme.outline;
    final border = served ? AppPalette.success : AppPalette.border;
    final tooltip = served
        ? AppLocalizations.of(context).posMarkPendingTooltip
        : AppLocalizations.of(context).posMarkServedTooltip;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: served,
        label: AppLocalizations.of(context).posServedColumn,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              context.read<PosBloc>().add(
                PosCartLineServedToggled(line.lineKey),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                alignment: served
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: foreground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    served ? Icons.check : Icons.circle_outlined,
                    color: background,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityControls extends StatelessWidget {
  const _QuantityControls({required this.line});

  final PosCartLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityButton(
          icon: Icons.remove,
          onPressed: line.quantity <= 1
              ? null
              : () {
                  context.read<PosBloc>().add(
                    PosCartLineDecremented(line.lineKey),
                  );
                },
        ),
        SizedBox(
          width: 32,
          child: AppText(
            '${line.quantity}',
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        _QuantityButton(
          icon: Icons.add,
          onPressed: () {
            context.read<PosBloc>().add(PosCartLineIncremented(line.lineKey));
          },
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final foreground = enabled ? colorScheme.primary : colorScheme.outline;
    final borderColor = enabled ? colorScheme.primary : colorScheme.outline;
    final background = enabled
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surfaceContainerHighest;

    return SizedBox.square(
      dimension: 36,
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: CircleBorder(side: BorderSide(color: borderColor)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: foreground, size: 20),
        ),
      ),
    );
  }
}
