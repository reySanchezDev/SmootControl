part of 'pos_ticket_panel.dart';

const _posForeignCurrencyCode = 'USD';

class _TicketTotalBand extends StatelessWidget {
  const _TicketTotalBand({
    required this.lines,
    required this.salesTypes,
    required this.productsVisible,
    this.showPhoneBand = true,
    this.selectedSalesTypeId,
    this.onProductsVisibilityToggled,
  });

  final List<PosCartLine> lines;
  final List<SalesType> salesTypes;
  final bool showPhoneBand;
  final String? selectedSalesTypeId;
  final bool productsVisible;
  final VoidCallback? onProductsVisibilityToggled;

  @override
  Widget build(BuildContext context) {
    final total = lines.fold(0, (sum, line) => sum + line.totalInCents);
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _ticketMinWidth;
        if (compact) {
          final phoneLayout = constraints.maxWidth < 560;
          if (phoneLayout && !showPhoneBand) {
            return const SizedBox.shrink();
          }
          if (phoneLayout) {
            return Container(
              color: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: _MobileTicketTotalBand(
                onProductsVisibilityToggled: onProductsVisibilityToggled,
                productsVisible: productsVisible,
                salesTypes: salesTypes,
                selectedSalesTypeId: selectedSalesTypeId,
                total: total,
              ),
            );
          }

          return Container(
            color: colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _ProductsVisibilityButton(
                  onPressed: onProductsVisibilityToggled,
                  productsVisible: productsVisible,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _SalesTypeSelector(
                      salesTypes: salesTypes,
                      selectedSalesTypeId: selectedSalesTypeId,
                      alignment: WrapAlignment.start,
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 10),
                const Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ExchangeRateTodayText(compact: true),
                  ),
                ),
                const SizedBox(width: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 112),
                  child: _TotalAmountText(total: total),
                ),
              ],
            ),
          );
        }

        return Container(
          color: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              _ProductsVisibilityButton(
                onPressed: onProductsVisibilityToggled,
                productsVisible: productsVisible,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SalesTypeSelector(
                    salesTypes: salesTypes,
                    selectedSalesTypeId: selectedSalesTypeId,
                    alignment: WrapAlignment.end,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _ExchangeRateTodayText(compact: true),
                ),
              ),
              const SizedBox(width: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 128),
                child: _TotalAmountText(total: total),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MobileTicketTotalBand extends StatelessWidget {
  const _MobileTicketTotalBand({
    required this.productsVisible,
    required this.salesTypes,
    required this.total,
    this.onProductsVisibilityToggled,
    this.selectedSalesTypeId,
  });

  final bool productsVisible;
  final List<SalesType> salesTypes;
  final VoidCallback? onProductsVisibilityToggled;
  final String? selectedSalesTypeId;
  final int total;

  @override
  Widget build(BuildContext context) {
    final activeTypes = salesTypes.where((type) => type.isActive).toList();

    return Row(
      children: [
        _ProductsVisibilityButton(
          onPressed: onProductsVisibilityToggled,
          productsVisible: productsVisible,
        ),
        if (activeTypes.isNotEmpty) ...[
          const SizedBox(width: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 122),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final type in activeTypes) ...[
                    _SalesTypeChip(
                      compact: true,
                      label: _mobileSalesTypeLabel(type),
                      selected: type.id == selectedSalesTypeId,
                      onPressed: () {
                        context.read<PosBloc>().add(
                          PosSalesTypeSelected(type.id),
                        );
                      },
                    ),
                    if (type != activeTypes.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(child: _TotalAmountText(total: total)),
      ],
    );
  }
}

class _TotalAmountText extends StatelessWidget {
  const _TotalAmountText({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.centerRight,
      fit: BoxFit.scaleDown,
      child: Text(
        MoneyFormatter.format(total),
        maxLines: 1,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        textAlign: TextAlign.end,
      ),
    );
  }
}

class _ProductsVisibilityButton extends StatelessWidget {
  const _ProductsVisibilityButton({
    required this.productsVisible,
    this.onPressed,
  });

  final bool productsVisible;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = productsVisible
        ? l10n.posHideProductsCompactAction
        : l10n.posShowProductsCompactAction;

    return Material(
      color: AppPalette.primaryDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colorScheme.onPrimary.withValues(alpha: .22)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
