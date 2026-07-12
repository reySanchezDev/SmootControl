part of 'touch_numeric_keyboard_dialog.dart';

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
