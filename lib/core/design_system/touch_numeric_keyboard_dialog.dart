import 'package:flutter/material.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Builds the result returned by the numeric keyboard.
typedef TouchNumericResultBuilder<T> = T? Function(String value);

/// Validates the current numeric keyboard value.
typedef TouchNumericValidator = String? Function(String value);

/// Shows a touch-first numeric keyboard dialog.
Future<T?> showTouchNumericKeyboardDialog<T>({
  required BuildContext context,
  required String title,
  required TouchNumericResultBuilder<T> resultBuilder,
  String initialValue = '',
  String? prefixText,
  TouchNumericValidator? validator,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => TouchNumericKeyboardDialog<T>(
      initialValue: initialValue,
      prefixText: prefixText,
      resultBuilder: resultBuilder,
      title: title,
      validator: validator,
    ),
  );
}

/// Touch-first dialog with a reusable numeric keypad.
class TouchNumericKeyboardDialog<T> extends StatefulWidget {
  /// Creates a numeric keyboard dialog.
  const TouchNumericKeyboardDialog({
    required this.resultBuilder,
    required this.title,
    this.initialValue = '',
    this.prefixText,
    this.validator,
    super.key,
  });

  /// Initial value shown in the input area.
  final String initialValue;

  /// Optional prefix shown before the current value.
  final String? prefixText;

  /// Converts the entered text into the dialog result.
  final TouchNumericResultBuilder<T> resultBuilder;

  /// Dialog title.
  final String title;

  /// Optional validation callback.
  final TouchNumericValidator? validator;

  @override
  State<TouchNumericKeyboardDialog<T>> createState() {
    return _TouchNumericKeyboardDialogState<T>();
  }
}

class _TouchNumericKeyboardDialogState<T>
    extends State<TouchNumericKeyboardDialog<T>> {
  late String _value;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _KeyboardHeader(title: widget.title),
                const SizedBox(height: 8),
                _NumericDisplay(
                  errorText: _errorText,
                  prefixText: widget.prefixText,
                  value: _value,
                ),
                const SizedBox(height: 10),
                _NumericKeypad(
                  onBackspace: _backspace,
                  onClear: _clear,
                  onKey: _append,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.tertiary,
                          foregroundColor: colorScheme.onTertiary,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Text(l10n.okAction),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Text(l10n.cancelAction),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _append(String text) {
    setState(() {
      _errorText = null;
      _value += text;
    });
  }

  void _backspace() {
    if (_value.isEmpty) return;
    setState(() {
      _errorText = null;
      _value = _value.substring(0, _value.length - 1);
    });
  }

  void _clear() {
    setState(() {
      _errorText = null;
      _value = '';
    });
  }

  void _confirm() {
    final validationError = widget.validator?.call(_value);
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    final result = widget.resultBuilder(_value);
    if (result == null) {
      setState(
        () => _errorText = AppLocalizations.of(context).numericFieldError,
      );
      return;
    }

    Navigator.of(context).pop(result);
  }
}

class _KeyboardHeader extends StatelessWidget {
  const _KeyboardHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      color: colorScheme.primary,
      height: 52,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NumericDisplay extends StatelessWidget {
  const _NumericDisplay({
    required this.value,
    this.errorText,
    this.prefixText,
  });

  final String? errorText;
  final String? prefixText;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = value.isEmpty ? '0' : value;
    return InputDecorator(
      decoration: InputDecoration(errorText: errorText, prefixText: prefixText),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    required this.onBackspace,
    required this.onClear,
    required this.onKey,
  });

  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    const keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', ',', '0', '.'];
    return GridView.count(
      childAspectRatio: 2.5,
      crossAxisCount: 4,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        for (final key in keys)
          _KeypadButton(label: key, onPressed: () => onKey(key)),
        _KeypadButton(icon: Icons.backspace_outlined, onPressed: onBackspace),
        _KeypadButton(label: '00', onPressed: () => onKey('00')),
        _KeypadButton(label: '-', onPressed: () => onKey('-')),
        _KeypadButton(label: 'C', onPressed: onClear),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.onPressed,
    this.icon,
    this.label,
  });

  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: icon == null
          ? Text(label!, style: Theme.of(context).textTheme.titleLarge)
          : Icon(icon, size: 28),
    );
  }
}
