part of 'pos_modifier_availability_page.dart';

class _ModifierGroupAvailabilityCard extends StatelessWidget {
  const _ModifierGroupAvailabilityCard({
    required this.group,
    required this.onChanged,
    required this.options,
    required this.savingOptionIds,
  });

  final ModifierGroup group;
  final List<ModifierOption> options;
  final Set<String> savingOptionIds;
  final void Function(ModifierOption option, {required bool available})
  onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.tune_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: AppText('Sin opciones activas'),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in options)
                        SizedBox(
                          width: isWide
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth,
                          child: _ModifierOptionAvailabilityTile(
                            isSaving: savingOptionIds.contains(option.id),
                            onChanged: (value) => onChanged(
                              option,
                              available: value,
                            ),
                            option: option,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModifierOptionAvailabilityTile extends StatelessWidget {
  const _ModifierOptionAvailabilityTile({
    required this.isSaving,
    required this.onChanged,
    required this.option,
  });

  final bool isSaving;
  final ValueChanged<bool> onChanged;
  final ModifierOption option;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = option.isAvailableInPos
        ? colorScheme.primary
        : colorScheme.error;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: isSaving ? null : () => onChanged(!option.isAvailableInPos),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                option.isAvailableInPos
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      option.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      variant: AppTextVariant.label,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      option.isAvailableInPos ? 'Disponible' : 'No disponible',
                      style: TextStyle(color: statusColor),
                      variant: AppTextVariant.label,
                    ),
                  ],
                ),
              ),
              if (isSaving)
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: option.isAvailableInPos,
                  onChanged: onChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
