import 'package:flutter/material.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'touch_numeric_keyboard_widgets.dart';

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
