part of 'pos_ticket_panel.dart';

class _ServedToggle extends StatelessWidget {
  const _ServedToggle({required this.line});

  final PosCartLine line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final served = line.isServed;
    final background = served ? AppPalette.success : AppPalette.surface;
    final foreground = served ? AppPalette.surface : colorScheme.outline;
    final border = served ? AppPalette.success : AppPalette.border;
    final tooltip = served
        ? AppLocalizations.of(context).posMarkPendingTooltip
        : AppLocalizations.of(context).posMarkServedTooltip;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: served,
        label: AppLocalizations.of(context).posServedColumn,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              context.read<PosBloc>().add(
                PosCartLineServedToggled(line.lineKey),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                alignment: served
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: foreground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    served ? Icons.check : Icons.circle_outlined,
                    color: background,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityControls extends StatelessWidget {
  const _QuantityControls({required this.line});

  final PosCartLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityButton(
          icon: Icons.remove,
          onPressed: line.quantity <= 1
              ? null
              : () {
                  context.read<PosBloc>().add(
                    PosCartLineDecremented(line.lineKey),
                  );
                },
        ),
        SizedBox(
          width: 32,
          child: AppText(
            '${line.quantity}',
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        _QuantityButton(
          icon: Icons.add,
          onPressed: () {
            context.read<PosBloc>().add(PosCartLineIncremented(line.lineKey));
          },
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final foreground = enabled ? colorScheme.primary : colorScheme.outline;
    final borderColor = enabled ? colorScheme.primary : colorScheme.outline;
    final background = enabled
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surfaceContainerHighest;

    return SizedBox.square(
      dimension: 36,
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: CircleBorder(side: BorderSide(color: borderColor)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: foreground, size: 20),
        ),
      ),
    );
  }
}
