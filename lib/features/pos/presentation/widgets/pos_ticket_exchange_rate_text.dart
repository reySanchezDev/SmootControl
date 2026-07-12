part of 'pos_ticket_panel.dart';

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
