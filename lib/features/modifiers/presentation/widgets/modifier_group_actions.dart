part of 'modifier_group_tile.dart';

enum _GroupAction { add, deactivate, edit }

class _GroupPopupActions extends StatelessWidget {
  const _GroupPopupActions({
    required this.isActive,
    required this.onAddOption,
    required this.onDeactivateGroup,
    required this.onEditGroup,
  });

  final bool isActive;
  final VoidCallback onAddOption;
  final VoidCallback onDeactivateGroup;
  final VoidCallback onEditGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_GroupAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _GroupAction.add:
            onAddOption();
          case _GroupAction.deactivate:
            onDeactivateGroup();
          case _GroupAction.edit:
            onEditGroup();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _GroupAction.add,
          child: _PopupActionLabel(
            icon: Icons.add,
            label: l10n.addModifierOptionAction,
          ),
        ),
        if (isActive)
          PopupMenuItem(
            value: _GroupAction.deactivate,
            child: _PopupActionLabel(
              icon: Icons.delete_outline,
              label: l10n.deactivateAction,
            ),
          ),
        PopupMenuItem(
          value: _GroupAction.edit,
          child: _PopupActionLabel(
            icon: Icons.edit_outlined,
            label: l10n.editAction,
          ),
        ),
      ],
      tooltip: l10n.moreOptionsAction,
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

enum _OptionAction { deactivate, edit }

class _OptionPopupActions extends StatelessWidget {
  const _OptionPopupActions({
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
    return PopupMenuButton<_OptionAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _OptionAction.deactivate:
            onDeactivate();
          case _OptionAction.edit:
            onEdit();
        }
      },
      itemBuilder: (context) => [
        if (isActive)
          PopupMenuItem(
            value: _OptionAction.deactivate,
            child: _PopupActionLabel(
              icon: Icons.delete_outline,
              label: l10n.deactivateAction,
            ),
          ),
        PopupMenuItem(
          value: _OptionAction.edit,
          child: _PopupActionLabel(
            icon: Icons.edit_outlined,
            label: l10n.editAction,
          ),
        ),
      ],
      tooltip: l10n.moreOptionsAction,
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

class _PopupActionLabel extends StatelessWidget {
  const _PopupActionLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: AppText(label)),
      ],
    );
  }
}
