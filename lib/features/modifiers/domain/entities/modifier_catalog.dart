import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';

/// Complete modifier catalog used by maintenance screens and POS.
final class ModifierCatalog extends Equatable {
  /// Creates a modifier catalog.
  const ModifierCatalog({
    required this.groups,
    required this.options,
  });

  /// Modifier groups.
  final List<ModifierGroup> groups;

  /// Modifier options.
  final List<ModifierOption> options;

  /// Finds one modifier group by identifier.
  ModifierGroup? groupById(String groupId) {
    for (final group in groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  /// Options for one group.
  List<ModifierOption> optionsFor(String groupId) {
    return options.where((option) => option.groupId == groupId).toList()
      ..sort((first, second) {
        final order = first.displayOrder.compareTo(second.displayOrder);
        if (order != 0) return order;
        return first.name.compareTo(second.name);
      });
  }

  @override
  List<Object?> get props => [groups, options];
}
