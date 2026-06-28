import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';

/// Local model for modifier options.
final class ModifierOptionModel extends Equatable {
  /// Creates a modifier option model.
  const ModifierOptionModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.priceDeltaInCents,
    required this.displayOrder,
    required this.isActive,
    required this.isAvailableInPos,
  });

  /// Creates a model from Drift row.
  factory ModifierOptionModel.fromLocal(LocalModifierOption row) {
    return ModifierOptionModel(
      id: row.id,
      groupId: row.groupId,
      name: row.name,
      priceDeltaInCents: row.priceDeltaInCents,
      displayOrder: row.displayOrder,
      isActive: row.isActive,
      isAvailableInPos: row.isAvailableInPos,
    );
  }

  /// Creates a model from entity.
  factory ModifierOptionModel.fromEntity(ModifierOption entity) {
    return ModifierOptionModel(
      id: entity.id,
      groupId: entity.groupId,
      name: entity.name,
      priceDeltaInCents: entity.priceDeltaInCents,
      displayOrder: entity.displayOrder,
      isActive: entity.isActive,
      isAvailableInPos: entity.isAvailableInPos,
    );
  }

  /// Identifier.
  final String id;

  /// Parent group.
  final String groupId;

  /// Name.
  final String name;

  /// Price delta.
  final int priceDeltaInCents;

  /// Order.
  final int displayOrder;

  /// Active flag.
  final bool isActive;

  /// POS availability.
  final bool isAvailableInPos;

  /// Converts to entity.
  ModifierOption toEntity() {
    return ModifierOption(
      id: id,
      groupId: groupId,
      name: name,
      priceDeltaInCents: priceDeltaInCents,
      displayOrder: displayOrder,
      isActive: isActive,
      isAvailableInPos: isAvailableInPos,
    );
  }

  @override
  List<Object?> get props => [
    id,
    groupId,
    name,
    priceDeltaInCents,
    displayOrder,
    isActive,
    isAvailableInPos,
  ];
}
