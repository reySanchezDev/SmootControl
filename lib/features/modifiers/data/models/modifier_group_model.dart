import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';

/// Local model for modifier groups.
final class ModifierGroupModel extends Equatable {
  /// Creates a modifier group model.
  const ModifierGroupModel({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.displayOrder,
    required this.isActive,
  });

  /// Creates a model from Drift row.
  factory ModifierGroupModel.fromLocal(LocalModifierGroup row) {
    return ModifierGroupModel(
      id: row.id,
      name: row.name,
      isRequired: row.isRequired,
      displayOrder: row.displayOrder,
      isActive: row.isActive,
    );
  }

  /// Creates a model from entity.
  factory ModifierGroupModel.fromEntity(ModifierGroup entity) {
    return ModifierGroupModel(
      id: entity.id,
      name: entity.name,
      isRequired: entity.isRequired,
      displayOrder: entity.displayOrder,
      isActive: entity.isActive,
    );
  }

  /// Identifier.
  final String id;

  /// Name.
  final String name;

  /// Required in POS.
  final bool isRequired;

  /// Order.
  final int displayOrder;

  /// Active flag.
  final bool isActive;

  /// Converts to entity.
  ModifierGroup toEntity() {
    return ModifierGroup(
      id: id,
      name: name,
      isRequired: isRequired,
      displayOrder: displayOrder,
      isActive: isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, isRequired, displayOrder, isActive];
}
