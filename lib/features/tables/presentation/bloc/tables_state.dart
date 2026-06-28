import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';

/// Base tables state.
sealed class TablesState extends Equatable {
  /// Creates a tables state.
  const TablesState();

  @override
  List<Object?> get props => [];
}

/// Initial tables state.
final class TablesInitial extends TablesState {
  /// Creates the initial state.
  const TablesInitial();
}

/// Tables loading state.
final class TablesLoading extends TablesState {
  /// Creates a loading state.
  const TablesLoading();
}

/// Tables loaded state.
final class TablesLoaded extends TablesState {
  /// Creates a loaded state.
  const TablesLoaded(this.tables);

  /// Available restaurant tables.
  final List<RestaurantTable> tables;

  @override
  List<Object?> get props => [tables];
}

/// Tables failure state.
final class TablesFailure extends TablesState {
  /// Creates a failure state.
  const TablesFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
