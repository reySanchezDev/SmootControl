part of 'exchange_rates_page.dart';

/// Editable daily exchange rate, saved when the user leaves the field.
class ExchangeRateTile extends StatefulWidget {
  /// Creates a daily rate field with save-result feedback.
  const ExchangeRateTile({
    required this.currencyCode,
    required this.date,
    required this.onSaved,
    this.focusNode,
    this.nextFocusNode,
    this.previousFocusNode,
    this.rate,
    super.key,
  });

  /// Foreign currency.
  final String currencyCode;

  /// Business date represented by this row.
  final DateTime date;

  /// Persisted rate, if one exists.
  final ExchangeRate? rate;

  /// Stable focus for this day; owned by the parent when provided.
  final FocusNode? focusNode;

  /// Explicit next daily cell, independent of workspace/sidebar tab order.
  final FocusNode? nextFocusNode;

  /// Explicit previous daily cell for Shift+Tab.
  final FocusNode? previousFocusNode;

  /// Preserves the repository's explicit success/failure result.
  final Future<AppResult<ExchangeRate>> Function(DateTime, int) onSaved;

  @override
  State<ExchangeRateTile> createState() => _ExchangeRateTileState();
}

class _ExchangeRateTileState extends State<ExchangeRateTile> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  int? _lastSavedUnits;
  bool _dirty = false;
  bool _saving = false;
  String? _error;
  bool _savedFeedback = false;

  @override
  void initState() {
    super.initState();
    _lastSavedUnits = _rateUnits(widget.rate);
    _controller = TextEditingController(text: _rateText);
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant ExchangeRateTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_rateUnits(oldWidget.rate) != _rateUnits(widget.rate) &&
        !_dirty &&
        !_saving &&
        !_focusNode.hasFocus) {
      _lastSavedUnits = _rateUnits(widget.rate);
      _controller.text = _rateText;
      _savedFeedback = false;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  int? _rateUnits(ExchangeRate? rate) {
    if (rate == null) return null;
    return rate.rateInTenThousandths ?? rate.rateInCents * 100;
  }

  String get _rateText {
    final rate = widget.rate;
    return rate == null ? '' : rate.rate.toStringAsFixed(4);
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus) unawaited(_commit());
  }

  void _onChanged(String _) {
    setState(() {
      _dirty = true;
      _error = null;
      _savedFeedback = false;
    });
  }

  /// Serializes successive edits of the same cell without losing the latest.
  Future<void> _commit() async {
    if (_saving || !_dirty) return;
    final units = _parseExchangeRate(_controller.text);
    if (units == null) {
      if (mounted) {
        setState(() => _error = 'Ingresá una tasa válida mayor que cero y hasta 4 decimales.');
      }
      return;
    }
    if (units == _lastSavedUnits) {
      setState(() {
        _dirty = false;
        _error = null;
      });
      return;
    }

    final submittedText = _controller.text;
    setState(() {
      _saving = true;
      _error = null;
      _savedFeedback = false;
    });
    try {
      final result = await widget.onSaved(widget.date, units);
      if (!mounted) return;
      switch (result) {
        case AppSuccess():
          setState(() {
            _lastSavedUnits = units;
            _dirty = _controller.text != submittedText;
            _saving = false;
            _savedFeedback = !_dirty;
          });
          if (_dirty && !_focusNode.hasFocus) unawaited(_commit());
        case AppFailureResult(:final error):
          setState(() {
            _saving = false;
            _error = error.message;
            _dirty = true;
          });
      }
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = true;
        _error = 'No se pudo guardar. Revisá la conexión y reintentá.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.date.day}/${widget.date.month}/${widget.date.year}';
    final subtitle = '${widget.currencyCode} → ${MoneyFormatter.symbol}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                _rateField(),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 150, child: Text(title)),
              SizedBox(width: 110, child: Text(subtitle)),
              SizedBox(
                width: BackofficeFormStandards.dateWidth,
                child: _rateField(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rateField() {
    final l10n = AppLocalizations.of(context);
    final statusText = _saving
        ? 'Guardando…'
        : _savedFeedback
        ? 'Guardado'
        : null;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.tab) {
          return KeyEventResult.ignored;
        }
        final target = HardwareKeyboard.instance.isShiftPressed
            ? widget.previousFocusNode
            : widget.nextFocusNode;
        if (target == null) return KeyEventResult.ignored;
        target.requestFocus();
        return KeyEventResult.handled;
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        onChanged: _onChanged,
        onTapOutside: (_) {
          _focusNode.unfocus();
          unawaited(_commit());
        },
        onSubmitted: (_) {
          final next = widget.nextFocusNode;
          if (next != null) {
            next.requestFocus();
          } else {
            FocusScope.of(context).nextFocus();
          }
          unawaited(_commit());
        },
        decoration: InputDecoration(
          isDense: true,
          labelText: l10n.exchangeRateField,
          helperText: _error == null ? statusText : null,
          errorText: _error,
          suffixIcon: _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _savedFeedback
              ? const Icon(Icons.check_circle_outline, size: 20)
              : null,
        ),
      ),
    );
  }
}
