part of 'pos_ticket_panel.dart';

const _posForeignCurrencyCode = 'USD';

class _TicketTotalBand extends StatelessWidget {
  const _TicketTotalBand({
    required this.lines,
    required this.productsVisible,
    this.onProductsVisibilityToggled,
  });

  final List<PosCartLine> lines;
  final bool productsVisible;
  final VoidCallback? onProductsVisibilityToggled;

  @override
  Widget build(BuildContext context) {
    final total = lines.fold(0, (sum, line) => sum + line.totalInCents);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.primary,
      height: 48,
      child: _TicketColumnRow(
        description: Align(
          alignment: Alignment.centerLeft,
          child: _ProductsVisibilityButton(
            onPressed: onProductsVisibilityToggled,
            productsVisible: productsVisible,
          ),
        ),
        served: const SizedBox.shrink(),
        quantity: const SizedBox.shrink(),
        price: const _ExchangeRateTodayText(compact: true),
        amount: Text(
          MoneyFormatter.format(total),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
          ),
          textAlign: TextAlign.end,
        ),
        remove: const SizedBox.shrink(),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
