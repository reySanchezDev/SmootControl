part of 'exchange_rates_page.dart';

class _RateTile extends StatefulWidget {
  const _RateTile({
    required this.currencyCode,
    required this.date,
    required this.onSaved,
    this.rate,
  });

  final String currencyCode;
  final DateTime date;
  final ExchangeRate? rate;
  final Future<void> Function(DateTime date, int rateInCents) onSaved;

  @override
  State<_RateTile> createState() => _RateTileState();
}

class _RateTileState extends State<_RateTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _rateText);
  }

  @override
  void didUpdateWidget(covariant _RateTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate?.rateInCents != widget.rate?.rateInCents) {
      _controller.text = _rateText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _rateText {
    final rate = widget.rate;
    if (rate == null) return '';
    return rate.rate.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = '${widget.date.day}/${widget.date.month}/${widget.date.year}';
    final subtitle = '${widget.currencyCode} -> ${MoneyFormatter.symbol}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppText(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  variant: AppTextVariant.label,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _rateField(l10n)),
                    IconButton(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _save,
                      tooltip: l10n.saveAction,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: AppText(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: AppText(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: SizedBox(
            width: 180,
            child: Row(
              children: [
                Expanded(child: _rateField(l10n)),
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _save,
                  tooltip: l10n.saveAction,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rateField(AppLocalizations l10n) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: l10n.exchangeRateField),
      keyboardType: TextInputType.number,
    );
  }

  Future<void> _save() async {
    final rateInCents = MoneyFormatter.parseToCents(_controller.text);
    if (rateInCents == null) return;
    await widget.onSaved(widget.date, rateInCents);
  }
}
