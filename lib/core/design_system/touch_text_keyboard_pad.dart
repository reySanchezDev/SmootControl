import 'package:flutter/material.dart';

/// Touch QWERTY-like keyboard used by POS text dialogs.
class TouchTextKeyboardPad extends StatelessWidget {
  /// Creates a touch text keyboard.
  const TouchTextKeyboardPad({
    required this.onBackspace,
    required this.onClear,
    required this.onKey,
    required this.onSpace,
    super.key,
  });

  /// Removes the last typed character.
  final VoidCallback onBackspace;

  /// Clears the current text.
  final VoidCallback onClear;

  /// Adds one visible key to the current text.
  final ValueChanged<String> onKey;

  /// Adds a blank space to the current text.
  final VoidCallback onSpace;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final gap = compact ? 4.0 : 6.0;
        final keyHeight = compact ? 42.0 : 48.0;
        final fontSize = compact ? 16.0 : 18.0;

        return Column(
          children: [
            _KeyboardRow(
              keys: const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
              gap: gap,
              keyHeight: keyHeight,
              fontSize: fontSize,
              onKey: onKey,
            ),
            SizedBox(height: gap),
            _KeyboardRow(
              keys: const ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
              gap: gap,
              keyHeight: keyHeight,
              fontSize: fontSize,
              onKey: onKey,
            ),
            SizedBox(height: gap),
            _KeyboardRow(
              keys: const ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'N'],
              gap: gap,
              keyHeight: keyHeight,
              fontSize: fontSize,
              onKey: onKey,
            ),
            SizedBox(height: gap),
            _KeyboardRow(
              keys: const ['Z', 'X', 'C', 'V', 'B', 'N', 'M', '-', '.', '/'],
              gap: gap,
              keyHeight: keyHeight,
              fontSize: fontSize,
              onKey: onKey,
            ),
            SizedBox(height: gap),
            Row(
              children: [
                Expanded(
                  child: _KeyboardButton(
                    icon: Icons.backspace_outlined,
                    keyHeight: keyHeight,
                    onPressed: onBackspace,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: 4,
                  child: _KeyboardButton(
                    label: 'ESPACIO',
                    keyHeight: keyHeight,
                    fontSize: fontSize,
                    onPressed: onSpace,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _KeyboardButton(
                    label: 'C',
                    keyHeight: keyHeight,
                    fontSize: fontSize,
                    onPressed: onClear,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _KeyboardRow extends StatelessWidget {
  const _KeyboardRow({
    required this.fontSize,
    required this.gap,
    required this.keyHeight,
    required this.keys,
    required this.onKey,
  });

  final double fontSize;
  final double gap;
  final double keyHeight;
  final List<String> keys;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final key in keys) ...[
          Expanded(
            child: _KeyboardButton(
              label: key,
              keyHeight: keyHeight,
              fontSize: fontSize,
              onPressed: () => onKey(key),
            ),
          ),
          if (key != keys.last) SizedBox(width: gap),
        ],
      ],
    );
  }
}

class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({
    required this.keyHeight,
    required this.onPressed,
    this.fontSize,
    this.icon,
    this.label,
  });

  final double? fontSize;
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: fontSize,
              ),
            )
          : Icon(icon, size: keyHeight * .48),
    );
  }
}
