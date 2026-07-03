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
  late bool _allSelected;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _allSelected = widget.initialValue.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final mediaSize = MediaQuery.sizeOf(context);
    final compact = mediaSize.width < 390;
    final dialogWidth = (mediaSize.width * .94).clamp(300.0, 520.0);
    final maxHeight = mediaSize.height * .92;
    final padding = compact ? 10.0 : 14.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 12,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: dialogWidth,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _KeyboardHeader(title: widget.title, compact: compact),
                SizedBox(height: compact ? 6 : 8),
                _NumericDisplay(
                  allSelected: _allSelected,
                  compact: compact,
                  errorText: _errorText,
                  prefixText: widget.prefixText,
                  value: _value,
                ),
                SizedBox(height: compact ? 8 : 10),
                _NumericKeypad(
                  onBackspace: _backspace,
                  onClear: _clear,
                  onKey: _append,
                ),
                SizedBox(height: compact ? 8 : 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.tertiary,
                          foregroundColor: colorScheme.onTertiary,
                          minimumSize: Size.fromHeight(compact ? 50 : 56),
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
                          minimumSize: Size.fromHeight(compact ? 50 : 56),
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
      _value = _allSelected ? text : _value + text;
      _allSelected = false;
    });
  }

  void _backspace() {
    if (_value.isEmpty) return;
    setState(() {
      _errorText = null;
      if (_allSelected) {
        _value = '';
      } else {
        _value = _value.substring(0, _value.length - 1);
      }
      _allSelected = false;
    });
  }

  void _clear() {
    setState(() {
      _errorText = null;
      _value = '';
      _allSelected = false;
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
  const _KeyboardHeader({required this.compact, required this.title});

  final bool compact;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      color: colorScheme.primary,
      height: compact ? 48 : 52,
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
    required this.allSelected,
    required this.compact,
    required this.value,
    this.errorText,
    this.prefixText,
  });

  final bool allSelected;
  final bool compact;
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: allSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: compact ? 22 : null,
              ),
            ),
          ),
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
    const keys = [
      '50',
      '100',
      '200',
      '500',
      '7',
      '8',
      '9',
      '4',
      '5',
      '6',
      '1',
      '2',
      '3',
      '.',
      '0',
      'backspace',
      '00',
      '000',
      'C',
      '1000',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final gap = compact ? 5.0 : 6.0;
        final keyHeight = compact ? 46.0 : 52.0;
        final keyWidth = (constraints.maxWidth - (gap * 3)) / 4;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.count(
              childAspectRatio: keyWidth / keyHeight,
              crossAxisCount: 4,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: [
                for (final key in keys) _buildKey(key, keyHeight),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKey(String key, double keyHeight) {
    if (key == 'backspace') {
      return _KeypadButton(
        icon: Icons.backspace_outlined,
        keyHeight: keyHeight,
        onPressed: onBackspace,
      );
    }
    if (key == 'C') {
      return _KeypadButton(
        keyHeight: keyHeight,
        label: key,
        onPressed: onClear,
      );
    }
    return _KeypadButton(
      keyHeight: keyHeight,
      label: key,
      onPressed: () => onKey(key),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.keyHeight,
    required this.onPressed,
    this.icon,
    this.label,
  });

  final IconData? icon;
  final double keyHeight;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, keyHeight),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: icon == null
          ? Text(
              label!,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            )
          : Icon(icon, size: keyHeight * .5),
    );
  }
}
