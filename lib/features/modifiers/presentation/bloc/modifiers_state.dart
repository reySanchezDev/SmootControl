import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';

/// Base state for modifier maintenance.
sealed class ModifiersState extends Equatable {
  /// Creates a state.
  const ModifiersState();

  @override
  List<Object?> get props => [];
}

/// Initial state.
final class ModifiersInitial extends ModifiersState {
  /// Creates an initial state.
  const ModifiersInitial();
}

/// Loading state.
final class ModifiersLoading extends ModifiersState {
  /// Creates a loading state.
  const ModifiersLoading();
}

/// Loaded state.
final class ModifiersLoaded extends ModifiersState {
  /// Creates a loaded state.
  const ModifiersLoaded(this.catalog);

  /// Current catalog.
  final ModifierCatalog catalog;

  @override
  List<Object?> get props => [catalog];
}

/// Failure state.
final class ModifiersFailure extends ModifiersState {
  /// Creates a failure state.
  const ModifiersFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
