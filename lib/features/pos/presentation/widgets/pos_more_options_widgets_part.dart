part of 'pos_more_options_panel.dart';

class _CompactSalesTypeSelector extends StatelessWidget {
  const _CompactSalesTypeSelector({
    required this.onSelected,
    required this.selectedSalesTypeId,
    required this.state,
  });

  final ValueChanged<String> onSelected;
  final String? selectedSalesTypeId;
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final activeTypes = state.salesTypes.where((type) => type.isActive).toList()
      ..sort(
        (first, second) => first.displayOrder.compareTo(second.displayOrder),
      );
    if (activeTypes.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (final type in activeTypes) ...[
          Expanded(
            child: _CompactSalesTypeButton(
              label: _mobileSalesTypeLabel(type),
              selected: type.id == selectedSalesTypeId,
              onPressed: () => onSelected(type.id),
            ),
          ),
          if (type != activeTypes.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _CompactSalesTypeButton extends StatelessWidget {
  const _CompactSalesTypeButton({
    required this.label,
    required this.onPressed,
    required this.selected,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? AppPalette.primaryDark
        : colorScheme.surfaceContainerHighest.withValues(alpha: .58);
    final foreground = selected ? AppPalette.surface : AppPalette.textPrimary;
    final border = selected
        ? AppPalette.primaryDark
        : colorScheme.outlineVariant;
    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: selected ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: foreground,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: AppText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground),
                  textAlign: TextAlign.center,
                  variant: AppTextVariant.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _mobileSalesTypeLabel(SalesType type) {
  final normalized = type.code.trim().toLowerCase();
  if (normalized == 'dine_in' || normalized == 'eat_here') return 'Aqui';
  if (normalized == 'to_go' || normalized == 'takeout') return 'GO';

  final name = type.name.trim().toLowerCase();
  if (name == 'comer aqui' || name == 'aqui') return 'Aqui';
  if (name == 'para llevar' || name == 'llevar') return 'GO';
  return type.name;
}

class _CompactSectionTitle extends StatelessWidget {
  const _CompactSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          variant: AppTextVariant.label,
        ),
      ),
    );
  }
}

class _MoreOptionButton extends StatelessWidget {
  const _MoreOptionButton({
    required this.label,
    required this.onPressed,
    required this.tone,
  });

  final String label;
  final VoidCallback onPressed;
  final _MoreOptionButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = switch (tone) {
      _MoreOptionButtonTone.danger => (
        background: colorScheme.error,
        foreground: colorScheme.onError,
      ),
      _MoreOptionButtonTone.neutral => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurface,
      ),
    };

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onPressed,
        child: AppText(
          label,
          style: TextStyle(color: colors.foreground),
          textAlign: TextAlign.center,
          variant: AppTextVariant.label,
        ),
      ),
    );
  }
}

class _FloatingMoreOptionsCloseButton extends StatelessWidget {
  const _FloatingMoreOptionsCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      elevation: 6,
      shadowColor: colorScheme.error.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          width: 56,
          child: Icon(Icons.close, color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _SyncDataProgressDialog extends StatelessWidget {
  const _SyncDataProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveTouchDialogFrame(
      maxWidth: 360,
      title: AppText(
        'Sincronizar datos',
        variant: AppTextVariant.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          CircularProgressIndicator(),
          SizedBox(height: 18),
          AppText(
            'Actualizando catalogos del POS...',
            textAlign: TextAlign.center,
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}
