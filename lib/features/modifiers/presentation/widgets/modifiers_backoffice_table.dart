import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Flat desktop view of modifier groups with editable option labels.
class ModifiersBackofficeTable extends StatelessWidget {
  /// Creates a reusable table without changing modifier operations.
  const ModifiersBackofficeTable({
    required this.groups,
    required this.optionsFor,
    required this.onAddOption,
    required this.onEditGroup,
    required this.onEditOption,
    required this.onDeactivateGroup,
    required this.compactBuilder,
    super.key,
  });

  /// Existing groups.
  final List<ModifierGroup> groups;

  /// Existing options for one group.
  final List<ModifierOption> Function(String groupId) optionsFor;

  /// Add a modifier option.
  final ValueChanged<ModifierGroup> onAddOption;

  /// Edit a group.
  final ValueChanged<ModifierGroup> onEditGroup;

  /// Edit an option, grouped by its parent.
  final void Function(ModifierGroup, ModifierOption) onEditOption;

  /// Inactivate a group with its confirmation flow.
  final ValueChanged<ModifierGroup> onDeactivateGroup;

  /// Preserve detailed mobile expansion tiles.
  final Widget Function(BuildContext, ModifierGroup) compactBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BackofficeCollectionView<ModifierGroup>(
      items: groups,
      searchLabel: 'Buscar grupo u opción modificadora',
      searchTextFor: (group) => [
        group.name,
        for (final option in optionsFor(group.id)) option.name,
      ].join(' '),
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: compactBuilder,
      columns: [
        BackofficeListColumn(
          label: 'Grupo',
          width: 285,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, group) => Text(group.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Opciones',
          width: 400,
          compare: (a, b) => optionsFor(a.id).length.compareTo(
            optionsFor(b.id).length,
          ),
          cell: (_, group) => Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (optionsFor(group.id).isEmpty)
                const Text('Sin opciones'),
              for (final option in optionsFor(group.id))
                TextButton(
                  onPressed: () => onEditOption(group, option),
                  child: Text(option.name, softWrap: true),
                ),
            ],
          ),
        ),
        BackofficeListColumn(
          label: 'Selección',
          width: 155,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isRequired ? 1 : 0).compareTo(b.isRequired ? 1 : 0),
          cell: (_, group) => Text(
            group.isRequired ? 'Obligatoria' : 'Opcional',
          ),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 125,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
          cell: (_, group) =>
              Text(group.isActive ? 'Activo' : 'Inactivo'),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 355,
          alignment: Alignment.center,
          cell: (_, group) => Wrap(
            spacing: 3,
            children: [
              TextButton.icon(
                onPressed: () => onEditGroup(group),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(l10n.editAction),
              ),
              TextButton.icon(
                onPressed: () => onAddOption(group),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Opción'),
              ),
              if (group.isActive)
                TextButton.icon(
                  onPressed: () => onDeactivateGroup(group),
                  icon: const Icon(Icons.toggle_off_outlined, size: 17),
                  label: Text(l10n.deactivateAction),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
