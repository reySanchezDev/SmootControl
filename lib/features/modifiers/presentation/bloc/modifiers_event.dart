import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';

/// Base event for modifier maintenance.
sealed class ModifiersEvent extends Equatable {
  /// Creates an event.
  const ModifiersEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the modifier catalog.
final class ModifiersLoadRequested extends ModifiersEvent {
  /// Creates a load event.
  const ModifiersLoadRequested();
}

/// Saves a modifier group.
final class ModifierGroupSaved extends ModifiersEvent {
  /// Creates a save event.
  const ModifierGroupSaved(this.group);

  /// Group to save.
  final ModifierGroup group;

  @override
  List<Object?> get props => [group];
}

/// Saves a modifier option.
final class ModifierOptionSaved extends ModifiersEvent {
  /// Creates a save event.
  const ModifierOptionSaved(this.option);

  /// Option to save.
  final ModifierOption option;

  @override
  List<Object?> get props => [option];
}
