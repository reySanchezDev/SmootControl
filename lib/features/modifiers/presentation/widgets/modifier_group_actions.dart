part of 'modifier_group_tile.dart';

class _CompactGroupCommands extends StatelessWidget {
  const _CompactGroupCommands({
    required this.isActive,
    required this.onAddOption,
    required this.onDeactivate,
    required this.onEdit,
  });

  final bool isActive;
  final VoidCallback onAddOption;
  final VoidCallback onDeactivate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.addModifierOptionAction),
            onPressed: onAddOption,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.editAction),
            onPressed: onEdit,
          ),
          if (isActive)
            OutlinedButton.icon(
              icon: const Icon(Icons.toggle_off_outlined),
              label: Text(l10n.deactivateAction),
              onPressed: onDeactivate,
            ),
        ],
      ),
    );
  }
}

class _GroupActions extends StatelessWidget {
  const _GroupActions({
    required this.isActive,
    required this.onAddOption,
    required this.onDeactivateGroup,
    required this.onEditGroup,
    required this.optionsLabel,
  });

  final bool isActive;
  final VoidCallback onAddOption;
  final VoidCallback onDeactivateGroup;
  final VoidCallback onEditGroup;
  final String optionsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticColors = context.semanticColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(optionsLabel, variant: AppTextVariant.label),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAddOption,
          tooltip: l10n.addModifierOptionAction,
        ),
        if (isActive)
          IconButton(
            color: semanticColors.dangerAction,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDeactivateGroup,
            tooltip: l10n.deactivateAction,
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEditGroup,
          tooltip: l10n.editAction,
        ),
      ],
    );
  }
}

class _CompactOptionCommands extends StatelessWidget {
  const _CompactOptionCommands({
    required this.isActive,
    required this.onDeactivate,
    required this.onEdit,
  });

  final bool isActive;
  final VoidCallback onDeactivate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 32, end: 12, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.editAction),
            onPressed: onEdit,
          ),
          if (isActive)
            OutlinedButton.icon(
              icon: const Icon(Icons.toggle_off_outlined),
              label: Text(l10n.deactivateAction),
              onPressed: onDeactivate,
            ),
        ],
      ),
    );
  }
}

class _OptionActions extends StatelessWidget {
  const _OptionActions({
    required this.isActive,
    required this.onDeactivate,
    required this.onEdit,
  });

  final bool isActive;
  final VoidCallback onDeactivate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticColors = context.semanticColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isActive)
          IconButton(
            color: semanticColors.dangerAction,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDeactivate,
            tooltip: l10n.deactivateAction,
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          tooltip: l10n.editAction,
        ),
      ],
    );
  }
}
