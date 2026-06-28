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
    return Column(
      children: [
        _KeyboardRow(
          keys: const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
          onKey: onKey,
        ),
        const SizedBox(height: 6),
        _KeyboardRow(
          keys: const ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
          onKey: onKey,
        ),
        const SizedBox(height: 6),
        _KeyboardRow(
          keys: const ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'N'],
          onKey: onKey,
        ),
        const SizedBox(height: 6),
        _KeyboardRow(
          keys: const ['Z', 'X', 'C', 'V', 'B', 'N', 'M', '-', '.', '/'],
          onKey: onKey,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _KeyboardButton(
                icon: Icons.backspace_outlined,
                onPressed: onBackspace,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: _KeyboardButton(label: 'ESPACIO', onPressed: onSpace),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _KeyboardButton(label: 'C', onPressed: onClear),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyboardRow extends StatelessWidget {
  const _KeyboardRow({
    required this.keys,
    required this.onKey,
  });

  final List<String> keys;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final key in keys) ...[
          Expanded(
            child: _KeyboardButton(label: key, onPressed: () => onKey(key)),
          ),
          if (key != keys.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({
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
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: icon == null
          ? Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : Icon(icon, size: 24),
    );
  }
}
