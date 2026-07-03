part of 'pos_ticket_panel.dart';

const _posForeignCurrencyCode = 'USD';

class _TicketTotalBand extends StatelessWidget {
  const _TicketTotalBand({
    required this.lines,
    required this.salesTypes,
    required this.productsVisible,
    this.hideProductsVisibilityButtonOnPhone = false,
    this.hideTotalOnPhone = false,
    this.selectedSalesTypeId,
    this.onProductsVisibilityToggled,
  });

  final List<PosCartLine> lines;
  final List<SalesType> salesTypes;
  final bool hideProductsVisibilityButtonOnPhone;
  final bool hideTotalOnPhone;
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
          if (phoneLayout) {
            return Container(
              color: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: _MobileTicketTotalBand(
                onProductsVisibilityToggled: onProductsVisibilityToggled,
                hideProductsVisibilityButton:
                    hideProductsVisibilityButtonOnPhone,
                hideTotal: hideTotalOnPhone,
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
    required this.hideProductsVisibilityButton,
    required this.hideTotal,
    required this.productsVisible,
    required this.salesTypes,
    required this.total,
    this.onProductsVisibilityToggled,
    this.selectedSalesTypeId,
  });

  final bool hideProductsVisibilityButton;
  final bool hideTotal;
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
        if (!hideProductsVisibilityButton)
          _ProductsVisibilityButton(
            onPressed: onProductsVisibilityToggled,
            productsVisible: productsVisible,
          ),
        if (activeTypes.isNotEmpty) ...[
          SizedBox(width: hideProductsVisibilityButton ? 0 : 14),
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
        if (!hideTotal) Expanded(child: _TotalAmountText(total: total)),
      ],
    );
  }
}

String _mobileSalesTypeLabel(SalesType type) {
  final normalized = type.code.trim().toLowerCase();
  if (normalized == 'dine_in' || normalized == 'eat_here') return 'Aquí';
  if (normalized == 'to_go' || normalized == 'takeout') return 'GO';

  final name = type.name.trim().toLowerCase();
  if (name == 'comer aqui' || name == 'aqui') return 'Aquí';
  if (name == 'para llevar' || name == 'llevar') return 'GO';
  return type.name;
}

class _SalesTypeSelector extends StatelessWidget {
  const _SalesTypeSelector({
    required this.salesTypes,
    required this.selectedSalesTypeId,
    required this.alignment,
  });

  final List<SalesType> salesTypes;
  final String? selectedSalesTypeId;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final activeTypes = salesTypes.where((type) => type.isActive).toList();
    if (activeTypes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in activeTypes)
          _SalesTypeChip(
            label: type.name,
            selected: type.id == selectedSalesTypeId,
            onPressed: () {
              context.read<PosBloc>().add(PosSalesTypeSelected(type.id));
            },
          ),
      ],
    );
  }
}

class _SalesTypeChip extends StatelessWidget {
  const _SalesTypeChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final bool compact;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 54 : 72,
        minHeight: 38,
        maxWidth: compact ? 80 : 180,
      ),
      child: Material(
        color: selected ? AppPalette.primaryDark : colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: colorScheme.onPrimary.withValues(alpha: selected ? .35 : .2),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: selected ? null : onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 13,
              vertical: 9,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalAmountText extends StatelessWidget {
  const _TotalAmountText({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      MoneyFormatter.format(total),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.onPrimary,
      ),
      textAlign: TextAlign.end,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                productsVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: colorScheme.onPrimary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExchangeRateTodayText extends StatefulWidget {
  const _ExchangeRateTodayText({this.compact = false});

  final bool compact;

  @override
  State<_ExchangeRateTodayText> createState() => _ExchangeRateTodayTextState();
}

class _ExchangeRateTodayTextState extends State<_ExchangeRateTodayText> {
  late Future<String> _labelFuture;

  @override
  void initState() {
    super.initState();
    _labelFuture = _loadLabel();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<String>(
      future: _labelFuture,
      builder: (context, snapshot) {
        final text =
            snapshot.data ?? _baseLabel(AppLocalizations.of(context), '--');
        return Row(
          mainAxisAlignment: widget.compact
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.currency_exchange_outlined,
              color: colorScheme.onPrimary,
              size: widget.compact ? 16 : 18,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: widget.compact ? TextAlign.end : TextAlign.start,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _loadLabel() async {
    final l10n = AppLocalizations.of(context);
    final result = await serviceLocator<IExchangeRateRepository>()
        .getRateForDate(
          currencyCode: _posForeignCurrencyCode,
          date: DateTime.now(),
        );
    if (!mounted) return _baseLabel(l10n, '--');

    return switch (result) {
      AppSuccess(:final value) when value != null => _baseLabel(
        l10n,
        value.rate.toStringAsFixed(2),
      ),
      AppSuccess() => _baseLabel(l10n, l10n.exchangeRateNotConfigured),
      AppFailureResult() => _baseLabel(l10n, l10n.exchangeRateNotConfigured),
    };
  }

  String _baseLabel(AppLocalizations l10n, String value) {
    return widget.compact
        ? l10n.posTodayExchangeRateCompactLabel(value)
        : l10n.posTodayExchangeRateLabel(value);
  }
}
