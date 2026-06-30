import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_pad.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shows a touch-first text keyboard dialog.
Future<String?> showTouchTextKeyboardDialog({
  required BuildContext context,
  required String title,
  String initialValue = '',
  String? hintText,
  String? label,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => TouchTextKeyboardDialog(
      hintText: hintText,
      initialValue: initialValue,
      label: label,
      title: title,
    ),
  );
}

/// Touch-first dialog with a reusable text keyboard.
class TouchTextKeyboardDialog extends StatefulWidget {
  /// Creates a text keyboard dialog.
  const TouchTextKeyboardDialog({
    required this.title,
    this.hintText,
    this.initialValue = '',
    this.label,
    super.key,
  });

  /// Hint shown when the value is empty.
  final String? hintText;

  /// Initial text value.
  final String initialValue;

  /// Optional field label.
  final String? label;

  /// Dialog title.
  final String title;

  @override
  State<TouchTextKeyboardDialog> createState() {
    return _TouchTextKeyboardDialogState();
  }
}

class _TouchTextKeyboardDialogState extends State<TouchTextKeyboardDialog> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * .92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 860),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TextKeyboardHeader(title: widget.title),
                const SizedBox(height: 8),
                _TextDisplay(
                  hintText: widget.hintText,
                  label: widget.label,
                  value: _value,
                ),
                const SizedBox(height: 10),
                TouchTextKeyboardPad(
                  onBackspace: _backspace,
                  onClear: _clear,
                  onKey: _append,
                  onSpace: () => _append(' '),
                ),
                const SizedBox(height: 10),
                _TextKeyboardActions(
                  colorScheme: colorScheme,
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: _confirm,
                  okLabel: l10n.okAction,
                  cancelLabel: l10n.cancelAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _append(String text) {
    setState(() => _value += text);
  }

  void _backspace() {
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  void _clear() {
    setState(() => _value = '');
  }

  void _confirm() {
    Navigator.of(context).pop(_value.trim());
  }
}

class _TextKeyboardActions extends StatelessWidget {
  const _TextKeyboardActions({
    required this.cancelLabel,
    required this.colorScheme,
    required this.okLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String cancelLabel;
  final ColorScheme colorScheme;
  final String okLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(okLabel),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: onCancel,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(cancelLabel),
          ),
        ),
      ],
    );
  }
}

class _TextKeyboardHeader extends StatelessWidget {
  const _TextKeyboardHeader({required this.title});

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

class _TextDisplay extends StatelessWidget {
  const _TextDisplay({
    required this.value,
    this.hintText,
    this.label,
  });

  final String? hintText;
  final String? label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value.isEmpty ? hintText ?? '' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: value.isEmpty
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
